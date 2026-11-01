# quickshell-theme

whole-desktop dotfiles: the quickshell shell plus hyprland, matugen and the apps around them. every top-level directory is a stow package.

## packages

| package | what |
|---|---|
| `quickshell` | the shell: bar + dynamic island, launcher, osd, notifications, session menu, matugen theming |
| `hypr` | hyprland config (pure lua — `hyprland.lua` requires animations/effects/keybinds) + hyprlock |
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

- `quickshell` (aur), `qt6-declarative`
- hyprland with lua config support, matugen + awww
- rofi — still live for the wallpaper/power menus until the quickshell modules replace them
- kitty, cava, btop, fastfetch, NetworkManager, pipewire (`wpctl`), brightnessctl, playerctl

## notes

- matugen has no quickshell template yet — `Theme/Colors.qml` keeps its catppuccin defaults until one exists.
- rofi wallpapers (~217MB) are gitignored and live only on disk.
- migrated from `~/hypr-dotfiles` (12 packages, imported verbatim in `e341109`); that repo is a read-only archive pending burn-in.

## status

bar + launcher + notifications live; osd still stubbed, session menu lives in the island.
