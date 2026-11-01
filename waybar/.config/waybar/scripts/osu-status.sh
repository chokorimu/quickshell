#!/bin/bash

WINDOW=$(hyprctl activewindow -j)

CLASS=$(echo "$WINDOW" | jq -r '.class')
TITLE=$(echo "$WINDOW" | jq -r '.title')

if [[ "$CLASS" =~ "osu" ]]; then
    CLEAN_TITLE=$(echo "$TITLE" | sed 's/ - osu!$//;s/^osu! - //')
    
    if [ "$CLEAN_TITLE" = "osu!" ]; then
        jq -n --unbuffered --compact-output \
            --arg text "Selecting a beatmap" \
            --arg class "selecting" \
            '{text: $text, class: $class}'
    else
        jq -n --unbuffered --compact-output \
            --arg text " $CLEAN_TITLE" \
            --arg class "playing" \
            '{text: $text, class: $class}'
    fi  
else
    echo ""
fi