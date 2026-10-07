#!/bin/bash
# autorotate.sh - Auto-rotate screen based on device orientation
# Based on https://linuxappfinder.com/blog/auto_screen_rotation_in_ubuntu
#
# Usage: ./autorotate.sh
# Add to your desktop environment's startup applications for automatic execution.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Load configuration
# ---------------------------------------------------------------------------
CONFIG_FILE="${SCRIPT_DIR}/../config/config.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: configuration file not found: $CONFIG_FILE" >&2
    exit 1
fi
# shellcheck source=../config/config.conf
source "$CONFIG_FILE"
export DISPLAY

# ---------------------------------------------------------------------------
# Load rotation library
# ---------------------------------------------------------------------------
LIB_FILE="${SCRIPT_DIR}/../lib/rotate.sh"
if [ ! -f "$LIB_FILE" ]; then
    echo "Error: library file not found: $LIB_FILE" >&2
    exit 1
fi
# shellcheck source=../lib/rotate.sh
source "$LIB_FILE"

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

MONITOR_PID=""

cleanup() {
    if [ -n "$MONITOR_PID" ]; then
        kill "$MONITOR_PID" 2>/dev/null || true
    fi
}
trap cleanup EXIT INT TERM

# Set default (upright) orientation on startup
rotate normal

# Stop any previously running monitor-sensor instance started by this script
LOCK_FILE="/run/user/$(id -u)/autorotate.lock"
if [ -f "$LOCK_FILE" ]; then
    OLD_PID=$(cat "$LOCK_FILE")
    kill "$OLD_PID" 2>/dev/null || true
fi

# Clear the sensor log so it does not grow unbounded
: > "$LOG"

# Start monitor-sensor and append its output to the log
monitor-sensor >> "$LOG" 2>&1 &
MONITOR_PID=$!
echo "$MONITOR_PID" > "$LOCK_FILE"

# Watch the log for orientation changes.
# Possible values: normal, bottom-up, right-up, left-up
while inotifywait -e modify "$LOG"; do
    ORIENTATION=$(tail -n 1 "$LOG" | grep 'orientation' | grep -oE '[^ ]+$' || true)

    if [ -n "$ORIENTATION" ]; then
        rotate "$ORIENTATION"
    fi
done
