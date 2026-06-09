#!/data/data/com.termux/files/usr/bin/bash

# Configuration
WORKDIR="$HOME/arrFin"
CONTROL_SCRIPT="$WORKDIR/service-control.sh"
PID_FILE="$WORKDIR/.battery_monitor.pid"
THRESHOLD=50
CHECK_INTERVAL=120 # Seconds

monitor_loop() {
    # Initial state: start as "none" to force a log/check on the first run
    CURRENT_MODE="none"
    HEARTBEAT_COUNT=0
    
    mkdir -p "$WORKDIR/logs"
    echo "$(date): Battery monitor started (PID: $$)" >> "$WORKDIR/logs/monitor.log"
    
    while true; do
        # Get battery info
        BATTERY_INFO=$(termux-battery-status 2>/dev/null)
        
        # Defensive parsing: default to 0 if API fails or percentage is missing
        LEVEL=$(echo "$BATTERY_INFO" | jq -r '.percentage // 0')
        STATUS=$(echo "$BATTERY_INFO" | jq -r '.status // "DISCHARGING"')
        
        # Ensure LEVEL is a valid integer
        if [[ ! "$LEVEL" =~ ^[0-9]+$ ]]; then LEVEL=0; fi
        
        # Logic: 
        # Full Power if Level > THRESHOLD OR Status == "CHARGING" OR Status == "FULL"
        # Eco Power if Level <= THRESHOLD AND Status != "CHARGING" AND Status != "FULL"
        
        if [[ "$LEVEL" -gt "$THRESHOLD" || "$STATUS" == "CHARGING" || "$STATUS" == "FULL" ]]; then
            TARGET_MODE="full"
        else
            TARGET_MODE="eco"
        fi
        
        # Transition logic
        if [[ "$TARGET_MODE" != "$CURRENT_MODE" ]]; then
            echo "$(date): Battery at $LEVEL%, Status: $STATUS. Mode: $TARGET_MODE" >> "$WORKDIR/logs/monitor.log"
            
            # CHECK FOR MANUAL OVERRIDE
            if [[ -f "$WORKDIR/.manual_mode" ]]; then
                echo "$(date): [SKIP] Manual override active. Not applying $TARGET_MODE mode." >> "$WORKDIR/logs/monitor.log"
            else
                if [[ "$TARGET_MODE" == "full" ]]; then
                    bash "$CONTROL_SCRIPT" start-all --auto
                else
                    bash "$CONTROL_SCRIPT" stop-eco --auto
                fi
                CURRENT_MODE="$TARGET_MODE"
            fi
            HEARTBEAT_COUNT=0 # Reset on transition
        else
            # Heartbeat log (every 5 checks approx 10 minutes)
            ((HEARTBEAT_COUNT++))
            if (( HEARTBEAT_COUNT >= 5 )); then
                 MODE_LABEL="$CURRENT_MODE"
                 [[ -f "$WORKDIR/.manual_mode" ]] && MODE_LABEL="$CURRENT_MODE (MANUAL 🕹️)"
                 echo "$(date): Heartbeat - Level: $LEVEL%, Status: $STATUS, Mode: $MODE_LABEL" >> "$WORKDIR/logs/monitor.log"
                 HEARTBEAT_COUNT=0
            fi
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

case "$1" in
    --start)
        if [[ -f "$PID_FILE" ]]; then
            PID=$(cat "$PID_FILE")
            if kill -0 "$PID" 2>/dev/null; then
                echo "Battery monitor already running (PID: $PID)"
                exit 0
            fi
        fi
        nohup "$0" --run >> "$WORKDIR/logs/monitor.log" 2>&1 &
        echo $! > "$PID_FILE"
        echo "Battery monitor started in background."
        ;;
    --stop)
        if [[ -f "$PID_FILE" ]]; then
            PID=$(cat "$PID_FILE")
            kill "$PID" 2>/dev/null
            rm "$PID_FILE"
            echo "Battery monitor stopped."
        else
            echo "Battery monitor is not running."
        fi
        ;;
    --run)
        monitor_loop
        ;;
    *)
        echo "Usage: $0 {--start|--stop}"
        exit 1
        ;;
esac
