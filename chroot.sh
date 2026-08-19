#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

PROJECT_DIR=/root/arch-secure
source "$PROJECT_DIR/config.sh"
source "$PROJECT_DIR/lib/common.sh"
source "$PROJECT_DIR/install.env"
source "$PROJECT_DIR/lib/dotfiles.sh"
source "$PROJECT_DIR/lib/projects.sh"

configure_locale_time() {
  log "Configuring timezone and clock"
  ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
  hwclock --systohc

  log "Configuring locale"
  sed -i "s/^#${LOCALE} UTF-8/${LOCALE} UTF-8/" /etc/locale.gen
  grep -q "^${LOCALE} UTF-8" /etc/locale.gen || printf '%s UTF-8\n' "$LOCALE" >> /etc/locale.gen
  locale-gen
  printf 'LANG=%s\n' "$LOCALE" > /etc/locale.conf
  printf 'KEYMAP=%s\n' "$KEYMAP" > /etc/vconsole.conf
}

configure_identity() {
  printf '%s\n' "$HOSTNAME" > /etc/hostname

  cat > /etc/hosts <<EOF_HOSTS
127.0.0.1 localhost
::1       localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
EOF_HOSTS
}

configure_user() {
  if ! id "$USERNAME" >/dev/null 2>&1; then
    local requested_groups=(wheel audio video input storage docker vboxusers)
    local supplementary_groups=()
    local group

    for group in "${requested_groups[@]}"; do
      getent group "$group" >/dev/null 2>&1 && supplementary_groups+=("$group")
    done

    local group_args=()
    if ((${#supplementary_groups[@]} > 0)); then
      group_args=(-G "$(IFS=,; echo "${supplementary_groups[*]}")")
    fi

    useradd -m "${group_args[@]}" -s /bin/zsh "$USERNAME"
  fi

  log "Set password for user '$USERNAME'"
  passwd "$USERNAME"
  passwd -l root

  cat > /etc/sudoers.d/10-wheel <<'EOF_SUDO'
%wheel ALL=(ALL:ALL) ALL
EOF_SUDO

  chmod 0440 /etc/sudoers.d/10-wheel
  visudo -cf /etc/sudoers.d/10-wheel >/dev/null
}

configure_encrypted_boot() {
  log "Configuring mkinitcpio for LUKS2 and UKI"

  sed -i -E \
    's/^HOOKS=.*/HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block sd-encrypt filesystems fsck)/' \
    /etc/mkinitcpio.conf

  mkdir -p /efi/EFI/Linux

  cat > /etc/kernel/cmdline <<EOF_CMDLINE
rd.luks.name=${LUKS_UUID}=${CRYPT_NAME} root=/dev/mapper/${CRYPT_NAME} rootflags=subvol=@ rw
EOF_CMDLINE

  cat > /etc/mkinitcpio.d/linux.preset <<'EOF_PRESET'
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"
PRESETS=('default' 'fallback')
default_uki="/efi/EFI/Linux/arch-linux.efi"
default_options="--splash /usr/share/systemd/bootctl/splash-arch.bmp"
fallback_uki="/efi/EFI/Linux/arch-linux-fallback.efi"
fallback_options="-S autodetect"
EOF_PRESET

  bootctl --esp-path=/efi install

  cat > /efi/loader/loader.conf <<'EOF_LOADER'
default @saved
timeout 3
console-mode max
editor no
EOF_LOADER

  mkinitcpio -P
  [[ -f /efi/EFI/Linux/arch-linux.efi ]] || die "UKI was not generated."
}

configure_services() {
  systemctl enable NetworkManager.service
  systemctl enable sshd.service
  systemctl enable fstrim.timer
  systemctl enable docker.service
}

configure_shift_shift_sudo() {
  local binary=/usr/local/lib/arch-secure/shift-shift
  local sudoers=/etc/sudoers.d/30-arch-secure-shift-shift

  [[ -x "$binary" ]] || die "Root-owned shift-shift binary is missing: $binary"

  chown root:root "$binary"
  chmod 0755 "$binary"

  printf '%s ALL=(root) NOPASSWD: %s\n' "$USERNAME" "$binary" > "$sudoers"
  chmod 0440 "$sudoers"
  visudo -cf "$sudoers" >/dev/null

  local xinitrc="/home/$USERNAME/.xinitrc"
  [[ -f "$xinitrc" ]] || die ".xinitrc is missing after dotfiles installation"

  sed -i \
    -e '/^[[:space:]]*sudo[[:space:]]+systemctl[[:space:]]+import-environment[[:space:]]+DISPLAY/d' \
    -e '/^[[:space:]]*sudo[[:space:]]+ntpdate[[:space:]]+pool.ntp.org/d' \
    -e "s#sudo[[:space:]]+shift-shift#sudo $binary#g" \
    "$xinitrc"

  chown "$USERNAME:$USERNAME" "$xinitrc"
  chmod 0755 "$xinitrc"
}

reload_udev_rules() {
  [[ -f /etc/udev/rules.d/88-xkbd.rules ]] || die "udev rule was not installed"

  chown root:root /etc/udev/rules.d/88-xkbd.rules
  chmod 0644 /etc/udev/rules.d/88-xkbd.rules

  udevadm control --reload-rules \
    || warn "udevadm reload is unavailable inside chroot; rules will load after reboot."

  udevadm trigger \
    || warn "udevadm trigger is unavailable inside chroot; rules will load after reboot."
}

configure_tty_autologin() {
  local override_dir="/etc/systemd/system/getty@tty1.service.d"
  local override_file="$override_dir/override.conf"

  log "Configuring tty1 autologin for $USERNAME"

  mkdir -p "$override_dir"

  cat > "$override_file" <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin $USERNAME --noclear %I \$TERM
EOF

  [[ -f "$override_file" ]] || die "Failed to configure tty1 autologin"
}

main() {
  configure_locale_time
  configure_identity
  configure_user
  configure_encrypted_boot
  configure_services

  export USERNAME USER_HOME="/home/$USERNAME"

  install_dotfiles "$PROJECT_DIR/dotfiles.map"
  find "$USER_HOME/Scripts" -type f -exec chmod 0755 {} +

  configure_shift_shift_sudo
  reload_udev_rules

  if ! install_user_projects; then
    warn "One or more optional Go projects failed. The base system remains installed."
  fi

  chown -R "$USERNAME:$USERNAME" "/home/$USERNAME"
  configure_tty_autologin

  rm -f "$PROJECT_DIR/install.env"
  log "Chroot configuration completed"
}

main "$@"