# arch-install v2.1.0

Automated Arch Linux workstation installer for UEFI systems.

This repository installs an encrypted Arch Linux workstation with LUKS2, Btrfs, systemd-boot/UKI, Xorg+i3, Zsh, URxvt, development tooling, desktop utilities, dotfiles, and selected Go utilities.

> **Warning:** a fresh installation erases the selected target disk.

## Defaults

| Setting | Value |
| --- | --- |
| Hostname | `workstation` |
| User | `operator` |
| Timezone | `Asia/Omsk` |
| Locale | `en_US.UTF-8` |
| Keymap | `us` |
| EFI partition | `2 GiB` |
| LUKS mapper | `cryptroot` |
| Btrfs label | `ArchRoot` |
| Mirrors | Kazakhstan, Russia, Germany |
| Dotfiles | `daniilsolovey/dotfiles`, branch `master` |

Configured Go repositories:

```text
volume-control-go
sensors-info-linux
cpu-monitoring
low-battery-notify
```

## Disk layout

```text
GPT
├── EFI System Partition (2 GiB) → /efi
└── LUKS2
    └── Btrfs: ArchRoot
        ├── @
        ├── @home
        ├── @snapshots
        ├── @var_log
        └── @pkg
```

Boot uses systemd-boot with Unified Kernel Images and `sd-encrypt`.

## Login and X startup

The root account is locked. The normal user is created with Zsh and added to available workstation groups such as:

```text
wheel audio video input storage docker vboxusers
```

The installer creates:

```text
/etc/systemd/system/getty@tty1.service.d/override.conf
```

and configures automatic login of `operator` on tty1.

The user's password is still required for `sudo`.

Automatic `startx` is intentionally disabled.

Normal boot flow:

```text
LUKS password
    ↓
Arch Linux
    ↓
operator autologin on tty1
    ↓
startx
    ↓
i3
```

Start X manually:

```bash
startx
```

## Fresh installation

Boot the official Arch ISO in UEFI mode and verify:

```bash
ls /sys/firmware/efi/efivars
```

Connect to the network and verify:

```bash
ping -c 3 archlinux.org
```

Clone and run:

```bash
git clone https://github.com/daniilsolovey/arch-install.git
cd arch-install
chmod +x install.sh
./install.sh
```

## Resume mode

If partitioning, LUKS, Btrfs and `pacstrap` already completed and installation failed later:

```bash
./install.sh --resume
```

Resume mode reopens LUKS, mounts the existing Btrfs layout, regenerates/validates `fstab`, and continues chroot configuration without repartitioning or reformatting.

## Package groups

```text
packages/
├── 01-base.txt
├── 02-shell.txt
├── 03-development.txt
├── 04-desktop.txt
├── 05-network.txt
├── 06-media.txt
├── 07-fonts.txt
├── 08-utils.txt
└── 09-work.txt
```

The workstation includes the components required for the current setup, including Xorg, i3, Zsh, URxvt, tmux, NetworkManager, Docker, SSH, PipeWire/WirePlumber, dunst, Rofi, Firefox, Chromium and VirtualBox.

VirtualBox uses the DKMS host-module setup.

## Packages to install manually

The installer does not install `yay` or any AUR packages. After the first boot, install `yay` as the normal user:

```bash
git clone https://aur.archlinux.org/yay.git /tmp/yay
cd /tmp/yay
makepkg -si
```

Then install these additional packages manually:

```bash
yay -S --needed \
  downgrade \
  nemo \
  obs-studio \
  amnezia-bin \
  amneziavpn-bin \
  cursor-bin \
  claude-code
```

## Dotfiles

Dotfiles are installed from:

```text
https://github.com/daniilsolovey/dotfiles
```

Important mappings include:

```text
.Xresources                     → ~/.Xresources
.xinitrc                        → ~/.xinitrc
.xbindkeysrc                    → ~/.xbindkeysrc
.zshrc                          → ~/.zshrc
.tmux.conf                      → ~/.tmux.conf
.keynavrc                       → ~/.keynavrc

.config/i3/config               → ~/.config/i3/config
.config/dunst/dunstrc           → ~/.config/dunst/dunstrc
.config/favor/favor.conf        → ~/.config/favor/favor.conf

.screenlayout/                  → ~/.screenlayout/
scripts/                        → ~/Scripts/
```

