#!/usr/bin/env bash

echo "working notify"
/usr/bin/inotifywait -m -e close_write /home/shahnebaj/Desktop/Sticky |
  while read -r ch; do 
    if [[ "$ch" == *"CLOSE_WRITE"* ]]; then
      echo "$ch from notify.sh" >> /home/shahnebaj/stickN/logs/lock.log
          next=$(( (RANDOM + 1) / 4096 ))
          /home/shahnebaj/stickN/glass_sticky.sh /home/shahnebaj/stickN/wallpapers/Slideshow/"$next".jpg  /home/shahnebaj/Desktop/Sticky/* /home/shahnebaj/stickN/wallpapers/Target/Sticky.png
          /home/shahnebaj/stickN/sticky.sh
    fi
  done
