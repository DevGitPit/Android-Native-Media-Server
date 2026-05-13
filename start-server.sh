#!/data/data/com.termux/files/usr/bin/bash

WORKDIR="/data/data/com.termux/files/home/arrFin"
cd "$WORKDIR" || exit

echo "🚀 Starting Media Server Stack with Battery Automation..."

# 1. Start all services
bash ./service-control.sh start-all

# 2. Start the battery monitor
bash ./battery-monitor.sh --start

echo "Media Server is UP and monitoring battery! 🚀"
