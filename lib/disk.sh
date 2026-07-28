#!/usr/bin/env bash

list_candidate_disks() {
  lsblk -d -e 7,11 -o PATH,SIZE,MODEL,TRAN,TYPE | awk 'NR==1 || $NF=="disk"'
}

validate_disk() {
  local disk=$1

  [[ -b "$disk" ]] || die "$disk is not a block device."
  [[ "$(lsblk -dn -o TYPE "$disk")" == "disk" ]] || die "$disk is not a whole disk."

  local live_source
  live_source=$(findmnt -n -o SOURCE /run/archiso/bootmnt 2>/dev/null || true)
  if [[ -n "$live_source" ]]; then
    local live_parent
    live_parent="/dev/$(lsblk -no PKNAME "$live_source" 2>/dev/null | head -n1)"
    [[ "$disk" != "$live_parent" ]] || die "Refusing to erase the Arch installation medium: $disk"
  fi
}

choose_disk() {
  log "Available disks"
  list_candidate_disks
  printf '\n'
  read -r -p "Target disk (example /dev/nvme0n1): " DISK
  validate_disk "$DISK"

  log "Selected disk"
  lsblk -o NAME,SIZE,MODEL,FSTYPE,MOUNTPOINTS "$DISK"

  warn "ALL data, partitions and files on $DISK will be destroyed."
  read -r -p "Type exactly: ERASE $DISK: " confirmation
  [[ "$confirmation" == "ERASE $DISK" ]] || die "Confirmation did not match. Nothing was erased."

  local serial
  serial=$(udevadm info --query=property --name="$DISK" 2>/dev/null | sed -n 's/^ID_SERIAL_SHORT=//p' | head -n1)
  printf 'Disk serial: %s\n' "${serial:-unknown}"
  read -r -p "Final confirmation: type YES: " final_confirmation
  [[ "$final_confirmation" == "YES" ]] || die "Installation cancelled. Nothing was erased."
}

partition_path() {
  local disk=$1 number=$2
  if [[ "$disk" =~ (nvme|mmcblk|loop) ]]; then
    printf '%sp%s\n' "$disk" "$number"
  else
    printf '%s%s\n' "$disk" "$number"
  fi
}

partition_disk() {
  local disk=$1

  log "Unmounting existing filesystems on $disk"
  while read -r mountpoint; do
    [[ -n "$mountpoint" ]] && umount -R "$mountpoint"
  done < <(lsblk -nr -o MOUNTPOINTS "$disk" | awk 'NF' | sort -r)

  log "Creating GPT with a ${EFI_SIZE} EFI partition"
  wipefs --all --force "$disk"
  sgdisk --zap-all "$disk"
  sgdisk --clear \
    --new=1:1MiB:+"$EFI_SIZE" --typecode=1:ef00 --change-name=1:"EFI System" \
    --new=2:0:0             --typecode=2:8309 --change-name=2:"Linux LUKS" \
    "$disk"

  partprobe "$disk"
  udevadm settle

  EFI_PART=$(partition_path "$disk" 1)
  LUKS_PART=$(partition_path "$disk" 2)

  [[ -b "$EFI_PART" && -b "$LUKS_PART" ]] || die "New partitions did not appear."

  log "Created partitions"
  lsblk -o NAME,SIZE,PARTTYPE,PARTLABEL "$disk"
}
