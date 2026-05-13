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
    if ! pgrep -f "jellyfin" > /dev/null; then
        echo "$(date): Starting Jellyfin..." >> "$LOG_DIR/jellyfin.log"
        jellyfin > "$LOG_DIR/jellyfin_run.log" 2>&1 &
    fi
}

start_transmission() {
    if ! pgrep -f "transmission-daemon" > /dev/null; then
        echo "$(date): Starting Transmission..." >> "$LOG_DIR/transmission.log"
        transmission-daemon -w ~/media/downloads -T 2>/dev/null
    fi
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
    if ! pgrep -f "bazarr.py" > /dev/null; then
        echo "$(date): Starting Bazarr..." >> "$LOG_DIR/bazarr.log"
        python "$BAZARR_PATH" >> "$LOG_DIR/bazarr.log" 2>&1 &
    fi
}

stop_arr_apps() {
    echo "Stopping Radarr, Sonarr, Prowlarr watchdogs and processes..."
    # Kill the subshell loops first
    pkill -f "dotnet.*/opt/(Radarr|Sonarr|Prowlarr)" 
    # Kill the actual dlls
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
    pkill -f "transmission-daemon"
}

stop_jellyfin() {
    echo "Stopping Jellyfin..."
    pkill -f "jellyfin"
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
        pgrep -f "jellyfin" > /dev/null && echo "[ON] Jellyfin" || echo "[OFF] Jellyfin"
        pgrep -f "transmission-daemon" > /dev/null && echo "[ON] Transmission" || echo "[OFF] Transmission"
        pgrep -f "Radarr.dll" > /dev/null && echo "[ON] Radarr" || echo "[OFF] Radarr"
        pgrep -f "Sonarr.dll" > /dev/null && echo "[ON] Sonarr" || echo "[OFF] Sonarr"
        pgrep -f "Prowlarr.dll" > /dev/null && echo "[ON] Prowlarr" || echo "[OFF] Prowlarr"
        pgrep -f "bazarr.py" > /dev/null && echo "[ON] Bazarr" || echo "[OFF] Bazarr"
        ;;
    *)
        echo "Usage: $0 {start-all|stop-all|stop-eco|status}"
        exit 1
        ;;
esac
