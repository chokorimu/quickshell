#!/bin/bash

WALL_DIR="$HOME/.config/rofi/wallpapers/"
TRANSITION_TYPE="grow" # Options: grow, outer, random, wave
TRANSITION_DURATION="2.5"

if [ -z "$@" ]; then
    find "$WALL_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.jpeg" -o -iname "*.gif" \) -print0 | \
    sort -z | \
    while IFS= read -r -d '' file; do
        filename=$(basename "$file")
        echo -en "${filename}\0icon\x1f${file}\n"
    done
else
    SELECTED_FILE="$WALL_DIR/$1"
    awww img "$SELECTED_FILE" \
        --transition-type $TRANSITION_TYPE \
        --transition-duration $TRANSITION_DURATION \
        --transition-fps 60
        
    matugen image "$SELECTED_FILE" --prefer saturation
    notify-send "Theme Changed" "Wallpaper: $1"
fi