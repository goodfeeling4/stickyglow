#!/usr/bin/env bash

gdbus monitor --system --dest org.freedesktop.login1 | \
while read -r line; do
        echo "iterate" >> /home/shahnebaj/sticky/logs/lock.log
    if [[ "$line" == *"org.freedesktop.login1.Session.Lock"* ]]; then
        echo "Screen Locked" >> /home/shahnebaj/sticky/logs/lock.log
        /home/shahnebaj/sticky/normal.sh
        
    elif [[ "$line" == *"org.freedesktop.login1.Manager.PrepareForSleep (true,)"* ]]; then
        echo "suspended" >> /home/shahnebaj/sticky/logs/lock.log
        /home/shahnebaj/sticky/normal.sh

    elif [[ "$line" == *"org.freedesktop.login1.Manager.PrepareForShutdownWithMetadata"* ]]; then
        echo "shutdown or restart" >> /home/shahnebaj/sticky/logs/lock.log
        /home/shahnebaj/sticky/normal.sh

    elif [[ "$line" == *"org.freedesktop.login1.Manager.UserNew"* ]]; then
        echo "logout" >> /home/shahnebaj/sticky/logs/lock.log
        /home/shahnebaj/sticky/normal.sh

    elif [[ "$line" == *"org.freedesktop.login1.Manager.UserRemoved"* ]]; then
        echo "login" >> /home/shahnebaj/sticky/logs/lock.log
        /home/shahnebaj/sticky/sticky.sh

    fi
done
