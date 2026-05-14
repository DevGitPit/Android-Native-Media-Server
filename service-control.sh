#!/data/data/com.termux/files/usr/bin/bash

# Configuration
WORKDIR="$HOME/arrFin"
BAZARR_PATH="$PREFIX/opt/bazarr/bazarr.py"
LOG_DIR="$WORKDIR/logs"
PID_DIR="$WORKDIR/pids"
mkdir -p "$LOG_DIR" "$PID_DIR"

# .NET Environment
export DOTNET_ROOT=$PREFIX/lib/dotnet
export LD_LIBRARY_PATH=$PREFIX/lib

notify() {
    termux-notification -t "Media Server" -c "$1" \
        --id "arrfin_status" \
        --priority "high" \
        --button1 "START" --button1-action "bash $WORKDIR/service-control.sh start-all" \
        --button2 "ECO" --button2-action "bash $WORKDIR/service-control.sh stop-eco" \
        --button3 "STOP" --button3-action "bash $WORKDIR/service-control.sh stop-all"
}

start_jellyfin() {
    echo "$(date): Starting Jellyfin (via sv)..." >> "$LOG_DIR/jellyfin.log"
    sv up jellyfin 2>/dev/null || jellyfin > "$LOG_DIR/jellyfin_run.log" 2>&1 &
}

start_transmission() {
    echo "$(date): Starting Transmission (via sv)..." >> "$LOG_DIR/transmission.log"
    sv up transmission 2>/dev/null || transmission-daemon -w ~/media/downloads -T 2>/dev/null
}

start_sonarr() {
    if ! pgrep -f "Sonarr.dll" > /dev/null; then
        echo "$(date): Starting Sonarr..." >> "$LOG_DIR/sonarr.log"
        ( echo "$BASHPID" > "$PID_DIR/sonarr_watchdog.pid"; while true; do dotnet "$PREFIX/opt/Sonarr/Sonarr.dll" -nobrowser >> "$LOG_DIR/sonarr.log" 2>&1; sleep 10; done ) &
    fi
}

start_radarr() {
    if ! pgrep -f "Radarr.dll" > /dev/null; then
        echo "$(date): Starting Radarr..." >> "$LOG_DIR/radarr.log"
        ( echo "$BASHPID" > "$PID_DIR/radarr_watchdog.pid"; while true; do dotnet "$PREFIX/opt/Radarr/Radarr.dll" -nobrowser >> "$LOG_DIR/radarr.log" 2>&1; sleep 10; done ) &
    fi
}

start_prowlarr() {
    if ! pgrep -f "Prowlarr.dll" > /dev/null; then
        echo "$(date): Starting Prowlarr..." >> "$LOG_DIR/prowlarr.log"
        ( echo "$BASHPID" > "$PID_DIR/prowlarr_watchdog.pid"; while true; do dotnet "$PREFIX/opt/Prowlarr/Prowlarr.dll" -nobrowser >> "$LOG_DIR/prowlarr.log" 2>&1; sleep 10; done ) &
    fi
}

start_arr_apps() {
    start_prowlarr
    start_radarr
    start_sonarr
}

start_bazarr() {
    if ! pgrep -f "bazarr.*main.py" > /dev/null; then
        echo "$(date): Starting Bazarr..." >> "$LOG_DIR/bazarr.log"
        python "$BAZARR_PATH" >> "$LOG_DIR/bazarr.log" 2>&1 &
    fi
}

stop_sonarr() {
    echo "Stopping Sonarr watchdog and process..."
    if [ -f "$PID_DIR/sonarr_watchdog.pid" ]; then
        PID=$(cat "$PID_DIR/sonarr_watchdog.pid")
        kill "$PID" 2>/dev/null
        rm "$PID_DIR/sonarr_watchdog.pid"
    fi
    pkill -f "/dotnet.*/opt/Sonarr"
}

stop_radarr() {
    echo "Stopping Radarr watchdog and process..."
    if [ -f "$PID_DIR/radarr_watchdog.pid" ]; then
        PID=$(cat "$PID_DIR/radarr_watchdog.pid")
        kill "$PID" 2>/dev/null
        rm "$PID_DIR/radarr_watchdog.pid"
    fi
    pkill -f "/dotnet.*/opt/Radarr"
}

stop_prowlarr() {
    echo "Stopping Prowlarr watchdog and process..."
    if [ -f "$PID_DIR/prowlarr_watchdog.pid" ]; then
        PID=$(cat "$PID_DIR/prowlarr_watchdog.pid")
        kill "$PID" 2>/dev/null
        rm "$PID_DIR/prowlarr_watchdog.pid"
    fi
    pkill -f "/dotnet.*/opt/Prowlarr"
}

stop_arr_apps() {
    stop_sonarr
    stop_radarr
    stop_prowlarr
}

