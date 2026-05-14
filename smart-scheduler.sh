#!/data/data/com.termux/files/usr/bin/bash

WORKDIR="$HOME/arrFin"
LOG="$WORKDIR/logs/scheduler.log"

echo "$(date): Scheduler wake-up triggered." >> "$LOG"

# 1. Run the monitor logic once to start what is needed
# This will also stop things if they are no longer needed
bash "$WORKDIR/battery-monitor.sh" --run-once

# 2. Calculate the optimal next wake-up time
NEXT_EVENT=$(bash "$WORKDIR/check-needs.sh" next)
NEEDS=$(bash "$WORKDIR/check-needs.sh" all)

# Default: 6 hours (21600000 ms) safety heartbeat
NEXT_CHECK_MS=21600000 

if echo "$NEEDS" | grep -vE "IDLE" | grep -qE "MISSING|ACTIVE"; then
    # We are busy! Check every 15 minutes to finish the job
    NEXT_CHECK_MS=900000
    echo "$(date): Media active or missing. Setting 15-min check." >> "$LOG"
elif [[ -n "$NEXT_EVENT" ]]; then
    # Calculate milliseconds until 1 hour after release
    NOW_S=$(date +%s)
    # Ensure date parsing works with the 'Z' suffix or space
    EVENT_S=$(date -d "${NEXT_EVENT/Z/}" +%s)
    TARGET_S=$(( EVENT_S + 3600 )) # Release + 1 hour
    
    DIFF_S=$(( TARGET_S - NOW_S ))
    
    if [[ "$DIFF_S" -gt 900 ]]; then
        # If the show is far away, sleep until then, but max 6 hours
        NEXT_CHECK_MS=$(( DIFF_S * 1000 ))
        [[ "$NEXT_CHECK_MS" -gt 21600000 ]] && NEXT_CHECK_MS=21600000
        echo "$(date): Next show at $NEXT_EVENT. Sleeping for $((DIFF_S / 60)) minutes." >> "$LOG"
    else
        # Show is coming very soon or just passed
        NEXT_CHECK_MS=900000
        echo "$(date): Show imminent or just aired. Setting 15-min check." >> "$LOG"
    fi
else
    echo "$(date): No upcoming media in DB. Using 6-hour heartbeat." >> "$LOG"
fi

# 3. Register the system job with the dynamic interval
termux-job-scheduler -s "$WORKDIR/smart-scheduler.sh" \
    --period-ms "$NEXT_CHECK_MS" \
    --persisted true \
    --battery-not-low true
