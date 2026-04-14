#!/data/data/com.termux/files/usr/bin/bash

# --- Configuration ---
INSTALL_DIR="$PREFIX/opt"
APPS=("Radarr" "Sonarr" "Prowlarr")
DOTNET_VERSION="9.0"

# --- URLs ---
RADARR_URL="https://radarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=arm64"
SONARR_URL="https://services.sonarr.tv/v1/download/main/latest?version=4&os=linux&arch=arm64"
PROWLARR_URL="https://prowlarr.servarr.com/v1/update/master/updatefile?os=linux&runtime=netcore&arch=arm64"

echo "🚀 Starting Native Termux Media Server Setup..."

# 1. Update and Dependencies
echo "📦 Installing system dependencies..."
pkg update -y
pkg install tur-repo -y
pkg install wget curl sqlite libicu mono libesqlite3 ffmpeg dotnet-runtime-9.0 jellyfin-server -y

# 2. Setup Directories
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR" || exit

# 3. Download and Extract Apps
setup_app() {
    local name=$1
    local url=$2
    
    echo "📥 Setting up $name..."
    if [ ! -d "$INSTALL_DIR/$name" ]; then
        wget -O "${name,,}.tar.gz" "$url"
        tar -xvzf "${name,,}.tar.gz" -C "$INSTALL_DIR/"
        rm "${name,,}.tar.gz"
    else
        echo "✅ $name already extracted."
    fi

    echo "⚙️ Optimizing $name for Native Termux..."
    
    # Remove bundled glibc libraries
    rm -f "$INSTALL_DIR/$name"/*.so
    
    # Link native Android libraries
    ln -sf "$PREFIX/lib/libMonoPosixHelper.so" "$INSTALL_DIR/$name/"
    ln -sf "$PREFIX/lib/libe_sqlite3.so" "$INSTALL_DIR/$name/"
    
    # Replace/Link ffprobe/ffmpeg with system ones (Fixes SIGSYS/Exit 159 on Android)
    rm -f "$INSTALL_DIR/$name/ffprobe" "$INSTALL_DIR/$name/ffmpeg"
    ln -sf "$PREFIX/bin/ffprobe" "$INSTALL_DIR/$name/ffprobe"
    ln -sf "$PREFIX/bin/ffmpeg" "$INSTALL_DIR/$name/ffmpeg"
    
    # Patch dependency manifest for .NET 9.0 compatibility (Fixes CoreCLR resolution)
    if [ -f "$INSTALL_DIR/$name/$name.deps.json" ]; then
        # Replace framework version from 6.0 to 9.0
        sed -i 's/"6\.0\.0"/"9.0.0"/g' "$INSTALL_DIR/$name/$name.deps.json"
        
        # Remove native runtime blocks that trick muxer into self-contained mode
        sed -i '/"libcoreclr.so": {/,/}/d' "$INSTALL_DIR/$name/$name.deps.json"
        sed -i '/"libclrjit.so": {/,/}/d' "$INSTALL_DIR/$name/$name.deps.json"
        sed -i '/"libhostpolicy.so": {/,/}/d' "$INSTALL_DIR/$name/$name.deps.json"
        sed -i '/"libhostfxr.so": {/,/}/d' "$INSTALL_DIR/$name/$name.deps.json"
    fi
    
    # Update Runtime Config to use System .NET 9.0
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

setup_app "Radarr" "$RADARR_URL"
setup_app "Sonarr" "$SONARR_URL"
setup_app "Prowlarr" "$PROWLARR_URL"

# 4. Final Environment Setup
echo "📝 Configuring environment..."
if ! grep -q "DOTNET_ROOT" ~/.bashrc; then
    echo "export DOTNET_ROOT=\$PREFIX/lib/dotnet" >> ~/.bashrc
    echo "export LD_LIBRARY_PATH=\$PREFIX/lib" >> ~/.bashrc
fi
export DOTNET_ROOT=$PREFIX/lib/dotnet
export LD_LIBRARY_PATH=$PREFIX/lib

# --- Verification & Testing ---
echo "🧪 Starting Verification Tests..."

test_service() {
    local name=$1
    local dll="$INSTALL_DIR/$name/$name.dll"
    
    echo "Testing $name..."
    # Run in background, capture output
    export DOTNET_ROOT=$PREFIX/lib/dotnet
    export LD_LIBRARY_PATH=$PREFIX/lib
    timeout 15s dotnet "$dll" -nobrowser > "${name,,}_test.log" 2>&1 &
    local pid=$!
    
    # Wait a bit for startup
    sleep 10
    
    if grep -q "Application started" "${name,,}_test.log" || grep -q "Now listening on" "${name,,}_test.log"; then
        echo "✅ $name started successfully!"
        kill $pid 2>/dev/null
        return 0
    else
        echo "❌ $name failed to start properly. Check ${name,,}_test.log"
        cat "${name,,}_test.log"
        kill $pid 2>/dev/null
        return 1
    fi
}

echo "Testing Jellyfin..."
if jellyfin --help > /dev/null 2>&1; then
    echo "✅ Jellyfin binary found and functional."
else
    echo "❌ Jellyfin check failed."
fi

test_service "Radarr"
test_service "Sonarr"
test_service "Prowlarr"

echo "🎉 Setup and Verification Complete!"
echo "Check your README.md for start commands."
