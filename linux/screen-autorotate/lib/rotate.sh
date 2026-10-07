#!/bin/bash
# rotate.sh - Screen rotation library for linux-screen-autorotate
# Provides the rotate() function used by autorotate.sh.
#
# Requires the following variables to be set by the caller:
#   DNAME   - display name (e.g. eDP-1)
#   DISPLAY - X display (e.g. :0)

# rotate <orientation>
#   Rotates the screen and remaps all input devices to match the new orientation.
#   orientation: normal | bottom-up | left-up | right-up
rotate() {
    local ORIENTATION="$1"
    local CUR_ROT
    local NEW_ROT="normal"
    local CTM="1 0 0 0 1 0 0 0 1"

    CUR_ROT=$(xrandr -q --verbose | grep -F "$DNAME" | cut -d" " -f6 || true)
    if [ -z "$CUR_ROT" ]; then
        echo "Error: display '$DNAME' not found. Run 'xrandr' to find the correct name." >&2
        return 1
    fi

    case "$ORIENTATION" in
        normal)
            NEW_ROT="normal"
            CTM="1 0 0 0 1 0 0 0 1"
            ;;
        bottom-up)
            NEW_ROT="inverted"
            CTM="-1 0 1 0 -1 1 0 0 1"
            ;;
        left-up)
            NEW_ROT="left"
            CTM="0 -1 1 1 0 0 0 0 1"
            ;;
        right-up)
            NEW_ROT="right"
            CTM="0 1 0 -1 0 1 0 0 1"
            ;;
        *)
            echo "rotate: unknown orientation '$ORIENTATION'" >&2
            return 1
            ;;
    esac

    echo "ORIENTATION: $ORIENTATION"
    echo "DNAME:       $DNAME"
    echo "DISPLAY:     $DISPLAY"
    echo "NEW_ROT:     $NEW_ROT"
    echo "CUR_ROT:     $CUR_ROT"
    echo "CTM:         $CTM"

    xrandr --output "$DNAME" --rotate "$NEW_ROT"

    # Remap every input device to the rotated display
    while IFS= read -r dev_id; do
        xinput map-to-output "$dev_id" "$DNAME" 2>/dev/null || true
    done < <(xinput --list --id-only)
}