stop_bazarr() {
    echo "Stopping Bazarr..."
    # Try graceful SIGTERM first
    pkill -f "/python.*/opt/bazarr/bazarr/main.py"
    pkill -f "/python.*/opt/bazarr/bazarr.py"
    sleep 2
    # Forceful SIGKILL if still alive
    pkill -9 -f "/python.*/opt/bazarr/bazarr/main.py"
    pkill -9 -f "/python.*/opt/bazarr/bazarr.py"
}

stop_transmission() {
    echo "Stopping Transmission..."
    sv down transmission 2>/dev/null
    # Try graceful SIGTERM first
    pkill -x "transmission-daemon"
    sleep 2
    # Forceful SIGKILL if still alive
    pkill -9 -x "transmission-daemon"
}

stop_jellyfin() {
    echo "Stopping Jellyfin..."
    sv down jellyfin 2>/dev/null
    # Try graceful SIGTERM first
    pkill -f "/bin/jellyfin"
    sleep 2
    # Forceful SIGKILL if still alive
    pkill -9 -f "/bin/jellyfin"
}

check_status() {
    local service=$1
    local pattern=$2
    local exact=$3
    if [ "$exact" == "true" ]; then
        if pgrep -x "$pattern" > /dev/null; then
            echo "[ON] $service"
        else
            echo "[OFF] $service"
        fi
    else
        # Use character class trick (e.g., [j]ellyfin) in pattern to avoid matching pgrep itself
        if pgrep -f "$pattern" > /dev/null; then
            echo "[ON] $service"
        else
            echo "[OFF] $service"
        fi
    fi
}

case "$1" in
    start-all)
        termux-wake-lock
        touch "$WORKDIR/.manual_override"
        start_jellyfin
        start_transmission
        start_arr_apps
        start_bazarr
        notify "Manual Mode: All services UP 🚀"
        ;;
    smart-start)
        # $2 will be the output of check-needs.sh
        termux-wake-lock
        start_jellyfin # Always keep Jellyfin up if battery allows
        
        # Parse needs
        if echo "$2" | grep -q "SONARR_MISSING\|SONARR_UPCOMING"; then
            start_sonarr
            start_prowlarr
            start_transmission
            start_bazarr
        fi
        
        if echo "$2" | grep -q "RADARR_MISSING\|RADARR_UPCOMING"; then
            start_radarr
            start_prowlarr
            start_transmission
            start_bazarr
        fi

        if echo "$2" | grep -q "TRANSMISSION_ACTIVE"; then
            start_transmission
        fi
        ;;
    stop-smart)
        # $2 will be the output of check-needs.sh
        if ! echo "$2" | grep -q "SONARR_MISSING\|SONARR_UPCOMING"; then
            stop_sonarr
        fi
        
        if ! echo "$2" | grep -q "RADARR_MISSING\|RADARR_UPCOMING"; then
            stop_radarr
        fi

        if ! echo "$2" | grep -q "TRANSMISSION_ACTIVE"; then
            # Only stop transmission if no media app needs it
            if ! echo "$2" | grep -q "SONARR_MISSING\|SONARR_UPCOMING\|RADARR_MISSING\|RADARR_UPCOMING"; then
                stop_transmission
            fi
        fi

        # Stop shared services if neither app needs them
        if ! echo "$2" | grep -q "SONARR_MISSING\|SONARR_UPCOMING\|RADARR_MISSING\|RADARR_UPCOMING"; then
            stop_prowlarr
            stop_bazarr
        fi
        ;;
    stop-all)
        rm -f "$WORKDIR/.manual_override"
        stop_bazarr
        stop_arr_apps
        stop_transmission
        stop_jellyfin
        termux-wake-unlock
        notify "All services STOPPED 💤"
        ;;
    stop-eco)
        rm -f "$WORKDIR/.manual_override"
        # Ensure Jellyfin is running
        start_jellyfin
        # Stop everything else
        stop_bazarr
        stop_arr_apps
        stop_transmission
        notify "Eco Mode: Only Jellyfin is running 🔋"
        ;;
    status)
        echo "--- Service Status ---"
        # Use character classes [x] to prevent pgrep from matching its own command line
        check_status "Jellyfin" "/bin/[j]ellyfin" "false"
        check_status "Transmission" "[t]ransmission-daemon" "true"
        check_status "Radarr" "[R]adarr.dll" "false"
        check_status "Sonarr" "[S]onarr.dll" "false"
        check_status "Prowlarr" "[P]rowlarr.dll" "false"
        check_status "Bazarr" "bazarr/[m]ain.py" "false"
        ;;
    re-shim)
        echo "🔧 Re-applying native library shims and patches..."
        bash ./setup_media_server.sh --optimize-only
        notify "Native shims re-applied! ✅"
        ;;
    *)
        echo "Usage: $0 {start-all|stop-all|stop-eco|status|re-shim}"
        exit 1
        ;;
esac
