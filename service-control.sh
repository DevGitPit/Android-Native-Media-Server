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
    termux-notification -t "Media Server" -c "$1" --id "arrfin_status" --priority "high"
}

start_jellyfin() {
    echo "$(date): Starting Jellyfin..." >> "$LOG_DIR/jellyfin.log"
    if is_native_app jellyfin; then
        sv up jellyfin
    else
        jellyfin > "$LOG_DIR/jellyfin_run.log" 2>&1 &
    fi
}

start_transmission() {
    echo "$(date): Starting Transmission (via sv)..." >> "$LOG_DIR/transmission.log"
    sv up transmission 2>/dev/null || transmission-daemon -w ~/media/downloads -T 2>/dev/null
}

# Helper to detect installation style
is_native_app() {
    # Native pkg install registers a runit service
    [ -d "$PREFIX/var/service/$1" ]
}

start_radarr_legacy() {
    if ! pgrep -f "[R]adarr.dll" > /dev/null; then
        echo "$(date): Starting Radarr (Legacy)..." >> "$LOG_DIR/radarr.log"
        (
            echo "$BASHPID" > "$PID_DIR/radarr_watchdog.pid"
            while true; do
                export DOTNET_ROOT=$PREFIX/lib/dotnet
                export LD_LIBRARY_PATH=$PREFIX/lib
                "$PREFIX/bin/dotnet" "$PREFIX/opt/Radarr/Radarr.dll" -nobrowser >> "$LOG_DIR/radarr.log" 2>&1
                echo "$(date): Radarr exited, restarting in 10s..." >> "$LOG_DIR/radarr.log"
                sleep 10
            done
        ) & disown
    fi
}

start_sonarr_legacy() {
    if ! pgrep -f "[S]onarr.dll" > /dev/null; then
        echo "$(date): Starting Sonarr (Legacy)..." >> "$LOG_DIR/sonarr.log"
        (
            echo "$BASHPID" > "$PID_DIR/sonarr_watchdog.pid"
            while true; do
                export DOTNET_ROOT=$PREFIX/lib/dotnet
                export LD_LIBRARY_PATH=$PREFIX/lib
                "$PREFIX/bin/dotnet" "$PREFIX/opt/Sonarr/Sonarr.dll" -nobrowser >> "$LOG_DIR/sonarr.log" 2>&1
                echo "$(date): Sonarr exited, restarting in 10s..." >> "$LOG_DIR/sonarr.log"
                sleep 10
            done
        ) & disown
    fi
}

start_prowlarr_legacy() {
    if ! pgrep -f "[P]rowlarr.dll" > /dev/null; then
        echo "$(date): Starting Prowlarr (Legacy)..." >> "$LOG_DIR/prowlarr.log"
        (
            echo "$BASHPID" > "$PID_DIR/prowlarr_watchdog.pid"
            while true; do
                export DOTNET_ROOT=$PREFIX/lib/dotnet
                export LD_LIBRARY_PATH=$PREFIX/lib
                "$PREFIX/bin/dotnet" "$PREFIX/opt/Prowlarr/Prowlarr.dll" -nobrowser >> "$LOG_DIR/prowlarr.log" 2>&1
                echo "$(date): Prowlarr exited, restarting in 10s..." >> "$LOG_DIR/prowlarr.log"
                sleep 10
            done
        ) & disown
    fi
}

start_radarr() {
    if is_native_app radarr; then
        echo "$(date): Starting Radarr (Native)..." >> "$LOG_DIR/radarr.log"
        sv up radarr
    else
        start_radarr_legacy
    fi
}

start_sonarr() {
    if is_native_app sonarr; then
        echo "$(date): Starting Sonarr (Native)..." >> "$LOG_DIR/sonarr.log"
        sv up sonarr
    else
        start_sonarr_legacy
    fi
}

start_prowlarr() {
    if is_native_app prowlarr; then
        echo "$(date): Starting Prowlarr (Native)..." >> "$LOG_DIR/prowlarr.log"
        sv up prowlarr
    else
        start_prowlarr_legacy
    fi
}

start_arr_apps() {
    echo "$(date): [START] start_arr_apps called (Parent: $PPID)" >> "$LOG_DIR/monitor.log"
    start_radarr
    start_sonarr
    start_prowlarr
}

start_bazarr() {
    if ! pgrep -f "bazarr/[m]ain.py" > /dev/null && ! pgrep -f "[b]azarr.py" > /dev/null; then
        echo "$(date): Starting Bazarr..." >> "$LOG_DIR/bazarr.log"
        python "$BAZARR_PATH" >> "$LOG_DIR/bazarr.log" 2>&1 &
    fi
}

stop_radarr() {
    if is_native_app radarr; then
        echo "Stopping Radarr (Native)..."
        sv down radarr
    else
        echo "Stopping Radarr (Legacy)..."
        if [ -f "$PID_DIR/radarr_watchdog.pid" ]; then
            kill $(cat "$PID_DIR/radarr_watchdog.pid") 2>/dev/null
            rm "$PID_DIR/radarr_watchdog.pid"
        fi
        pkill -f "[R]adarr.dll"
    fi
}

stop_sonarr() {
    if is_native_app sonarr; then
        echo "Stopping Sonarr (Native)..."
        sv down sonarr
    else
        echo "Stopping Sonarr (Legacy)..."
        if [ -f "$PID_DIR/sonarr_watchdog.pid" ]; then
            kill $(cat "$PID_DIR/sonarr_watchdog.pid") 2>/dev/null
            rm "$PID_DIR/sonarr_watchdog.pid"
        fi
        pkill -f "[S]onarr.dll"
    fi
}

