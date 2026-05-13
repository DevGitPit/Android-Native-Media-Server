#!/data/data/com.termux/files/usr/bin/bash

WORKDIR="/data/data/com.termux/files/home/arrFin"
cd "$WORKDIR" || exit

echo "🛑 Stopping Media Server Stack..."

# 1. Stop the battery monitor first to prevent it from restarting things
bash ./battery-monitor.sh --stop

# 2. Stop all services
bash ./service-control.sh stop-all

echo "All services STOPPED! 💤"
