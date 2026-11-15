#!/usr/bin/env bash

echo "working notify"
/usr/bin/inotifywait -m -e close_write /home/shahnebaj/Desktop/Sticky |
  while read -r ch; do 
    if [[ "$ch" == *"CLOSE_WRITE"* ]]; then
      echo "$ch from notify.sh" >> /home/shahnebaj/sticky/logs/lock.log
          next=$(( (RANDOM + 1) / 4096 ))
          /home/shahnebaj/sticky/glass_sticky.sh /home/shahnebaj/sticky/wallpapers/Slideshow/"$next".jpg  /home/shahnebaj/Desktop/Sticky/* /home/shahnebaj/sticky/wallpapers/Target/Sticky.png
          /home/shahnebaj/sticky/sticky.sh
    fi
  done
