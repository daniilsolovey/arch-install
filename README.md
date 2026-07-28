# arch-secure v1.4

Destructive Arch Linux workstation installer for UEFI systems.

## Defaults

- hostname: `workstation`
- user: `operator`
- timezone: `Asia/Omsk`
- locale: `en_US.UTF-8`
- console keymap: `us`
- AUR installation: disabled by default

All interactive defaults can be changed in `config.sh`.

## Installed layout

- GPT
- 2 GiB EFI System Partition mounted at `/efi`
- LUKS2 on the remaining disk space
- Btrfs label `ArchRoot`
- Btrfs subvolumes: `@`, `@home`, `@snapshots`, `@var_log`, `@pkg`
- systemd-boot with Unified Kernel Images
- TTY login and automatic `startx` on tty1; no LightDM
- root account locked; normal user uses sudo

## Mirrors

Before the disk is erased, the installer:

1. uses the Arch ISO mirrorlist to install `reflector` when necessary;
2. attempts to select HTTPS mirrors from Kazakhstan, Russia and Germany;
3. sorts them by measured download rate;
4. restores the original ISO mirrorlist if Reflector fails;
5. copies the working mirrorlist into the installed system.

Mirror selection is intentionally non-fatal: a temporary Reflector or regional mirror failure does not destroy an otherwise usable installation path.

## Usage

Boot the official Arch ISO in UEFI mode, connect to the internet, unpack the archive and run:

```bash
chmod +x install.sh
./install.sh
```

The installer permanently erases the selected target disk. It asks for two destructive confirmations and interactively asks for the LUKS and user passwords.

Official packages, dotfiles and the listed Go repositories are installed automatically. AUR packages such as `cursor-bin` are offered interactively and default to **No**.

## Included applications

The package lists include Firefox, Chromium and VirtualBox for the standard Arch `linux` kernel. The user is added to `docker` and `vboxusers` when those groups exist.

## Important

Review `config.sh`, `packages/`, `dotfiles.map`, and `repositories.list` before running on real hardware. A syntax check cannot fully reproduce firmware, disk, network, GitHub or AUR behavior, so the safest first run is in a UEFI virtual machine or on a spare disk.

## v1.4 final changes

- `.zshrc` is installed into the selected user's home directory.
- `translator.sh` is installed as `~/bin/translator`.
- `.xinitrc` is executable; blocking/background sudo calls are sanitized without changing `i3/config`.
- `shift-shift` uses a root-owned executable and a narrow sudoers rule.
- `88-xkbd.rules` is installed under `/etc/udev/rules.d/`.
- Supplementary groups are added only when they exist.
- Go repositories and AUR packages are optional and cannot invalidate the base installation.
- The chroot environment file is shell-escaped and mode `0600`.
- Xorg package selection remains unchanged.
- `usr/xkbcomp` from dotfiles is validated and installed root-owned as `/usr/bin/xkbcomp`.
- `ttf-ubuntu-font-family` is installed for the Ubuntu Mono font used by i3.
- Every dotfiles source and destination is validated before any dotfile is copied.
