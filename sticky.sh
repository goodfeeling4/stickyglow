#!/usr/bin/env bash
CONF_DIR="$HOME/.config/cosmic/com.system76.CosmicBackground/v1"
CONF="$CONF_DIR/all"

base=$(sed -n 's/^ *rotation_frequency: \([0-9]*\),/\1/p' /home/shahnebaj/sticky/setting_conf/sticky | head -n 1)
base=${base:-300}
cur=$(sed -n 's/^ *rotation_frequency: \([0-9]*\),/\1/p' "$CONF" 2>/dev/null | head -n 1)
new=$(( cur == base ? base + 1 : base ))

sed "s/^\( *rotation_frequency: \)[0-9]*,\$/\1${new},/" /home/shahnebaj/sticky/setting_conf/sticky > "$CONF_DIR/.atomicwrite-sticky.tmp"
mv "$CONF_DIR/.atomicwrite-sticky.tmp" "$CONF"