All regular files in `~/Scripts` are made executable automatically.

Commands referenced by name in i3 are also installed into `~/bin`, including `translator` and `keyboard_setup.sh`.

## Services

Enabled automatically:

```text
NetworkManager.service
sshd.service
fstrim.timer
docker.service
```

# Desktop controls

The i3 modifier is:

```text
Mod4 = Super / Windows / Command
```

The hotkeys below were checked against the current `dotfiles/master` i3 config.

## Applications and utilities

| Hotkey | Action |
| --- | --- |
| `Mod + Enter` | Open URxvt with tmux |
| `Mod + S` | Area screenshot |
| `Mod + T` | Translator |
| `Mod + W` | Show `sensors-info-linux` |
| `Mod + D` | Rofi command launcher |
| `Mod + A` | Rofi window switcher |
| `Mod + F11` | `dmenu_run` |

## Audio / microphone

| Hotkey | Action |
| --- | --- |
| `Mod + F1` | Toggle output mute |
| `Mod + F2` | Volume down |
| `Mod + F3` | Volume up |
| `Mod + F4` | Toggle microphone mute |

The current audio scripts use PipeWire/WirePlumber and dunst notifications. Volume changes are in 10% steps.

## Brightness

| Hotkey | Action |
| --- | --- |
| `Mod + F5` | Brightness -10% |
| `Mod + F6` | Brightness +10% |

Brightness is controlled with `brightnessctl`.

## Displays

| Hotkey | Action |
| --- | --- |
| `Mod + F7` | Laptop-only layout |
| `Mod + Ctrl + F7` | HDMI + DisplayPort layout |

## Wi-Fi

| Hotkey | Action |
| --- | --- |
| `Mod + F8` | Wi-Fi off |
| `Mod + F9` | Wi-Fi on |

## Keyboard and lock

| Hotkey | Action |
| --- | --- |
| `Mod + F10` | Run `keyboard_setup.sh` |
| `Mod + F12` | Lock X with `slock` |

## Window focus and movement

| Hotkey | Action |
| --- | --- |
| `Ctrl + Home` | Focus left |
| `Ctrl + PageDown` | Focus down |
| `Ctrl + PageUp` | Focus up |
| `Ctrl + End` | Focus right |
| `Ctrl + Shift + Home` | Move left |
| `Ctrl + Shift + PageDown` | Move down |
| `Ctrl + Shift + PageUp` | Move up |
| `Ctrl + Shift + End` | Move right |
| `Mod + Ctrl + Q` | Kill focused window |

## Layout

| Hotkey | Action |
| --- | --- |
| `Mod + E` | Horizontal split |
| `Mod + B` | Vertical split |
| `Mod + F` | Fullscreen toggle |
| `Mod + Y` | Tabbed layout |
| `Mod + Shift + Space` | Floating toggle |
| `Mod + Space` | Toggle tiling/floating focus |
| `Mod + R` | Resize mode |

Resize mode:

```text
J / Left      shrink width
K / Down      grow height
L / Up        shrink height
; / Right     grow width
```

Exit resize mode with `Enter`, `Escape`, or `Mod + R`.

## Workspaces

Switch:

```text
Mod + 1 ... Mod + 0
```

Move focused container:

```text
Mod + Ctrl + 1 ... Mod + Ctrl + 0
```

## i3 control

| Hotkey | Action |
| --- | --- |
| `Mod + Shift + C` | Reload config |
| `Mod + Shift + R` | Restart i3 |
| `Mod + Shift + E` | Exit i3 after confirmation |

## Window switching

```text
Alt + Tab
```

runs:

```bash
i3re -h 20 || i3re -w 20
```

Rofi window selection is also available with `Mod + A`.

# Terminal hotkeys

URxvt clipboard handling is configured directly in `.Xresources`.

| Hotkey | Action |
| --- | --- |
| `Mod + C` | Copy selected terminal text |
| `Mod + V` | Paste X clipboard |

Current bindings:

```text
URxvt.keysym.Mod4-c: eval:selection_to_clipboard
URxvt.keysym.Mod4-v: eval:paste_clipboard
```

