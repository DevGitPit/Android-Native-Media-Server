#!/data/data/com.termux/files/usr/bin/bash

# 1. Prevent Android from killing Termux
termux-wake-lock

# 2. Export .NET Environment (Critical for Native Termux)
export DOTNET_ROOT=$PREFIX/lib/dotnet

# 3. Start Transmission (Torrent Engine)
# -w sets the download directory, -T enables the built-in RPC (Remote Procedure Call)
transmission-daemon -w ~/media/downloads -T &

# 4. Start Jellyfin (Streaming Server)
jellyfin &

# 5. Start Prowlarr, Sonarr, and Radarr (Automation Stack)
# We use nohup and redirect logs to keep them running silently
nohup dotnet $PREFIX/opt/Prowlarr/Prowlarr.dll -nobrowser > prowlarr.log 2>&1 &
nohup dotnet $PREFIX/opt/Sonarr/Sonarr.dll -nobrowser > sonarr.log 2>&1 &
nohup dotnet $PREFIX/opt/Radarr/Radarr.dll -nobrowser > radarr.log 2>&1 &

echo "Media Server is UP and RUNNING! 🚀"
echo "Jellyfin: http://localhost:8096"
echo "Radarr:   http://localhost:7878"
echo "Sonarr:   http://localhost:8989"
echo "Prowlarr: http://localhost:9696"
echo "Transmission: http://localhost:9091 (Default Port)"
