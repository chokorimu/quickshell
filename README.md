# quickshell-theme

quickshell shell for hyprland — bar, launcher, notifications, osd, session menu, matugen theming.

scaffolded against quickshell 1.x. verify api details against the installed version (`qs --version`) — the 0.x → 1.x jump moved a few things around (`Quickshell.screens`, `SystemClock.Seconds`, `Hyprland.workspaces` fields, `PanelWindow.exclusiveZone`).

## structure

| path | what |
|---|---|
| `shell.qml` | root `ShellRoot` — one bar per monitor via `Variants` |
| `Modules/Bar` | top bar: workspaces, clock (waybar replacement) |
| `Modules/Launcher` | app launcher (rofi replacement) |
| `Modules/Notifications` | notification popups (swaync replacement) |
| `Modules/OSD` | volume / brightness on-screen display |
| `Modules/Session` | power menu: lock, logout, reboot, shutdown |
| `Services/Matugen` | wallpaper → palette regeneration |
| `Theme` | `Theme` singleton + `Colors` palette |

## install

stow-based, same pattern as `hypr-dotfiles`:

```bash
cd ~/quickshell-theme
stow --dir=. --target="$HOME" .
```

symlinks `~/.config/quickshell` → `~/quickshell-theme/.config/quickshell`.

## run

```bash
qs                          # default instance
qs -p ~/.config/quickshell  # explicit path
```

## dependencies

- `quickshell` (aur: `quickshell`, or `quickshell-git` for bleeding edge)
- `qt6-declarative`
- matugen + awww — already part of the hypr-dotfiles setup

## wiring into hyprland

once the bar is ready, swap `waybar` for `qs` in `hypr/.config/hypr/keybinds.lua` autostart:

```lua
hl.exec_cmd("qs")
```

## status

scaffold — bar renders workspaces + clock, everything else is stubbed.
