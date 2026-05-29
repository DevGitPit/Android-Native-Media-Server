#!/data/data/com.termux/files/usr/bin/bash

# Seerr Termux Native Installer/Updater
# This script handles dependencies, SWC WASM patching, and building.

set -e

REPO_DIR="/data/data/com.termux/files/usr/opt/seerr"
CONFIG_DIR="$HOME/.config/seerr"

echo "[*] Starting Seerr Termux Setup..."

# 1. Install System Dependencies
echo "[*] Checking system dependencies..."
pkg update -y
pkg install -y nodejs git libvips termux-services
npm install -g pnpm

# 2. Setup Directory
if [ ! -d "$REPO_DIR" ]; then
    echo "[*] Creating repository directory..."
    mkdir -p "$(dirname "$REPO_DIR")"
    git clone https://github.com/seerr-team/seerr.git "$REPO_DIR"
    cd "$REPO_DIR"
else
    echo "[*] Updating existing repository..."
    cd "$REPO_DIR"
    
    echo "[*] Local changes summary:"
    git status -s
    git diff --stat || true
    
    echo "[*] Syncing with remote..."
    git stash || true
    git pull
    git stash pop || true
fi

# 3. Loosen Node engine requirement to prevent build blocks
sed -i 's/"node": ".*"/"node": ">=20.0.0"/' package.json

# 4. Install JS Dependencies
echo "[*] Installing node modules (this may take a while)..."
# Using --no-engine-strict to bypass any rigid version checks
CYPRESS_INSTALL_BINARY=0 pnpm install --frozen-lockfile=false --no-engine-strict
pnpm add @next/swc-wasm-nodejs@14.2.33

# 5. Apply Termux Patches (SWC WASM Fallback)
echo "[*] Applying Termux-specific patches..."
INDEX_JS="node_modules/next/dist/build/swc/index.js"
if [ -f "$INDEX_JS" ]; then
    sed -i 's/const isWebContainer = process.versions.webcontainer;/const isWebContainer = true;/g' "$INDEX_JS"
    echo "  [+] Patched Next.js SWC loader for WASM fallback."
fi

if ! grep -q "swcMinify: false" next.config.js; then
    sed -i 's/module.exports = {/module.exports = {\n  swcMinify: false,/' next.config.js
    echo "  [+] Disabled swcMinify in next.config.js."
fi

# 6. Build Project
echo "[*] Building Seerr..."
pnpm build

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
#!/data/data/com.termux/files/usr/bin/bash
exec 2>&1
export \$(cat $REPO_DIR/.env | xargs)
cd $REPO_DIR
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
