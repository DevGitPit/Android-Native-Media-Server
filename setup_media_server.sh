#!/data/data/com.termux/files/usr/bin/bash

# --- Configuration ---
WORKDIR=$(pwd)
INSTALL_DIR="$PREFIX/opt"
APPS=("Radarr" "Sonarr" "Prowlarr")
DOTNET_VERSION="9.0"

# --- URLs ---
RADARR_URL="https://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=arm64"
SONARR_URL="https://services.sonarr.tv/v1/download/main/latest?version=4&os=linux&arch=arm64"
PROWLARR_URL="https://prowlarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=arm64"

# --- Optimization Function (The "Shim") ---
optimize_app() {
    local name=$1
    echo "⚙️ Optimizing $name for Native Termux..."
    
    # Remove bundled glibc libraries
    rm -f "$INSTALL_DIR/$name"/*.so
    
    # Link native Android libraries
    ln -sf "$PREFIX/lib/libMonoPosixHelper.so" "$INSTALL_DIR/$name/"
    ln -sf "$PREFIX/lib/libe_sqlite3.so" "$INSTALL_DIR/$name/"
    
    # Replace/Link ffprobe/ffmpeg with system ones
    rm -f "$INSTALL_DIR/$name/ffprobe" "$INSTALL_DIR/$name/ffmpeg"
    ln -sf "$PREFIX/bin/ffprobe" "$INSTALL_DIR/$name/ffprobe"
    ln -sf "$PREFIX/bin/ffmpeg" "$INSTALL_DIR/$name/ffmpeg"
    
    # Patch dependency manifest
    if [ -f "$INSTALL_DIR/$name/$name.deps.json" ]; then
        sed -i 's/"6\.0\.0"/"9.0.0"/g' "$INSTALL_DIR/$name/$name.deps.json"
        sed -i '/"libcoreclr.so": {/,/}/d' "$INSTALL_DIR/$name/$name.deps.json"
        sed -i '/"libclrjit.so": {/,/}/d' "$INSTALL_DIR/$name/$name.deps.json"
        sed -i '/"libhostpolicy.so": {/,/}/d' "$INSTALL_DIR/$name/$name.deps.json"
        sed -i '/"libhostfxr.so": {/,/}/d' "$INSTALL_DIR/$name/$name.deps.json"
    fi
    
    # Update Runtime Config
    cat > "$INSTALL_DIR/$name/$name.runtimeconfig.json" <<EOF
{
  "runtimeOptions": {
    "tfm": "net$DOTNET_VERSION",
    "frameworks": [
      { "name": "Microsoft.NETCore.App", "version": "$DOTNET_VERSION.0" },
      { "name": "Microsoft.AspNetCore.App", "version": "$DOTNET_VERSION.0" }
    ],
    "configProperties": {
      "System.Reflection.Metadata.MetadataUpdater.IsSupported": false,
      "System.Runtime.Serialization.EnableUnsafeBinaryFormatterSerialization": false
    }
  }
}
EOF
}

# --- Main Logic ---
if [[ "$1" == "--optimize-only" ]]; then
    for app in "${APPS[@]}"; do
        if [ -d "$INSTALL_DIR/$app" ]; then
            optimize_app "$app"
        fi
    done
    exit 0
fi

echo "🚀 Starting Native Termux Media Server Setup..."

# 1. Update and Dependencies
echo "📦 Installing system dependencies..."
pkg update -y
pkg install tur-repo -y
pkg install wget curl sqlite libicu mono libesqlite3 ffmpeg jq termux-api dotnet-runtime-9.0 jellyfin-server -y

# 2. Setup Directories
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit

# 3. Download and Extract Apps
setup_app() {
    local name=$1
    local url=$2
    
    # Check if native package is already installed
    if dpkg -s "${name,,}" 2>/dev/null | grep -q "Status: install ok installed"; then
        echo "✨ $name is already installed via pkg (Native). Skipping manual setup."
        return 0
    fi


    echo "📥 Setting up $name (Legacy Manual)..."
    if [ ! -d "$INSTALL_DIR/$name" ]; then
        wget -O "${name,,}.tar.gz" "$url"
        tar -xvzf "${name,,}.tar.gz" -C "$INSTALL_DIR/"
        rm "${name,,}.tar.gz"
    else
        echo "✅ $name already exists."
    fi

    optimize_app "$name"
}

setup_app "Radarr" "$RADARR_URL"
setup_app "Sonarr" "$SONARR_URL"
setup_app "Prowlarr" "$PROWLARR_URL"

# 4. Apply Custom Tweaks (e.g., Bazarr)
echo "🔧 Applying custom tweaks..."
BAZARR_INSTALLED_DIR="$PREFIX/opt/bazarr"
if [ -d "$WORKDIR/custom/bazarr" ] && [ -d "$BAZARR_INSTALLED_DIR" ]; then
    echo "📦 Applying custom Bazarr tweaks..."
    cp "$WORKDIR/custom/bazarr/"* "$BAZARR_INSTALLED_DIR/"
fi

# 5. Final Environment Setup
echo "📝 Configuring environment..."
if ! grep -q "DOTNET_ROOT" ~/.bashrc; then
    echo "export DOTNET_ROOT=\$PREFIX/lib/dotnet" >> ~/.bashrc
    echo "export LD_LIBRARY_PATH=\$PREFIX/lib" >> ~/.bashrc
fi
export DOTNET_ROOT=$PREFIX/lib/dotnet
export LD_LIBRARY_PATH=$PREFIX/lib

echo "🎉 Setup Complete!"
