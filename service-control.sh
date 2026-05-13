#!/data/data/com.termux/files/usr/bin/bash

# Configuration
WORKDIR="/data/data/com.termux/files/home/arrFin"
BAZARR_PATH="/data/data/com.termux/files/usr/opt/bazarr/bazarr.py"
LOG_DIR="$WORKDIR/logs"
PID_DIR="$WORKDIR/pids"
mkdir -p "$LOG_DIR" "$PID_DIR"

# .NET Environment
export DOTNET_ROOT=$PREFIX/lib/dotnet
export LD_LIBRARY_PATH=$PREFIX/lib

notify() {
    termux-notification -t "Media Server" -c "$1" --id "arrfin_status" --priority "high"
}

start_jellyfin() {
    echo "$(date): Starting Jellyfin (via sv)..." >> "$LOG_DIR/jellyfin.log"
    sv up jellyfin 2>/dev/null || jellyfin > "$LOG_DIR/jellyfin_run.log" 2>&1 &
}

start_transmission() {
    echo "$(date): Starting Transmission (via sv)..." >> "$LOG_DIR/transmission.log"
    sv up transmission 2>/dev/null || transmission-daemon -w ~/media/downloads -T 2>/dev/null
}

start_arr_apps() {
    for app in Radarr Sonarr Prowlarr; do
        if ! pgrep -f "$app.dll" > /dev/null; then
            echo "$(date): Starting $app..." >> "$LOG_DIR/${app,,}.log"
            # Watchdog loop
            (
                # Store the actual subshell PID
                echo "$BASHPID" > "$PID_DIR/${app,,}_watchdog.pid"
                while true; do
                    dotnet "$PREFIX/opt/$app/$app.dll" -nobrowser >> "$LOG_DIR/${app,,}.log" 2>&1
                    echo "$(date): $app exited, restarting in 10s..." >> "$LOG_DIR/${app,,}.log"
                    sleep 10
                done
            ) &
        fi
    done
}

start_bazarr() {
    if ! pgrep -f "bazarr.*main.py" > /dev/null; then
        echo "$(date): Starting Bazarr..." >> "$LOG_DIR/bazarr.log"
        python "$BAZARR_PATH" >> "$LOG_DIR/bazarr.log" 2>&1 &
    fi
}

stop_arr_apps() {
    echo "Stopping Radarr, Sonarr, Prowlarr watchdogs and processes..."
    for app in radarr sonarr prowlarr; do
        if [ -f "$PID_DIR/${app}_watchdog.pid" ]; then
            PID=$(cat "$PID_DIR/${app}_watchdog.pid")
            echo "Killing watchdog PID $PID for $app"
            kill "$PID" 2>/dev/null
            rm "$PID_DIR/${app}_watchdog.pid"
        fi
    done
    
    # Now kill the actual processes using absolute paths (Graceful SIGTERM)
    pkill -f "/dotnet.*/opt/Radarr"
    pkill -f "/dotnet.*/opt/Sonarr"
    pkill -f "/dotnet.*/opt/Prowlarr"
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
        # When using -f, we must avoid matching the check_status/pgrep command itself
        # We do this by checking for more than 1 match if the pattern is broad, 
        # or just being specific.
        if pgrep -f "$pattern" | grep -v "$$" > /dev/null; then
            echo "[ON] $service"
        else
            echo "[OFF] $service"
        fi
    fi
}

case "$1" in
    start-all)
        termux-wake-lock
        start_jellyfin
        start_transmission
        start_arr_apps
        start_bazarr
        notify "All services are UP 🚀"
        ;;
    stop-all)
        stop_bazarr
        stop_arr_apps
        stop_transmission
        stop_jellyfin
        termux-wake-unlock
        notify "All services STOPPED 💤"
        ;;
    stop-eco)
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
        # Use specific paths or exact matches where possible
        check_status "Jellyfin" "/bin/jellyfin" "false"
        check_status "Transmission" "transmission-daemon" "true"
        check_status "Radarr" "Radarr.dll" "false"
        check_status "Sonarr" "Sonarr.dll" "false"
        check_status "Prowlarr" "Prowlarr.dll" "false"
        check_status "Bazarr" "bazarr/main.py" "false"
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
