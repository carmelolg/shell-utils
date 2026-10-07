#!/bin/bash
# make-bootable.sh - wizard to write an ISO to a USB drive (macOS)
# Usage: ./make-bootable.sh [path/to/image.iso]

set -u

show_help() {
  cat << 'EOF'
make-bootable.sh - Create a bootable USB drive from an ISO on macOS

USAGE:
  ./make-bootable.sh [path/to/image.iso]
  ./make-bootable.sh -h, --help

ARGUMENTS:
  path/to/image.iso   Path to the ISO image (optional)
                      If omitted, choose an ISO from ~/Downloads or type a path

OPTIONS:
  -h, --help          Show this message

FEATURES:
  • Automatically detects ISOs in ~/Downloads
  • Lists available external USB drives
  • Checks that the ISO is not larger than the disk
  • Asks for confirmation before erasing the disk
  • Shows a progress bar on recent macOS versions
  • Uses the raw device (/dev/rdisk) for fast writing

REQUIREMENTS:
  • macOS (not supported on Linux/Windows)
  • sudo (for disk access)
  • Full Disk Access for Terminal (if requested)

EXAMPLES:
  ./make-bootable.sh ~/Downloads/xubuntu-26.04-desktop-amd64.iso
  ./make-bootable.sh  # Choose ISO interactively

LIMITATIONS:
  • Erases everything on the chosen disk (irreversible)
  • Requires the sudo password
  • Physical external disks only
EOF
  exit 0
}

case "${1:-}" in
  -h|--help) show_help ;;
esac

if [ "$(uname)" != "Darwin" ]; then
  echo "This script only works on macOS."
  exit 1
fi

bold=$'\033[1m'; red=$'\033[31m'; green=$'\033[32m'; blue=$'\033[34m'; yellow=$'\033[33m'; cyan=$'\033[36m'; reset=$'\033[0m'
sep="${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"

# ---------- 1. ISO selection ----------
echo
echo "${sep}"
echo "${bold}${blue}📦 ISO IMAGE SELECTION${reset}"
echo "${sep}"
echo

ISO="${1:-}"

