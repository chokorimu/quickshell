#!/bin/bash

lock="$HOME/.config/rofi/icons/lock_256dp_E3E3E3_FILL1_wght400_GRAD200_opsz48.png"
logout="$HOME/.config/rofi/icons/exit_to_app_256dp_E3E3E3_FILL1_wght400_GRAD200_opsz48.png"
suspend="$HOME/.config/rofi/icons/pause_256dp_E3E3E3_FILL1_wght400_GRAD200_opsz48.png"
reboot="$HOME/.config/rofi/icons/replay_256dp_E3E3E3_FILL1_wght400_GRAD200_opsz48.png"
poweroff="$HOME/.config/rofi/icons/mode_off_on_256dp_E3E3E3_FILL1_wght400_GRAD200_opsz48.png"

if [ -z "$@" ]; then
    echo -en "Lock\0icon\x1f$lock\n"
    echo -en "Logout\0icon\x1f$logout\n"
    echo -en "Suspend\0icon\x1f$suspend\n"
    echo -en "Reboot\0icon\x1f$reboot\n"
    echo -en "Poweroff\0icon\x1f$poweroff\n"
else
    case "$1" in
        "Lock") 
            (sleep 0.5; hyprlock) >/dev/null 2>&1 & 
            ;;
        "Logout") 
            (sleep 0.5; hyprctl dispatch exit) >/dev/null 2>&1 & 
            ;;
        "Suspend") 
            (sleep 0.5; systemctl suspend) >/dev/null 2>&1 & 
            ;;
        "Reboot") 
            (sleep 0.5; systemctl reboot) >/dev/null 2>&1 & 
            ;;
        "Poweroff") 
            (sleep 0.5; systemctl poweroff) >/dev/null 2>&1 & 
            ;;
    esac
    exit 0
fi