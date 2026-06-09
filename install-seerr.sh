#!/data/data/com.termux/files/usr/bin/bash

# Seerr Termux Native Installer/Updater
# This script handles dependencies, SWC WASM patching, and building.

set -e

REPO_DIR="$PREFIX/opt/seerr"
CONFIG_DIR="$HOME/.config/seerr"

echo "[*] Starting Seerr Termux Setup..."

# 1. Install System Dependencies
echo "[*] Checking system dependencies..."
pkg update
pkg install -y nodejs git libvips termux-services
if ! command -v pnpm &> /dev/null; then
    echo "[*] Installing pnpm..."
    npm install -g pnpm
fi

# 2. Setup Directory
if [ ! -d "$REPO_DIR" ]; then
    echo "[*] Creating repository directory..."
    mkdir -p "$(dirname "$REPO_DIR")"
    git clone https://github.com/seerr-team/seerr.git "$REPO_DIR"
    cd "$REPO_DIR"
else
    echo "[*] Updating existing repository..."
    cd "$REPO_DIR"
    
    echo "[*] Resetting local changes to avoid conflicts..."
    git reset --hard
    git clean -fd
    
    echo "[*] Syncing with remote..."
    git fetch origin main
    git reset --hard origin/main
fi

# 3. Loosen Node engine requirement to prevent build blocks
sed -i '/"engines": {/,/}/ s/"node": ".*"/"node": ">=20.0.0"/' package.json

# 4. Install JS Dependencies
echo "[*] Installing node modules (this may take a while)..."
# Using --no-engine-strict to bypass any rigid version checks
CYPRESS_INSTALL_BINARY=0 pnpm install --frozen-lockfile=false --no-engine-strict
pnpm add @next/swc-wasm-nodejs@14.2.33

# 5. Apply Termux Patches (SWC WASM Fallback)
echo "[*] Applying Termux-specific patches..."
INDEX_JS="node_modules/next/dist/build/swc/index.js"
if [ -f "$INDEX_JS" ]; then
    sed -i 's/const isWebContainer = .*;/const isWebContainer = true;/g' "$INDEX_JS"
    echo "  [+] Patched Next.js SWC loader for WASM fallback."
fi

# 6. Build Project
echo "[*] Building Seerr..."
# Forcing Webpack because Turbopack is not yet supported with WASM on Android/arm64
# We also use npx to ensure we're using the local next binary with the correct flags
./node_modules/.bin/next build --webpack
pnpm build:server

# 7. Configure Environment
echo "[*] Configuring environment..."
mkdir -p "$CONFIG_DIR/db" "$CONFIG_DIR/logs" "$CONFIG_DIR/cache/images"

cat <<EOT > .env
CONFIG_DIRECTORY=$CONFIG_DIR
PORT=5055
NODE_ENV=production
EOT

# 8. Setup/Update Service
echo "[*] Setting up termux-service..."
SERVICE_DIR="$PREFIX/var/service/seerr"
mkdir -p "$SERVICE_DIR"
cat <<EOT > "$SERVICE_DIR/run"
#!$PREFIX/bin/bash
exec 2>&1
if [ -f "$REPO_DIR/.env" ]; then
    set -a
    . "$REPO_DIR/.env"
    set +a
fi
cd "$REPO_DIR"
exec node dist/index.js
EOT
chmod +x "$SERVICE_DIR/run"

echo ""
echo "=========================================="
echo "  Seerr Setup Complete!"
echo "=========================================="
echo "To start Seerr:  sv-enable seerr"
echo "To check logs:   tail -f $CONFIG_DIR/logs/seerr-*.log"
echo "URL:             http://localhost:5055"
echo "=========================================="
