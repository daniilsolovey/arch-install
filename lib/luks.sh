#!/usr/bin/env bash

create_luks() {
  local partition=$1

  log "Creating a LUKS2 container on $partition"
  printf '%s\n' \
    "Use a long, unique recovery passphrase." \
    "It will not be stored by this installer." \
    "cryptsetup will ask for it twice."

  cryptsetup luksFormat \
    --type luks2 \
    --verify-passphrase \
    "$partition"

  log "Opening LUKS2 container as $CRYPT_NAME"
  cryptsetup open "$partition" "$CRYPT_NAME"
  [[ -b "/dev/mapper/$CRYPT_NAME" ]] || die "LUKS mapper was not created."
}