# Shell workflow

Zsh is the default shell.

The dotfiles include persistent history, Git/Go/Docker/systemctl aliases, zoxide, fzf integration and a custom prompt.

Use:

```text
Ctrl + R
```

for fzf history search.

Typical additional fzf bindings:

```text
Ctrl + T    file search
Alt + C     directory search
```

zoxide examples:

```bash
zoxide add .
zoxide query -l
z <name>
```

# System management

## Audio

```bash
wpctl status
wpctl set-volume @DEFAULT_AUDIO_SINK@ 10%-
wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 10%+
wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
```

## Brightness

```bash
brightnessctl
brightnessctl set 10%-
brightnessctl set +10%
```

## Wi-Fi

```bash
nmcli device
nmcli device wifi list
nmcli radio wifi off
nmcli radio wifi on
```

## Notifications

Config:

```text
~/.config/dunst/dunstrc
```

Reload:

```bash
dunstctl reload
```

Test:

```bash
notify-send "Test" "Notification works"
```

## System information

Run:

```bash
sensors-info-linux
```

or press `Mod + W`.

## Battery / power profiles

Inspect:

```bash
powerprofilesctl list
powerprofilesctl get
```

Typical profiles:

```text
power-saver
balanced
performance
```

## Docker

```bash
systemctl status docker
```

## SSH

```bash
systemctl status sshd
```

## VirtualBox

```bash
VBoxManage list vms
VBoxManage list runningvms
```

# Legacy xbindkeys note

The current dotfiles still contain `.xbindkeysrc` with older `amixer` and `xbacklight` entries.

The primary workstation controls are the i3 bindings documented above, which use the newer PipeWire/custom audio scripts and `brightnessctl`.

If a shortcut behaves unexpectedly, inspect both:

```text
~/.config/i3/config
~/.xbindkeysrc
```

because both i3 and xbindkeys can receive X11 keyboard events.

# Troubleshooting

Validate i3:

```bash
i3 -C -c ~/.config/i3/config
```

Reload:

```bash
i3-msg reload
```

Restart:

```bash
i3-msg restart
```

Audio:

```bash
wpctl status
aplay -l
arecord -l
```

Microphone test:

```bash
pw-record ~/test-mic.wav
```

then:

```bash
pw-play ~/test-mic.wav
```

Brightness:

```bash
brightnessctl
ls /sys/class/backlight/
```

Autologin:

```bash
systemctl cat getty@tty1
```

Dotfiles:

```bash
ls -la ~/.config/i3/config
ls -la ~/.config/dunst/dunstrc
ls -la ~/.config/favor/favor.conf
ls -la ~/Scripts
```

# First boot checklist

After a clean install:

1. Enter the LUKS passphrase.
2. Confirm automatic login to `operator`.
3. Connect Wi-Fi if required.
4. Run `startx`.
5. Verify:
   - `Mod + Enter`;
   - `Mod + C` / `Mod + V` in URxvt;
   - `Mod + S`;
   - `Mod + W`;
   - `Mod + F1/F2/F3`;
   - `Mod + F4`;
   - `Mod + F5/F6`;
   - `Mod + F8/F9`;
   - Rofi;
   - dunst;
   - audio and microphone;
   - Zsh history;
   - Go utilities under `~/go/bin`.

# v1.5 real-hardware fixes

Current `main` includes fixes found during repeated real-hardware installs:

- safer `fstab` validation;
- validation of `/` and `/efi`;
- LUKS/Btrfs resume support;
- non-destructive `--resume`;
- Reflector fallback;
- VirtualBox DKMS setup;
- tty1 autologin;
- manual `startx`;
- dunst and favor config deployment;
- executable permissions for all `~/Scripts` files;
- URxvt built-in clipboard handling;
- PipeWire/WirePlumber audio control;
- microphone mute;
- volume notifications;
- `brightnessctl` hotkeys;
- custom system-info and battery utilities.

## Notes

This installer is intentionally opinionated and tied to the associated dotfiles repository.

Before using it on another machine, review:

```text
config.sh
packages/
dotfiles.map
repositories.list
```

as well as hardware-specific X11, keyboard, display and power-management settings.
