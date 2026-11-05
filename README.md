# quickshell-theme

whole-desktop dotfiles: the quickshell shell plus hyprland, matugen and the apps around them. every top-level directory is a stow package.

## packages

| package | what |
|---|---|
| `quickshell` | the shell: bar + dynamic island (media / usage / theme / volume / capture / session / notifications), launcher, lockscreen, notifications, matugen theming |
| `hypr` | hyprland config (pure lua — `hyprland.lua` requires animations/effects/keybinds) + a dormant hyprlock fallback config |
| `matugen` | wallpaper → palette templates for hypr, rofi, kitty, cava, quickshell |
| `rofi` | launcher + wallpaper/power menus — drun replaced by the quickshell launcher |
| `kitty` `cava` `btop` `fastfetch` | terminal, audio visualiser, system monitor, fetch |
| `bash` `zsh` | shell rc files |
| `OpenTabletDriver` | tablet profile |

## install

```bash
./install.sh                  # all packages (dry-run + conflict backup first)
./install.sh hypr quickshell  # named packages only
```

stow-based; conflicts are backed up to `~/.dotfiles-backup-<timestamp>/`. pre-existing symlinks must be removed by hand first. never `stow .` — the repo root is not a package.

## run

```bash
qs                          # the shell (default instance)
qs -p ~/.config/quickshell  # explicit path
qs ipc call launcher toggle # launcher from a keybind
```

## dependencies

arch package names. `./install.sh` checks for the binaries before it stows and warns about anything missing — the one fatal case is `qt6-websockets`, which the config imports at load time.

### required

| package | what breaks without it |
|---|---|
| `quickshell` (aur), `qt6-declarative` | the shell |
| `qt6-websockets` | **the config will not load** — `Capture.qml` imports `QtWebSockets` |
| `hyprland` (lua-config build) | compositor |
| `matugen`, `awww` | palette regeneration and wallpaper transitions |
| `rofi` | the wallpaper and power menus |
| `kitty` | the terminal (SUPER+Return) |
| `networkmanager` (`nmcli`) | the bar's network readout and the wifi tile |
| `pipewire` (`wpctl`), `libpulse` (`pactl`) | volume readout, media transport, per-app sliders |
| `brightnessctl` | the theme page's brightness slider |
| `playerctl` | media transport controls |
| `cava` | the media page's visualiser |
| `hyprshot`, `hyprpicker`, `slurp`, `grim` | the capture page's screenshot row, and hyprland's own screenshot keybinds |
| `wl-clipboard` (`wl-copy`, `wl-paste`), `cliphist` | clipboard writes and the capture page's clipboard history |
| `hyprpolkitagent` | the autostart's polkit agent |
| `libnotify` (`notify-send`) | screenshot and recording confirmations |
| `bluez-utils` (`bluetoothctl`), `util-linux` (`rfkill`) | the control centre's bluetooth tile — power-on clears the rfkill soft block first |
| `power-profiles-daemon` (`powerprofilesctl`) | the control centre's battery saver tile |

### fonts

not packages — all four are hand-installed into `~/.local/share/fonts`, which is why they are easy to lose on a fresh box and why nothing above catches them.

- `Montserrat SemiBold` — the bar's UI font
- `JetBrainsMonoNL Nerd Font` — every status glyph; tofu without it
- `Rubik`, `MartianMono Nerd Font` — hyprlock, now only the lockscreen's dormant fallback

cursor: `capitaine-cursors-light`, set by the autostart and `HYPRCURSOR_THEME`.

### optional

degrades rather than dies.

- `obs-websocket` (the OBS plugin) — the capture page's record row reads "OBS offline" without it
- `nvidia-utils` (`nvidia-smi`) — the usage page's GPU cell reads `n/a`
- `wf-recorder` — an alternative record backend
- `hyprlock` — the lockscreen's fallback if the shell's own PAM stack cannot be opened at all; the session page's lock cell is Quickshell's own now
- `qt6-imageformats` — the two `.webp` wallpapers render as bare plates without it (installed)

### keybind targets

in `hypr/.config/hypr/keybinds.lua`, but these are your apps rather than the shell's requirements: `discord`, `google-chrome-stable`, `thunar`, `otd-daemon` (opentabletdriver).

## notes

- matugen regenerates five files on every wallpaper pick, `Theme/Colors.qml` among them — they are tracked but marked `skip-worktree`, so the repo holds their seed content and git never sees the regenerated copies.
- rofi wallpapers (~217MB) are gitignored and live only on disk.
- migrated from `~/hypr-dotfiles` (12 packages, imported verbatim in `e341109`); that repo is a read-only archive pending burn-in.

## status

bar + launcher + notifications + lockscreen live; osd still stubbed, session menu lives in the island.
