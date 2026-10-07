#!/bin/bash
# install.sh - Installation script for linux-screen-autorotate
#
# This script installs the required packages, copies the project to
# /opt/linux-screen-autorotate, and creates an XDG autostart entry so the
# screen rotation starts automatically when the user logs in.
#
# Usage: bash install.sh

set -euo pipefail

INSTALL_DIR="/opt/linux-screen-autorotate"
AUTOSTART_DIR="$HOME/.config/autostart"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Installing dependencies..."
sudo apt-get install -y iio-sensor-proxy inotify-tools x11-xserver-utils xinput

echo "==> Copying files to $INSTALL_DIR..."
sudo mkdir -p "$INSTALL_DIR"
sudo cp -r "$SCRIPT_DIR/src"    "$INSTALL_DIR/"
sudo cp -r "$SCRIPT_DIR/lib"    "$INSTALL_DIR/"
sudo cp -r "$SCRIPT_DIR/config" "$INSTALL_DIR/"
sudo chmod +x "$INSTALL_DIR/src/autorotate.sh"

echo "==> Creating autostart entry..."
mkdir -p "$AUTOSTART_DIR"
cat > "$AUTOSTART_DIR/autorotate.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Screen Auto-Rotate
Exec=$INSTALL_DIR/src/autorotate.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

echo ""
echo "Installation complete."
echo "Edit $INSTALL_DIR/config/config.conf to set your display name (run 'xrandr' to find it)."
