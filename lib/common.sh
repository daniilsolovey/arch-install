#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

log()   { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\n\033[1;33mWARNING:\033[0m %s\n' "$*" >&2; }
die()   { printf '\n\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

require_root() {
  [[ ${EUID:-$(id -u)} -eq 0 ]] || die "Run this installer as root."
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

cleanup_mounts() {
  set +e
  mountpoint -q /mnt/efi && umount -R /mnt/efi
  mountpoint -q /mnt && umount -R /mnt
  [[ -e /dev/mapper/${CRYPT_NAME:-cryptroot} ]] && cryptsetup close "${CRYPT_NAME:-cryptroot}"
  set -e
}