stop_prowlarr() {
    if is_native_app prowlarr; then
        echo "Stopping Prowlarr (Native)..."
        sv down prowlarr
    else
        echo "Stopping Prowlarr (Legacy)..."
        if [ -f "$PID_DIR/prowlarr_watchdog.pid" ]; then
            kill $(cat "$PID_DIR/prowlarr_watchdog.pid") 2>/dev/null
            rm "$PID_DIR/prowlarr_watchdog.pid"
        fi
        pkill -f "[P]rowlarr.dll"
    fi
}

stop_arr_apps() {
    echo "$(date): [STOP] stop_arr_apps called (Parent: $PPID)" >> "$LOG_DIR/monitor.log"
    stop_radarr
    stop_sonarr
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

is_transmission_active() {
    # If Transmission is not running, it's not active
    if ! pgrep -x "transmission-daemon" > /dev/null; then
        return 1
    fi
    # Check if any torrent is not 100% AND not Idle
    # (Covers Downloading, Up & Down, Verifying, Uploading if < 100%)
    transmission-remote -l 2>/dev/null | sed '1d;$d' | grep -v "100%" | grep -v "Idle" > /dev/null
}

stop_jellyfin() {
    echo "Stopping Jellyfin..."
    if is_native_app jellyfin; then
        sv down jellyfin
    else
        # Try graceful SIGTERM first
        pkill -x "jellyfin"
        # Wait up to 15 seconds for process to exit
        for i in {1..15}; do
            pgrep -x "jellyfin" > /dev/null || break
            sleep 1
        done
        # Forceful SIGKILL if still alive
        pkill -9 -x "jellyfin"
    fi
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

# Helper to manage manual override
set_manual() {
    if [[ "$2" != "--auto" ]]; then
        touch "$WORKDIR/.manual_mode"
        echo "🕹️ Manual Mode engaged. Battery automation paused."
    fi
}

case "$1" in
    start-all)
        set_manual "$1" "$2"
        termux-wake-lock
        start_jellyfin
        start_transmission
        start_arr_apps
        start_bazarr
        notify "All services are UP 🚀"
        ;;
    stop-all)
        set_manual "$1" "$2"
        stop_bazarr
        stop_arr_apps
        stop_transmission
        stop_jellyfin
        termux-wake-unlock
        notify "All services STOPPED 💤"
        ;;
    stop-eco)
        set_manual "$1" "$2"
        # Ensure Jellyfin is running
        start_jellyfin
        # Stop everything else
        stop_bazarr
        stop_arr_apps
        
        if is_transmission_active; then
            echo "Transmission is actively downloading. Keeping it alive..."
            notify "Eco Mode: Keeping Transmission alive for active downloads 📥"
        else
            stop_transmission
            notify "Eco Mode: Only Jellyfin is running 🔋"
        fi
        ;;
    auto)
        rm -f "$WORKDIR/.manual_mode"
        echo "🤖 Auto-pilot engaged. Enforcing battery rules..."
        
        # Immediate enforcement
        BATTERY_INFO=$(termux-battery-status 2>/dev/null)
        LEVEL=$(echo "$BATTERY_INFO" | jq -r '.percentage // 0')
        STATUS=$(echo "$BATTERY_INFO" | jq -r '.status // "DISCHARGING"')
        if [[ ! "$LEVEL" =~ ^[0-9]+$ ]]; then LEVEL=0; fi
        THRESHOLD=50 # Should match battery-monitor.sh
        
        if [[ "$LEVEL" -gt "$THRESHOLD" || "$STATUS" == "CHARGING" || "$STATUS" == "FULL" ]]; then
            # Call functions directly instead of re-invoking the script
            termux-wake-lock
            start_jellyfin
            start_transmission
            start_arr_apps
            start_bazarr
            notify "Auto Mode: All services UP 🚀"
        else
            # Call functions directly
            start_jellyfin
            stop_bazarr
            stop_arr_apps
            if is_transmission_active; then
                notify "Auto Mode: Battery low, keeping active Transmission 📥"
            else
                stop_transmission
                notify "Auto Mode: Battery low, Eco Mode active 🔋"
            fi
        fi
        ;;
    status)
        echo "--- Service Status ---"
        if [[ -f "$WORKDIR/.manual_mode" ]]; then
            echo "MODE: [MANUAL] 🕹️"
        else
            echo "MODE: [AUTO] 🤖"
        fi
        # Use character classes [x] to prevent pgrep from matching its own command line
        check_status "Jellyfin" "[j]ellyfin" "false"
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
    start-sonarr|start-radarr|start-prowlarr|start-bazarr|start-transmission|start-jellyfin)
        set_manual "$1" "$2"
        app_name="${1#*-}"
        "start_$app_name"
        ;;
    stop-sonarr|stop-radarr|stop-prowlarr|stop-bazarr|stop-transmission|stop-jellyfin)
        set_manual "$1" "$2"
        app_name="${1#*-}"
        "stop_$app_name"
        ;;
    *)
        echo "Usage: $0 {start-all|stop-all|stop-eco|auto|status|re-shim|start-<app>|stop-<app>}"
        exit 1
        ;;
esac
