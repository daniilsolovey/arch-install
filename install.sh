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

main() {
  check_environment
  collect_install_settings
  configure_mirrors
  validate_official_packages
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

main "$@"
