#!/data/data/com.termux/files/usr/bin/bash

# 1. Prevent Android from killing Termux
termux-wake-lock

# 2. Export Global .NET Environment
export DOTNET_ROOT=$PREFIX/lib/dotnet
export LD_LIBRARY_PATH=$PREFIX/lib

# Work directory
WORKDIR="/data/data/com.termux/files/home/arrFin"
cd "$WORKDIR" || exit

# 3. Start Transmission (Torrent Engine)
transmission-daemon -w ~/media/downloads -T 2>/dev/null

# 4. Start Jellyfin (Streaming Server)
jellyfin > "$WORKDIR/jellyfin_run.log" 2>&1 &

# 5. Start Automation Stack with Watchdogs
# Prowlarr Watchdog
while true; do
    echo "$(date): Starting Prowlarr..." >> "$WORKDIR/prowlarr.log"
    dotnet $PREFIX/opt/Prowlarr/Prowlarr.dll -nobrowser >> "$WORKDIR/prowlarr.log" 2>&1
    echo "$(date): Prowlarr process exited, restarting in 10s..." >> "$WORKDIR/prowlarr.log"
    sleep 10
done &

# Radarr Watchdog
while true; do
    echo "$(date): Starting Radarr..." >> "$WORKDIR/radarr.log"
    dotnet $PREFIX/opt/Radarr/Radarr.dll -nobrowser >> "$WORKDIR/radarr.log" 2>&1
    echo "$(date): Radarr process exited, restarting in 10s..." >> "$WORKDIR/radarr.log"
    sleep 10
done &

# Sonarr Watchdog
while true; do
    echo "$(date): Starting Sonarr..." >> "$WORKDIR/sonarr.log"
    dotnet $PREFIX/opt/Sonarr/Sonarr.dll -nobrowser >> "$WORKDIR/sonarr.log" 2>&1
    echo "$(date): Sonarr process exited, restarting in 10s..." >> "$WORKDIR/sonarr.log"
    sleep 10
done &

echo "Media Server is UP and RUNNING! 🚀"
