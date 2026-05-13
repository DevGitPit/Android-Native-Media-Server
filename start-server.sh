#!/data/data/com.termux/files/usr/bin/bash

WORKDIR="$HOME/arrFin"
cd "$WORKDIR" || exit

echo "🚀 Starting Media Server Stack with Battery Automation..."

# Start the battery monitor. 
# It is now configured to enforce the correct mode (Full or Eco) on startup.
bash ./battery-monitor.sh --start

echo "Battery monitor is active and managing services! 🚀"
