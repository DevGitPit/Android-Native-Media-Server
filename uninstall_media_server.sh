#!/data/data/com.termux/files/usr/bin/bash

echo "🗑️ Starting Native Termux Media Server Uninstallation..."

# 1. Stop all running services
echo "🛑 Stopping services..."
pkill -f "Radarr.dll"
pkill -f "Sonarr.dll"
pkill -f "Prowlarr.dll"
pkill -f "jellyfin"

# 2. Remove Application Binaries
echo "📂 Removing application binaries from $PREFIX/opt/..."
rm -rf "$PREFIX/opt/Radarr"
rm -rf "$PREFIX/opt/Sonarr"
rm -rf "$PREFIX/opt/Prowlarr"

# 3. Remove Configuration and Databases
# Default .NET Arr app config locations: ~/.config/[AppName]
echo "🧹 Cleaning up configuration files and databases..."
rm -rf ~/.config/Radarr
rm -rf ~/.config/Sonarr
rm -rf ~/.config/Prowlarr
rm -rf ~/.config/jellyfin
rm -rf ~/.local/share/jellyfin
rm -rf ~/.cache/jellyfin

# 4. Clean up Environment Variables
echo "📝 Removing DOTNET_ROOT from .bashrc..."
sed -i '/export DOTNET_ROOT=\$PREFIX\/lib\/dotnet/d' ~/.bashrc

# 5. Cleanup test logs
rm -f ~/*_test.log

echo "✅ Uninstallation complete!"
echo "Note: System packages (dotnet, jellyfin-server, mono, etc.) were kept. To remove them, run:"
echo "pkg uninstall dotnet-runtime-9.0 jellyfin-server mono libesqlite3 sqlite -y"
