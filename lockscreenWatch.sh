#!/usr/bin/env bash

gdbus monitor --system --dest org.freedesktop.login1 | \
while read -r line; do
        echo "iterate" >> /home/shahnebaj/stickN/logs/lock.log
    if [[ "$line" == *"org.freedesktop.login1.Session.Lock"* ]]; then
        echo "Screen Locked" >> /home/shahnebaj/stickN/logs/lock.log
        /home/shahnebaj/stickN/normal.sh
        
    elif [[ "$line" == *"org.freedesktop.login1.Manager.PrepareForSleep (true,)"* ]]; then
        echo "suspended" >> /home/shahnebaj/stickN/logs/lock.log
        /home/shahnebaj/stickN/normal.sh

    elif [[ "$line" == *"org.freedesktop.login1.Manager.PrepareForShutdownWithMetadata"* ]]; then
        echo "shutdown or restart" >> /home/shahnebaj/stickN/logs/lock.log
        /home/shahnebaj/stickN/normal.sh

    elif [[ "$line" == *"org.freedesktop.login1.Manager.UserNew"* ]]; then
        echo "logout" >> /home/shahnebaj/stickN/logs/lock.log
        /home/shahnebaj/stickN/normal.sh

    elif [[ "$line" == *"org.freedesktop.login1.Manager.UserRemoved"* ]]; then
        echo "login" >> /home/shahnebaj/stickN/logs/lock.log
        /home/shahnebaj/stickN/sticky.sh

    fi
done
