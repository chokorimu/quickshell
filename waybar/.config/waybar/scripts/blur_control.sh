#!/bin/bash

CURRENT=$(hyprctl getoption decoration:blur:enabled -j | jq '.int')

if [ "$CURRENT" == "1" ]; then
    hyprctl --batch "\
        keyword decoration:blur:enabled 0;\
        keyword decoration:active_opacity 1.0;\
        keyword decoration:inactive_opacity 1.0"

    notify-send -u low -t 2000 "Hyprctl Toggle" "(Blur Off, Transparency Off)"

else
    hyprctl --batch "\
        keyword decoration:blur:enabled 1;\
        keyword decoration:active_opacity 0.95;\
        keyword decoration:inactive_opacity 0.95"
        
    notify-send -u low -t 2000 "Hyprctl Toggle" "(Blur On, Transparency On)"
fi