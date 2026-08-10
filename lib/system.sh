#!/usr/bin/env bash

collect_install_settings() {
  read -r -p "Hostname [$HOSTNAME_DEFAULT]: " HOSTNAME
  HOSTNAME=${HOSTNAME:-$HOSTNAME_DEFAULT}
  [[ "$HOSTNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || die "Invalid hostname."

  read -r -p "Username [$USERNAME_DEFAULT]: " USERNAME
  USERNAME=${USERNAME:-$USERNAME_DEFAULT}
  [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] || die "Invalid username."

  read -r -p "Timezone [$TIMEZONE_DEFAULT]: " TIMEZONE
  TIMEZONE=${TIMEZONE:-$TIMEZONE_DEFAULT}
  [[ -e "/usr/share/zoneinfo/$TIMEZONE" ]] || die "Unknown timezone: $TIMEZONE"

  export HOSTNAME USERNAME TIMEZONE
}

write_fstab() {
  log "Generating fstab"

  genfstab -U /mnt > /mnt/etc/fstab

  awk '$1 !~ /^#/ && $2 == "/" { found=1 } END { exit !found }' /mnt/etc/fstab \
    || die "Root filesystem is missing from generated fstab."

  awk '$1 !~ /^#/ && $2 == "/efi" { found=1 } END { exit !found }' /mnt/etc/fstab \
    || die "EFI filesystem is missing from generated fstab."

  log "fstab validated"
}

prepare_chroot_payload() {
  rm -rf /mnt/root/arch-secure
  mkdir -p /mnt/root/arch-secure
  cp -a "$PROJECT_DIR"/. /mnt/root/arch-secure/

  local luks_uuid
  luks_uuid=$(cryptsetup luksUUID "$LUKS_PART")
  [[ -n "$luks_uuid" ]] || die "Could not determine LUKS UUID."

  {
    printf 'HOSTNAME=%q\n' "$HOSTNAME"
    printf 'USERNAME=%q\n' "$USERNAME"
    printf 'TIMEZONE=%q\n' "$TIMEZONE"
    printf 'LOCALE=%q\n' "$LOCALE_DEFAULT"
    printf 'KEYMAP=%q\n' "$KEYMAP_DEFAULT"
    printf 'CRYPT_NAME=%q\n' "$CRYPT_NAME"
    printf 'LUKS_UUID=%q\n' "$luks_uuid"
  } > /mnt/root/arch-secure/install.env

  chmod 0600 /mnt/root/arch-secure/install.env
}

run_chroot_install() {
  log "Configuring installed system"
  arch-chroot /mnt /root/arch-secure/chroot.sh
}