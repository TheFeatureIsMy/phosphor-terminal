#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKEND_DIR="$PROJECT_ROOT/backend"

echo "==> Installing Python dependencies..."
pip3 install --user -r "$BACKEND_DIR/requirements.txt"

echo "==> Installing PyInstaller..."
pip3 install --user pyinstaller

echo "==> Building backend binary with PyInstaller..."
cd "$BACKEND_DIR"
python3 -m PyInstaller pulsedesk-server.spec --clean

echo "==> Copying binary to Tauri sidecar..."
TARGET_TRIPLE=$(rustc -vV | grep host | cut -d' ' -f2)
SIDECAR_DIR="$PROJECT_ROOT/src-tauri/binaries"
mkdir -p "$SIDECAR_DIR"

if [ -f "dist/pulsedesk-server" ]; then
    cp "dist/pulsedesk-server" "$SIDECAR_DIR/pulsedesk-server-$TARGET_TRIPLE"
elif [ -d "dist/pulsedesk-server.app" ]; then
    cp -r "dist/pulsedesk-server.app" "$SIDECAR_DIR/pulsedesk-server-$TARGET_TRIPLE.app"
fi

echo "==> Done! Sidecar binary at: $SIDECAR_DIR/pulsedesk-server-$TARGET_TRIPLE"
