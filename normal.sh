#!/usr/bin/env bash
next=$(( (RANDOM + 1) / 4096 ))

cp /home/shahnebaj/stickN/wallpapers/Slideshow/"$next".jpg /home/shahnebaj/stickN/wallpapers/Target/normal.png
cp /home/shahnebaj/stickN/setting_conf/normal ~/.config/cosmic/com.system76.CosmicBackground/v1/all

pkill -9 -f "/home/shahnebaj/stickN/glass_sticky.sh"
pkill cosmic-bg