if [ -z "$ISO" ]; then
  isos=()
  while IFS= read -r f; do isos+=("$f"); done < <(ls -t "$HOME"/Downloads/*.iso 2>/dev/null)

  if [ ${#isos[@]} -eq 0 ]; then
    echo "${yellow}⚠  No ISO found in ~/Downloads${reset}"
    echo
    read -r -p "${bold}Enter ISO path:${reset} " ISO
  else
    echo "${green}✓ ISOs found in ~/Downloads:${reset}"
    echo
    i=1
    for f in "${isos[@]}"; do
      size=$(stat -f%z "$f" | awk '{printf "%.2f GB", $1/1073741824}')
      printf "  ${cyan}%d)${reset} %s\n" "$i" "$(basename "$f")"
      printf "     ${blue}%s${reset}\n" "$size"
      i=$((i + 1))
    done
    echo
    printf "  ${cyan}0)${reset} ${yellow}Enter a different path${reset}\n"
    echo
    read -r -p "${bold}Choice:${reset} " n
    if [ "$n" = "0" ]; then
      read -r -p "${bold}ISO path:${reset} " ISO
    elif [ "$n" -ge 1 ] 2>/dev/null && [ "$n" -le ${#isos[@]} ]; then
      ISO="${isos[$((n - 1))]}"
    else
      echo "${red}✗ Invalid choice${reset}"; exit 1
    fi
  fi
fi

ISO="${ISO/#\~/$HOME}"
if [ ! -f "$ISO" ]; then
  echo "${red}✗ ISO not found: $ISO${reset}"; exit 1
fi
ISO_SIZE=$(stat -f%z "$ISO")
echo "${green}✓ ISO loaded: $(basename "$ISO")${reset}"
echo "  Size: $(echo "$ISO_SIZE" | awk '{printf "%.2f GB", $1/1073741824}')"
echo

# ---------- 2. Disk selection (physical external only) ----------
echo "${sep}"
echo "${bold}${blue}💾 USB DISK SELECTION${reset}"
echo "${sep}"
echo

disks=()
while IFS= read -r d; do disks+=("$d"); done \
  < <(diskutil list external physical | awk '/^\/dev\/disk/ {print $1}')

if [ ${#disks[@]} -eq 0 ]; then
  echo "${red}✗ No external disk found.${reset}"
  echo "${yellow}Connect the USB drive and try again.${reset}"
  exit 1
fi

echo "${green}✓ External disks detected:${reset}"
echo
i=1
for d in "${disks[@]}"; do
  info=$(diskutil info "$d")
  name=$(echo "$info" | awk -F': *' '/Media Name/ {print $2; exit}')
  size=$(echo "$info" | awk -F': *' '/Disk Size/ {print $2; exit}' | cut -d'(' -f1)
  vols=$(diskutil list "$d" | awk 'NR>2 && $NF ~ /^disk/ {print}' | wc -l | tr -d ' ')
  printf "  ${cyan}%d)${reset} ${bold}%s${reset}\n" "$i" "$d"
  printf "     Name: ${blue}%s${reset}\n" "${name:-?}"
  printf "     Size: ${blue}%s${reset}\n" "$size"
  printf "     Partitions: ${blue}%s${reset}\n" "$vols"
  echo
  i=$((i + 1))
done

printf "  ${cyan}q)${reset} ${yellow}Quit${reset}\n"
echo
read -r -p "${bold}Which disk to use?${reset} " n
[ "$n" = "q" ] && exit 0
if ! { [ "$n" -ge 1 ] 2>/dev/null && [ "$n" -le ${#disks[@]} ]; }; then
  echo "${red}✗ Invalid choice${reset}"; exit 1
fi
DISK="${disks[$((n - 1))]}"
RDISK="/dev/r${DISK#/dev/}"
echo "${green}✓ Disk selected: $DISK${reset}"
echo

# ---------- 3. Checks ----------
echo "${sep}"
echo "${bold}${blue}🔍 COMPATIBILITY CHECK${reset}"
echo "${sep}"
echo

DISK_SIZE=$(diskutil info -plist "$DISK" | plutil -extract TotalSize raw - 2>/dev/null || echo 0)
if [ "$DISK_SIZE" -gt 0 ] 2>/dev/null && [ "$ISO_SIZE" -gt "$DISK_SIZE" ]; then
  echo "${red}✗ ISO is larger than the available disk${reset}"
  echo "  ISO: $(echo "$ISO_SIZE" | awk '{printf "%.2f GB", $1/1073741824}')"
  echo "  Disk: $(echo "$DISK_SIZE" | awk '{printf "%.2f GB", $1/1073741824}')"
  exit 1
fi
echo "${green}✓ ISO and disk are compatible${reset}"
echo

# ---------- 4. Confirmation ----------
echo "${sep}"
echo "${bold}${blue}📋 OPERATION SUMMARY${reset}"
echo "${sep}"
echo

echo "${bold}Image:${reset}"
echo "  ${cyan}$(basename "$ISO")${reset}"
echo "  Size: $(echo "$ISO_SIZE" | awk '{printf "%.2f GB", $1/1073741824}')"
echo

echo "${bold}Target disk:${reset}"
diskutil list "$DISK" 2>/dev/null | head -n 8 | sed 's/^/  /'
echo

echo "${red}${bold}⚠ WARNING: ALL data on $DISK will be ERASED!${reset}"
echo

diskname="${DISK#/dev/}"
read -r -p "${bold}To confirm, type ${cyan}${diskname}${reset}${bold}:${reset} " confirm
if [ "$confirm" != "$diskname" ]; then
  echo "${yellow}Operation cancelled.${reset}"; exit 0
fi
echo

# ---------- 5. Writing ----------
echo "${sep}"
echo "${bold}${blue}⚙ WRITING IMAGE${reset}"
echo "${sep}"
echo

diskutil unmountDisk "$DISK" 2>/dev/null || { echo "${red}✗ Unmount failed.${reset}"; exit 1; }
echo "${green}✓ Disk unmounted${reset}"
echo

# status=progress is only supported on recent macOS
if dd if=/dev/null of=/dev/null status=progress >/dev/null 2>&1; then
  PROG="status=progress"
else
  PROG=""
  echo "${yellow}💡 Tip: Press ${bold}Ctrl+T${reset}${yellow} to see the write status${reset}"
  echo
fi

echo "${bold}Writing...${reset}"
echo "${yellow}You will be asked for the sudo password${reset}"
echo

# shellcheck disable=SC2086
if ! sudo dd if="$ISO" of="$RDISK" bs=4m $PROG; then
  echo
  echo "${red}✗ Error while writing${reset}"
  echo
  echo "${yellow}If you see 'Operation not permitted':${reset}"
  echo "  1. Open ${bold}System Settings${reset}"
  echo "  2. Go to ${bold}Privacy & Security${reset}"
  echo "  3. Select ${bold}Full Disk Access${reset}"
  echo "  4. Enable ${bold}Terminal${reset}"
  echo "  5. Restart Terminal"
  exit 1
fi
echo

sync
echo "${green}✓ Image written successfully${reset}"

diskutil eject "$DISK" 2>/dev/null
echo "${green}✓ Disk ejected${reset}"
echo

echo "${sep}"
echo "${bold}${green}✓ DONE!${reset}"
echo "${sep}"
echo
echo "${green}${bold}Bootable USB ready!${reset}"
echo "You can unplug the drive and use it for installation."
echo
