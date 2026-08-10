#!/usr/bin/env bash

create_btrfs_layout() {
  local mapper="/dev/mapper/$CRYPT_NAME"

  log "Creating Btrfs filesystem"
  mkfs.btrfs -f -L "$BTRFS_LABEL" "$mapper"
  mount "$mapper" /mnt

  local subvol
  for subvol in @ @home @snapshots @var_log @pkg; do
    btrfs subvolume create "/mnt/$subvol"
  done
  umount /mnt

  local opts="noatime,compress=zstd:3,ssd,discard=async,space_cache=v2"
  mount -o "$opts,subvol=@" "$mapper" /mnt
  mkdir -p /mnt/{home,.snapshots,var/log,var/cache/pacman/pkg,efi}
  mount -o "$opts,subvol=@home"      "$mapper" /mnt/home
  mount -o "$opts,subvol=@snapshots" "$mapper" /mnt/.snapshots
  mount -o "$opts,subvol=@var_log"   "$mapper" /mnt/var/log
  mount -o "$opts,subvol=@pkg"       "$mapper" /mnt/var/cache/pacman/pkg

  log "Formatting and mounting EFI partition"
  mkfs.fat -F 32 -n EFI "$EFI_PART"
  mount "$EFI_PART" /mnt/efi

  log "Mounted target layout"
  findmnt -R /mnt
}

mount_existing_btrfs_layout() {
  local mapper="/dev/mapper/$CRYPT_NAME"
  local opts="noatime,compress=zstd:3,ssd,discard=async,space_cache=v2"

  [[ -b "$LUKS_PART" ]] || die "LUKS partition not found: $LUKS_PART"
  [[ -b "$EFI_PART" ]] || die "EFI partition not found: $EFI_PART"
  cryptsetup isLuks "$LUKS_PART" >/dev/null 2>&1 || die "$LUKS_PART is not a LUKS container."

  if [[ ! -b "$mapper" ]]; then
    log "Opening existing LUKS2 container as $CRYPT_NAME"
    cryptsetup open "$LUKS_PART" "$CRYPT_NAME"
  fi

  mkdir -p /mnt
  mountpoint -q /mnt && umount -R /mnt

  mount -o "$opts,subvol=@" "$mapper" /mnt
  mkdir -p /mnt/{home,.snapshots,var/log,var/cache/pacman/pkg,efi}
  mount -o "$opts,subvol=@home"      "$mapper" /mnt/home
  mount -o "$opts,subvol=@snapshots" "$mapper" /mnt/.snapshots
  mount -o "$opts,subvol=@var_log"   "$mapper" /mnt/var/log
  mount -o "$opts,subvol=@pkg"       "$mapper" /mnt/var/cache/pacman/pkg
  mount "$EFI_PART" /mnt/efi

  [[ -f /mnt/etc/os-release ]] || die "No installed Arch system found under /mnt."
  log "Existing target layout mounted"
  findmnt -R /mnt
}
