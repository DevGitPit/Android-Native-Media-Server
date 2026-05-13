#!/data/data/com.termux/files/usr/bin/bash

# Configuration
WORKDIR="/data/data/com.termux/files/home/arrFin"
BAZARR_PATH="/data/data/com.termux/files/usr/opt/bazarr/bazarr.py"
LOG_DIR="$WORKDIR/logs"
mkdir -p "$LOG_DIR"

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
    pkill -f "dotnet.*/opt/(Radarr|Sonarr|Prowlarr)" 
    pkill -f "Radarr.dll"
    pkill -f "Sonarr.dll"
    pkill -f "Prowlarr.dll"
    pkill -f "dotnet"
}

stop_bazarr() {
    echo "Stopping Bazarr..."
    pkill -f "bazarr.py"
    pkill -f "bazarr/main.py"
}

stop_transmission() {
    echo "Stopping Transmission..."
    sv down transmission 2>/dev/null
    pkill -x "transmission-daemon"
}

stop_jellyfin() {
    echo "Stopping Jellyfin..."
    sv down jellyfin 2>/dev/null
    pkill -f "bin/jellyfin"
}

check_status() {
    local service=$1
    local pattern=$2
    if pgrep -f "$pattern" > /dev/null; then
        echo "[ON] $service"
    else
        echo "[OFF] $service"
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
        stop_bazarr
        stop_arr_apps
        stop_transmission
        # Jellyfin stays up
        notify "Eco Mode: Only Jellyfin is running 🔋"
        ;;
    status)
        echo "--- Service Status ---"
        # Be careful with patterns to avoid matching runsv or svlogd
        check_status "Jellyfin" "bin/jellyfin"
        check_status "Transmission" "transmission-daemon"
        check_status "Radarr" "Radarr.dll"
        check_status "Sonarr" "Sonarr.dll"
        check_status "Prowlarr" "Prowlarr.dll"
        check_status "Bazarr" "bazarr/main.py"
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
