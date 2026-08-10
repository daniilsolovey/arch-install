#!/usr/bin/env bash
set -Eeuo pipefail
IFS=$'\n\t'

PROJECT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$PROJECT_DIR/config.sh"
source "$PROJECT_DIR/lib/common.sh"
source "$PROJECT_DIR/lib/disk.sh"
source "$PROJECT_DIR/lib/luks.sh"
source "$PROJECT_DIR/lib/btrfs.sh"
source "$PROJECT_DIR/lib/packages.sh"
source "$PROJECT_DIR/lib/system.sh"

on_error() {
  local line=$1 status=$2
  warn "Installer stopped at line $line with status $status."
  warn "Target mounts and the LUKS mapper will be cleaned up."
  cleanup_mounts
  exit "$status"
}
trap 'on_error "$LINENO" "$?"' ERR
trap 'cleanup_mounts; exit 130' INT TERM

check_environment() {
  require_root
  [[ -d /sys/firmware/efi/efivars ]] || die "Boot the Arch ISO in UEFI mode."

  local cmd
  for cmd in lsblk findmnt wipefs sgdisk partprobe udevadm cryptsetup mkfs.btrfs btrfs mkfs.fat mount umount pacstrap genfstab arch-chroot bootctl; do
    require_command "$cmd"
  done

  if command -v curl >/dev/null 2>&1; then
    curl --fail --silent --show-error --head --max-time 10 https://archlinux.org/ >/dev/null \
      || die "Internet connection is unavailable."
  else
    ping -c 1 -W 5 archlinux.org >/dev/null 2>&1 \
      || die "Internet connection is unavailable."
  fi
  timedatectl set-ntp true
}

validate_installer_integrity() {
  log "Validating installer files and functions"

  local file
  for file in \
    "$PROJECT_DIR/config.sh" \
    "$PROJECT_DIR/chroot.sh" \
    "$PROJECT_DIR/dotfiles.map" \
    "$PROJECT_DIR/lib/common.sh" \
    "$PROJECT_DIR/lib/disk.sh" \
    "$PROJECT_DIR/lib/luks.sh" \
    "$PROJECT_DIR/lib/btrfs.sh" \
    "$PROJECT_DIR/lib/packages.sh" \
    "$PROJECT_DIR/lib/system.sh"; do
    [[ -f "$file" ]] || die "Required installer file is missing: $file"
  done

  local fn
  for fn in \
    collect_install_settings configure_mirrors validate_official_packages \
    choose_disk partition_disk create_luks create_btrfs_layout \
    install_official_packages write_fstab prepare_chroot_payload run_chroot_install \
    mount_existing_btrfs_layout; do
    declare -F "$fn" >/dev/null || die "Required installer function is missing: $fn"
  done

  while IFS= read -r file; do
    bash -n "$file" || die "Shell syntax check failed: $file"
  done < <(find "$PROJECT_DIR" -maxdepth 2 -type f -name '*.sh' -print)
}

preflight_dotfiles() {
  require_command git
  local check_dir=/tmp/arch-install-dotfiles-preflight
  rm -rf "$check_dir"

  log "Checking dotfiles repository before disk erase"
  if ! git clone --quiet --depth 1 --branch "$DOTFILES_BRANCH" "$DOTFILES_REPO" "$check_dir"; then
    rm -rf "$check_dir"
    git clone --quiet --depth 1 "$DOTFILES_REPO" "$check_dir" \
      || die "Could not clone dotfiles repository."
  fi

  local type source destination count=0
  while IFS='|' read -r type source destination; do
    [[ -z "${type// }" || "$type" == \#* ]] && continue
    [[ -n "${source:-}" && -n "${destination:-}" ]] || die "Malformed dotfiles.map entry."
    case "$type" in
      file|config|system) [[ -f "$check_dir/$source" ]] || die "Dotfiles source is missing: $source" ;;
      dir) [[ -d "$check_dir/$source" ]] || die "Dotfiles directory is missing: $source" ;;
      *) die "Unknown dotfiles.map type: $type" ;;
    esac
    ((count += 1))
  done < "$PROJECT_DIR/dotfiles.map"
  ((count > 0)) || die "dotfiles.map contains no entries."

  rm -rf "$check_dir"
  log "Dotfiles preflight passed: $count entries"
}

select_existing_target() {
  log "Available disks for resume"
  list_candidate_disks
  printf '\n'
  read -r -p "Existing target disk (example /dev/nvme0n1): " DISK
  validate_disk "$DISK"
  EFI_PART=$(partition_path "$DISK" 1)
  LUKS_PART=$(partition_path "$DISK" 2)
  [[ -b "$EFI_PART" && -b "$LUKS_PART" ]] || die "Expected partitions were not found on $DISK."
}

resume_install() {
  check_environment
  validate_installer_integrity
  collect_install_settings
  select_existing_target
  mount_existing_btrfs_layout
  write_fstab
  prepare_chroot_payload
  run_chroot_install
  log "Installation resumed and completed successfully"
  trap - ERR INT TERM
}

main() {
  check_environment
  validate_installer_integrity
  collect_install_settings
  configure_mirrors
  validate_official_packages
  preflight_dotfiles
  choose_disk
  partition_disk "$DISK"
  create_luks "$LUKS_PART"
  create_btrfs_layout
  install_official_packages
  write_fstab
  prepare_chroot_payload
  run_chroot_install

  log "Installation completed successfully"
  printf '\nReview /mnt/etc/fstab if desired, then run:\n  umount -R /mnt\n  cryptsetup close %s\n  reboot\n' "$CRYPT_NAME"
  trap - ERR INT TERM
}

case "${1:-}" in
  --resume) resume_install ;;
  "")       main ;;
  *)        die "Usage: $0 [--resume]" ;;
esac
