#!/bin/bash
# ---------------------------------------------------------------------------
# Service monitor
# ---------------------------------------------------------------------------

TARGET_PORT=${1}
TARGET_SERVICE="${2}"
CHECK_INTERVAL=120
MAX_IDLE_TIME=360

IDLE_COUNTER=0
while true; do
    if systemctl is-active --quiet "\$TARGET_SERVICE"; then
        ACTIVE_CONNS=\$(ss -tn sport = :\$TARGET_PORT or dport = :\$TARGET_PORT | tail -n +2 | wc -l)
        if [ "\$ACTIVE_CONNS" -eq 0 ]; then
            ((IDLE_COUNTER += CHECK_INTERVAL))
            if [ "\$IDLE_COUNTER" -ge "\$MAX_IDLE_TIME" ]; then
                echo "No network activity detected on port \$TARGET_PORT for \$MAX_IDLE_TIME seconds. Stopping \$TARGET_SERVICE..."
                systemctl stop "\$TARGET_SERVICE"
                IDLE_COUNTER=0 # Reset counter after stopping
            fi
        else
            IDLE_COUNTER=0
        fi
    else
        IDLE_COUNTER=0
    fi
    sleep "\$CHECK_INTERVAL"
done
