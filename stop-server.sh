#!/data/data/com.termux/files/usr/bin/bash

echo "🛑 Stopping Media Server Stack..."

# 1. Stop the start script / watchdog first
echo "Stopping Watchdog..."
pkill -f "start-server.sh"

# 2. Stop Radarr, Sonarr, and Prowlarr (.NET Apps)
echo "Stopping Radarr, Sonarr, and Prowlarr..."
pkill -f "Radarr.dll"
pkill -f "Sonarr.dll"
pkill -f "Prowlarr.dll"
pkill -f "dotnet"

# 3. Stop Jellyfin (Runit)
echo "Stopping Jellyfin..."
sv down jellyfin 2>/dev/null
pkill -f "jellyfin"

# 4. Stop Transmission (Runit)
echo "Stopping Transmission..."
sv down transmission 2>/dev/null
pkill -f "transmission-daemon"

# 5. Release Wake Lock
termux-wake-unlock

echo "All services STOPPED! 💤"
