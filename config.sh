#!/usr/bin/env bash

EFI_SIZE="2GiB"
CRYPT_NAME="cryptroot"
BTRFS_LABEL="ArchRoot"

HOSTNAME_DEFAULT="workstation"
USERNAME_DEFAULT="operator"
TIMEZONE_DEFAULT="Asia/Omsk"
LOCALE_DEFAULT="en_US.UTF-8"
KEYMAP_DEFAULT="us"

# Reflector settings. If reflector cannot refresh the list, the installer
# restores the Arch ISO mirrorlist and continues with it.
MIRROR_COUNTRIES="Kazakhstan,Russia,Germany"
MIRROR_AGE_HOURS="24"
MIRROR_LATEST="30"

DOTFILES_REPO="https://github.com/daniilsolovey/dotfiles"
DOTFILES_BRANCH="master"
DOTFILES_CLONE_DIR="/tmp/arch-secure-dotfiles"

GITHUB_OWNER="daniilsolovey"
GO_REPOSITORIES=(
  volume-control-go
  sensors-info-linux
  cpu-monitoring
  low-battery-notify
)

INSTALL_AUR_DEFAULT="no"
