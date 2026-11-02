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
