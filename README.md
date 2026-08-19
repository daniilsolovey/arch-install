# arch-install v1.5

Automated Arch Linux workstation installer for UEFI systems.

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
- automatic login of the normal user on `tty1`
- X is started manually with `startx`
- no LightDM or other display manager
- root account locked; normal user uses sudo

Automatic `startx` is intentionally disabled. After boot, the configured user is automatically logged in on `tty1` and X can be started manually:

```bash
startx
```

This keeps the TTY available if an X11, i3 or user configuration prevents the graphical environment from starting correctly.

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

## Dotfiles

User configuration files are installed according to `dotfiles.map`.

This includes configuration for:

- i3
- URxvt
- Zsh
- tmux
- X11
- dunst
- favor
- user scripts and utilities

For example:

```text
.config/dunst/dunstrc
→ ~/.config/dunst/dunstrc

.config/favor/favor.conf
→ ~/.config/favor/favor.conf
```

The installer creates required destination directories automatically.

## Included applications

The package lists include Firefox, Chromium and VirtualBox. VirtualBox uses the current official `virtualbox-host-dkms` package, with `linux-headers` already installed. The user is added to `docker` and `vboxusers` when those groups exist.

## Important

Review `config.sh`, `packages/`, `dotfiles.map`, and `repositories.list` before running on real hardware. A syntax check cannot fully reproduce firmware, disk, network, GitHub or AUR behavior, so the safest first run is in a UEFI virtual machine or on a spare disk.

## v1.5 changes after first real-hardware installation test

- `fstab` validation now parses fields with `awk`, so tabs produced by `genfstab` are handled correctly. Both `/` and `/efi` are verified.
- `virtualbox-host-modules-arch` was replaced by the current official `virtualbox-host-dkms` package.
- Reflector rates at most 8 recent mirrors instead of 30, reducing installation startup time.
- A strict preflight validates installer files, required Bash functions and shell syntax before disk erase.
- The dotfiles repository and every source in `dotfiles.map` are checked before disk erase.
- `./install.sh --resume` can continue an interrupted installation after `pacstrap` without repartitioning or reformatting the disk. It reopens LUKS, mounts the existing Btrfs layout, regenerates/validates `fstab`, then continues with the chroot stage.
- Destructive confirmation remains mandatory for a fresh installation; resume mode never calls the partitioning or formatting functions.
- Automatic `startx` on `tty1` was removed. X is now started manually with `startx`.
- The configured normal user is automatically logged in on `tty1` using a systemd `getty@tty1` override.
- The TTY remains usable if X11 or i3 fails to start.
- dunst configuration is installed to `~/.config/dunst/dunstrc`.
- favor configuration is installed to `~/.config/favor/favor.conf`.

## Resume after a late-stage failure

If a fresh installation has already completed partitioning, LUKS, Btrfs and `pacstrap`, do **not** run a fresh installation again. Reboot the Arch ISO if necessary, reconnect to the network, clone this repository, and run:

```bash
./install.sh --resume
```

Choose the same hostname/user/timezone and the existing target disk. The installer will ask for the existing LUKS passphrase, mount the existing layout and continue from the post-`pacstrap` configuration stage.
