#!/usr/bin/env bash
#
# install.sh — deploy these dotfiles with GNU Stow
#
# This repo is the whole desktop: the Quickshell shell plus Hyprland,
# matugen and the apps around them. Every top-level directory is a stow
# package containing .config/<app>/ (or a dotfile at its root).
#
# Usage:
#   ./install.sh              # stow every package
#   ./install.sh hypr quickshell  # stow only the named packages
#
# Existing files that conflict with the repo are moved to
# ~/.dotfiles-backup-<timestamp>/ before stowing. Note: pre-existing
# SYMLINKS are not backed up — remove them by hand first.
#
# After stowing, matugen's five output files (see
# matugen/.config/matugen/config.toml) are marked skip-worktree so the
# palettes matugen regenerates on every wallpaper pick never show up as
# repo changes. They stay tracked — stow deploys them and the apps read
# them before matugen has ever run — the repo just holds their seed
# content. This is safe to re-run.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

ALL_PACKAGES=(quickshell hypr rofi kitty cava btop fastfetch matugen bash zsh OpenTabletDriver)

PACKAGES=("$@")
[ ${#PACKAGES[@]} -eq 0 ] && PACKAGES=("${ALL_PACKAGES[@]}")

# --- sanity checks -------------------------------------------------------

if ! command -v stow >/dev/null 2>&1; then
    echo "error: GNU Stow not found. Install it first:  sudo pacman -S stow" >&2
    exit 1
fi

for pkg in "${PACKAGES[@]}"; do
    if [ ! -d "$REPO_DIR/$pkg" ]; then
        echo "error: no package '$pkg' in $REPO_DIR" >&2
        exit 1
    fi
done

# --- dependency pre-flight ---------------------------------------------
#
# A warning, not a gate. Almost everything here degrades rather than
# dies: a missing hyprshot leaves the capture page's screenshot row
# dead, a missing nvidia-smi leaves the usage page's GPU cell reading
# n/a. The one exception is qt6-websockets — Capture.qml imports
# QtWebSockets at load time, so a missing module is a config that will
# not start at all rather than a feature that is switched off. That one
# is fatal, and only when the quickshell package is in play.
#
# Package names are Arch's. The list is the point, not the manager.

# binary|package|what breaks without it
RUNTIME_DEPS=(
    "matugen|matugen|palette regeneration on every wallpaper pick"
    "awww|awww|wallpaper transitions"
    "rofi|rofi|the wallpaper and power menus"
    "kitty|kitty|the terminal (SUPER+Return)"
    "nmcli|networkmanager|the bar's network readout and the wifi tile"
    "wpctl|pipewire|volume readout and the media transport"
    "pactl|libpulse|the volume page's per-app sliders"
    "brightnessctl|brightnessctl|the theme page's brightness slider"
    "playerctl|playerctl|media transport controls"
    "hyprlock|hyprlock|the session page's lock cell"
    "hyprshot|hyprshot|the capture page's screenshot row"
    "hyprpicker|hyprpicker|hyprshot's region freeze"
    "slurp|slurp|region selection, hyprshot's and hyprland's own"
    "grim|grim|hyprland's own screenshot keybinds"
    "wl-copy|wl-clipboard|clipboard writes and the cliphist watcher exec-once"
    "cliphist|cliphist|the capture page's clipboard history"
    "notify-send|libnotify|screenshot and recording confirmations"
    "bluetoothctl|bluez-utils|the bluetooth tile"
    "rfkill|util-linux|bluetooth power-on, which clears the soft block"
    "powerprofilesctl|power-profiles-daemon|the battery saver tile"
    "cava|cava|the media page's visualiser"
)

# degrades to n/a, an offline line, or nothing at all
OPTIONAL_DEPS=(
    "nvidia-smi|nvidia-utils|the usage page's GPU cell reads n/a"
    "wf-recorder|wf-recorder|an alternative record backend"
    "otd-daemon|opentabletdriver|the tablet daemon in the autostart"
)

# Not binaries, so they cannot be command -v'd. None of these is a
# package on this box — all four are hand-installed into
# ~/.local/share/fonts, which is exactly why they are easy to lose on a
# fresh machine and why nothing else here catches them.
FONTS=(
    "Montserrat SemiBold|the bar's UI font"
    "JetBrainsMonoNL Nerd Font|every status glyph — tofu without it"
    "Rubik|hyprlock"
    "MartianMono Nerd Font|hyprlock"
)

missing_runtime=()
missing_optional=()
missing_fonts=()

for entry in "${RUNTIME_DEPS[@]}"; do
    IFS='|' read -r bin pkg what <<<"$entry"
    command -v "$bin" >/dev/null 2>&1 || missing_runtime+=("$pkg — $what")
done

for entry in "${OPTIONAL_DEPS[@]}"; do
    IFS='|' read -r bin pkg what <<<"$entry"
    command -v "$bin" >/dev/null 2>&1 || missing_optional+=("$pkg — $what")
done

# fc-list : family emits comma-SPACE separated families, so after the tr
# every line but the first carries a leading space — trim it, or grep -x
# misses every family that is not listed first.
#
# Read once, into a variable, and match against the variable rather than
# piping into grep -q. grep -q exits on its first match, and fc-list is
# still writing the full system font list at that point, so it takes
# SIGPIPE and dies 141 — which `set -o pipefail` turns into a failed
# pipeline even though the font was found. Measured flaky at roughly one
# run in three, failing on a different font each time. A herestring has
# no upstream to signal, so it cannot race.
font_families="$(fc-list : family 2>/dev/null | tr ',' '\n' | sed 's/^ *//; s/ *$//')"

for entry in "${FONTS[@]}"; do
    IFS='|' read -r family what <<<"$entry"
    grep -ix "$family" <<<"$font_families" >/dev/null \
        || missing_fonts+=("$family — $what")
done

if [ ${#missing_runtime[@]} -gt 0 ]; then
    echo "warning: ${#missing_runtime[@]} runtime dependencies not found:" >&2
    printf '    %s\n' "${missing_runtime[@]}" >&2
fi

if [ ${#missing_optional[@]} -gt 0 ]; then
    echo "note: ${#missing_optional[@]} optional dependencies not found:" >&2
    printf '    %s\n' "${missing_optional[@]}" >&2
fi

if [ ${#missing_fonts[@]} -gt 0 ]; then
    echo "note: ${#missing_fonts[@]} font(s) not found — install into ~/.local/share/fonts:" >&2
    printf '    %s\n' "${missing_fonts[@]}" >&2
fi

want_quickshell=0
for pkg in "${PACKAGES[@]}"; do
    if [ "$pkg" = "quickshell" ]; then
        want_quickshell=1
    fi
done

if [ "$want_quickshell" -eq 1 ] && [ ! -d /usr/lib/qt6/qml/QtWebSockets ]; then
    echo "error: qt6-websockets not found. Capture.qml imports QtWebSockets, so" >&2
    echo "       the shell will not load without it:  sudo pacman -S qt6-websockets" >&2
    exit 1
fi

# --- stow ----------------------------------------------------------------

for pkg in "${PACKAGES[@]}"; do
    echo "==> $pkg"

    # Dry-run first. On conflict, move the offending real files aside.
    if ! stow --dir="$REPO_DIR" --target="$HOME" --no --verbose=1 "$pkg" >/dev/null 2>&1; then
        conflicts=$(stow --dir="$REPO_DIR" --target="$HOME" --no --verbose=1 "$pkg" 2>&1 \
            | sed -n 's/.*over existing target \(.*\) since.*/\1/p' || true)

        if [ -n "$conflicts" ]; then
            echo "    conflicts found — backing up to $BACKUP_DIR"
            while IFS= read -r rel; do
                src="$HOME/$rel"
                if [ -f "$src" ] && [ ! -L "$src" ]; then
                    mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
                    mv "$src" "$BACKUP_DIR/$rel"
                    echo "    backed up ~/$rel"
                fi
            done <<< "$conflicts"
        fi
    fi

    stow --dir="$REPO_DIR" --target="$HOME" --restow "$pkg"
done

# --- matugen outputs: tracked, but their changes ignored --------------------
#
# matugen rewrites five files on every wallpaper pick — its output_paths in
# matugen/.config/matugen/config.toml. They have to stay in the repo: stow
# deploys them and the apps read them before matugen has ever run, so the
# repo holds the seed content. What they hold after that is a runtime
# artifact, so they are marked skip-worktree and git leaves the working-tree
# copy alone — which is what keeps `git status` clean after a wallpaper
# change. The flag lives in .git/index, not in a commit, so a fresh clone
# comes up unmarked and dirty; that is why this is here and not only in
# AGENTS.md.
#
# Idempotent, and a path that is not tracked (a partial checkout) is skipped
# rather than failing the install.

MATUGEN_OUTPUTS=(
    quickshell/.config/quickshell/Theme/Colors.qml
    hypr/.config/hypr/config/colors.lua
    kitty/.config/kitty/custom.conf
    cava/.config/cava/themes/custom
    rofi/.config/rofi/colors.rasi
)

if [ -d "$REPO_DIR/.git" ] && command -v git >/dev/null 2>&1; then
    marked=0
    for f in "${MATUGEN_OUTPUTS[@]}"; do
        if git -C "$REPO_DIR" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
            git -C "$REPO_DIR" update-index --skip-worktree "$f"
            marked=$((marked + 1))
        fi
    done
    if [ "$marked" -gt 0 ]; then
        echo "==> $marked matugen output(s) marked skip-worktree — their changes no longer show in git status"
    fi
fi

echo
echo "done."
echo "note: wallpapers in ~/.config/rofi/wallpapers/ are not in the repo at all."
echo "note: matugen's five output files ARE in the repo but are marked"
echo "      skip-worktree, so their regenerated contents are never tracked."
