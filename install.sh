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

echo
echo "done."
echo "note: wallpapers in ~/.config/rofi/wallpapers/ are not tracked by git."
