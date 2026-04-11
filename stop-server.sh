#!/data/data/com.termux/files/usr/bin/bash

echo "🛑 Stopping Media Server Stack..."

# 1. Stop the .NET Arr Stack
echo "Stopping Radarr, Sonarr, and Prowlarr..."
pkill -f "Radarr.dll"
pkill -f "Sonarr.dll"
pkill -f "Prowlarr.dll"

# 2. Stop Jellyfin
echo "Stopping Jellyfin..."
pkill -f "jellyfin"

# 3. Stop Transmission
echo "Stopping Transmission..."
transmission-remote -n 'transmission:transmission' --exit > /dev/null 2>&1 || pkill -f "transmission-daemon"

# 4. Release Wake Lock
echo "Releasing Termux Wake Lock..."
termux-wake-unlock

echo "✅ All services stopped. Memory freed! 🚀"
