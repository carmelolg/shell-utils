#!/bin/bash
# clean-system.sh - safe cache/temp cleanup for macOS.
# Run with -h or --help for usage. See README.txt for details.

set -u

usage() {
  cat <<'EOF'
clean-system.sh - safe cleanup of caches, logs, temp files and Docker on macOS

USAGE
  ./clean-system.sh [options]

DEFAULT BEHAVIOR
  Dry-run: shows what would be freed, deletes nothing.

OPTIONS
  --apply            Actually delete, asking for confirmation for each group
  --yes              With --apply: no questions, delete everything
  --docker-volumes   With Docker running: also prune unused volumes
                     (WARNING: possible loss of container data)
  --gradle           Also delete ~/.gradle/caches (re-downloaded, slow)
  --projects         Also delete .venv and node_modules of projects in
                     ~/workspace (folder changeable with WORKSPACE=/path).
                     Skips projects without requirements.txt/pyproject.toml/
                     Pipfile/setup.py (for .venv) or package.json (node_modules),
                     because they could not be rebuilt. Does not touch .env.
  -h, --help         Show this help

EXAMPLES
  ./clean-system.sh                  # preview
  ./clean-system.sh --apply          # interactive cleanup
  ./clean-system.sh --apply --yes    # automatic cleanup
  ./clean-system.sh --projects       # preview including .venv/node_modules
  ./clean-system.sh --apply --projects

NEVER TOUCHES
  ~/Library/Preferences, Application Support (config), Keychains,
  LaunchAgents, /var/folders, your files and projects.

NEVER DELETES AUTOMATICALLY (only suggests)
  Ollama models, Android emulators, SDKs, .venv/node_modules of projects.
EOF
}

APPLY=0; YES=0; DOCKER_VOLUMES=0; GRADLE=0; PROJECTS=0
for a in "$@"; do
  case "$a" in
    --projects) PROJECTS=1 ;;
    --apply) APPLY=1 ;;
    --yes) YES=1 ;;
    --docker-volumes) DOCKER_VOLUMES=1 ;;
    --gradle) GRADLE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $a"; exit 1 ;;
  esac
done

[ "$(uname)" = "Darwin" ] || { echo "macOS only."; exit 1; }

bold=$'\033[1m'; green=$'\033[32m'; yellow=$'\033[33m'; blue=$'\033[34m'; cyan=$'\033[36m'; red=$'\033[31m'; reset=$'\033[0m'
sep="${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"
free_kb() { df -k "$HOME" | awk 'NR==2 {print $4}'; }
START_FREE=$(free_kb)

size_of() { du -sk "$@" 2>/dev/null | awk '{s+=$1} END {print s+0}'; }
human() { awk -v k="$1" 'BEGIN {
  if (k>=1048576) printf "%.1f GB", k/1048576;
  else if (k>=1024) printf "%.0f MB", k/1024; else printf "%d KB", k }'; }

confirm() {
  [ "$YES" -eq 1 ] && return 0
  read -r -p "  Proceed? [y/N] " r
  [[ "$r" =~ ^[yY]$ ]]
}

# group "<title>" path...   -> deletes the CONTENT of each existing path
group() {
  local title="$1"; shift
  local existing=()
  for p in "$@"; do [ -e "$p" ] && existing+=("$p"); done
  [ ${#existing[@]} -eq 0 ] && return
  local kb; kb=$(size_of "${existing[@]}")
  [ "$kb" -lt 1024 ] && return
  echo "${bold}${cyan}📁 $title${reset}  ${blue}$(human "$kb")${reset}"
  for p in "${existing[@]}"; do echo "   ${yellow}→${reset} $p"; done
  [ "$APPLY" -eq 0 ] && return
  if confirm; then
    for p in "${existing[@]}"; do
      case "$p" in ""|"/"|"$HOME"|"$HOME/") echo "   ${red}✗ refused: $p${reset}"; continue ;; esac
      if [ -d "$p" ]; then
        find "$p" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
      else
        rm -f "$p"
      fi
    done
    echo "   ${green}✓ done${reset}"
  else
    echo "   ${yellow}⊘ skipped${reset}"
  fi
}

# cmd_group "<title>" "<command>" : tool-native cleanup, only if tool exists
cmd_group() {
  local title="$1" tool="$2"; shift 2
  command -v "$tool" >/dev/null 2>&1 || return
  echo "${bold}${cyan}⚙ $title${reset}"
  echo "   ${yellow}→${reset} $*"
  [ "$APPLY" -eq 0 ] && return
  if confirm; then "$@" >/dev/null 2>&1 && echo "   ${green}✓ done${reset}" || echo "   ${yellow}⚠ error/ignored${reset}"
  else echo "   ${yellow}⊘ skipped${reset}"; fi
}

echo
echo "$sep"
echo "${bold}${blue}🧹 SYSTEM CLEANUP$( [ $APPLY -eq 1 ] && echo " - APPLY" || echo " - DRY-RUN")${reset}"
echo "$sep"
echo
echo "${blue}Free space now:${reset} ${cyan}$(human "$START_FREE")${reset}"
echo

# ---- Temp / logs / trash ----
echo "${sep}"
echo "${bold}${blue}🗑️  TRASH & LOGS${reset}"
echo "${sep}"
echo
group "Trash" "$HOME/.Trash"
group "User logs" "$HOME/Library/Logs"
group "Crash reports" "$HOME/Library/Logs/DiagnosticReports"
group "User temp" "${TMPDIR:-/tmp}"/com.apple.* 2>/dev/null
echo

# ---- App cache (regenerable) ----
echo "${sep}"
echo "${bold}${blue}💾 APP CACHE${reset}"
echo "${sep}"
echo
C="$HOME/Library/Caches"
group "JetBrains cache (indexes/updates, not settings)" "$C/JetBrains"
group "Playwright cache (browsers, re-downloaded when needed)" "$C/ms-playwright"
group "Google/Chrome cache" "$C/Google"
group "Firefox cache" "$C/Firefox"
group "pip/virtualenv/node-gyp/typescript cache" "$C/pip" "$C/virtualenv" "$C/node-gyp" "$C/typescript"
group "draw.io updater cache" "$C/draw.io-updater"
group "Docker Desktop installer leftovers" "$HOME/Library/Application Support/com.docker.install"
group "VS Code cache" "$HOME/Library/Application Support/Code/CachedData" "$HOME/Library/Application Support/Code/CachedExtensionVSIXs" "$HOME/Library/Application Support/Code/Cache"
group "npm/yarn cache" "$HOME/.npm/_cacache" "$HOME/.cache"
[ "$GRADLE" -eq 1 ] && group "Gradle cache (slow to rebuild)" "$HOME/.gradle/caches" "$HOME/.gradle/daemon"
group "Android emulator: RAM snapshots (regenerated)" "$HOME/.android/avd/Pixel_8a.avd/snapshots"

# ---- Tool-native cleanup ----
echo "${sep}"
echo "${bold}${blue}🛠️  TOOLS${reset}"
echo "${sep}"
echo
cmd_group "Homebrew: cache and old versions" brew brew cleanup -s --prune=all
cmd_group "Go build cache" go go clean -cache
cmd_group "pip cache" pip3 pip3 cache purge

# ---- Docker ----
echo
echo "${sep}"
echo "${bold}${blue}🐳 DOCKER${reset}"
echo "${sep}"
echo
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    echo "${bold}${cyan}📊 Docker usage:${reset}"
    docker system df | sed 's/^/  /'
    echo
    if [ "$DOCKER_VOLUMES" -eq 1 ]; then
      cmd_group "Docker prune -a + UNUSED volumes" docker docker system prune -a --volumes -f
    else
      cmd_group "Docker prune -a (unused images/containers/networks)" docker docker system prune -a -f
    fi
  else
    echo "${yellow}⚠ Docker installed but daemon not running${reset}"
    echo "   Start Docker Desktop to clean it."
    echo
    echo "   ${blue}💡 Tip: The Docker.raw file under${reset}"
    echo "      ${blue}~/Library/Containers/com.docker.docker${reset}"
    echo "      ${blue}often takes a lot of space in 'System Data'${reset}"
  fi
else
  echo "${yellow}⊘ Docker not installed${reset}"
fi
echo

# ---- Time Machine local snapshots ----
echo "${sep}"
echo "${bold}${blue}⏱️  TIME MACHINE${reset}"
echo "${sep}"
echo
if [ "$APPLY" -eq 1 ]; then
  snaps=$(tmutil listlocalsnapshots / 2>/dev/null | grep -c 'com.apple')
  if [ "$snaps" -gt 0 ]; then
    echo "${bold}${cyan}📸 Local Time Machine snapshots: ${blue}$snaps${reset}"
    echo "   ${yellow}→${reset} sudo tmutil thinlocalsnapshots / 99999999999 4"
  else
    echo "${green}✓ No local snapshots${reset}"
  fi
else
  echo "${yellow}💡 Run with ${bold}--apply${reset}${yellow} to manage snapshots${reset}"
fi
echo

# ---- Optional: project dependencies (.venv / node_modules) ----
echo "${sep}"
echo "${bold}${blue}📦 PROJECT DEPENDENCIES${reset}"
echo "${sep}"
echo
if [ "$PROJECTS" -eq 1 ]; then
  WS="${WORKSPACE:-$HOME/workspace}"
  proj=(); proj_kb=0; skipped=()
  while IFS= read -r d; do
    parent=$(dirname "$d"); ok=0
    case "$(basename "$d")" in
      node_modules) [ -f "$parent/package.json" ] && ok=1 ;;
      .venv) for m in requirements.txt pyproject.toml Pipfile setup.py; do
               [ -f "$parent/$m" ] && ok=1
             done ;;
    esac
    if [ "$ok" -eq 1 ]; then proj+=("$d"); else skipped+=("$d"); fi
  done < <(find "$WS" -xdev -type d \( -name .venv -o -name node_modules \) -prune -print 2>/dev/null)

  if [ ${#proj[@]} -gt 0 ]; then
    proj_kb=$(size_of "${proj[@]}")
    echo "${bold}${cyan}📁 Rebuildable .venv / node_modules${reset}  ${blue}$(human "$proj_kb")${reset}  ${cyan}(${#proj[@]} folders)${reset}"
    echo
    for d in "${proj[@]}"; do echo "   ${yellow}→${reset} $(human "$(size_of "$d")")  $d"; done
    echo
    if [ "$APPLY" -eq 1 ]; then
      if confirm; then
        for d in "${proj[@]}"; do
          case "$(basename "$d")" in .venv|node_modules) rm -rf "$d" ;; esac
        done
        echo "   ${green}✓ done${reset}"
        echo "   ${blue}💡 Recreate with: 'pip install -r requirements.txt' or 'npm install'${reset}"
      else echo "   ${yellow}⊘ skipped${reset}"; fi
    fi
  else
    echo "${yellow}⊘ No rebuildable .venv/node_modules in $WS${reset}"
  fi
  if [ ${#skipped[@]} -gt 0 ]; then
    echo
    echo "${yellow}⚠ Skipped (no dependency file, not rebuildable):${reset}"
    for d in "${skipped[@]}"; do echo "   ${yellow}→${reset} $d"; done
  fi
else
  echo "${yellow}💡 Use ${bold}--projects${reset}${yellow} to manage .venv/node_modules${reset}"
fi
echo

# ---- Proposals (never auto-deleted) ----
echo "${sep}"
echo "${bold}${blue}💭 MANUAL CANDIDATES${reset}"
echo "${sep}"
echo

manual_found=0
[ -d "$HOME/.ollama" ] && { echo "${cyan}🤖 Ollama models:${reset} ${blue}$(human "$(size_of "$HOME/.ollama")")${reset}"; echo "   ${yellow}→${reset} 'ollama list' then 'ollama rm <model>'"; echo; manual_found=1; }
[ -d "$HOME/.android/avd" ] && { echo "${cyan}📱 Android emulators:${reset} ${blue}$(human "$(size_of "$HOME/.android/avd")")${reset}"; echo "   ${yellow}→${reset} Android Studio > Device Manager"; echo; manual_found=1; }
[ -d "$HOME/Library/Android/sdk" ] && { echo "${cyan}📚 Android SDK:${reset} ${blue}$(human "$(size_of "$HOME/Library/Android/sdk")")${reset}"; echo "   ${yellow}→${reset} SDK Manager, remove old system images/versions"; echo; manual_found=1; }
[ -d "$HOME/Library/Application Support/JetBrains" ] && { echo "${cyan}🧠 JetBrains config:${reset} ${blue}$(human "$(size_of "$HOME/Library/Application Support/JetBrains")")${reset}"; echo "   ${yellow}→${reset} Delete old IDE folders (e.g. IdeaIC2025.1)"; echo; manual_found=1; }
[ -d "$HOME/Library/Group Containers/group.net.whatsapp.WhatsApp.shared" ] && { echo "${cyan}💬 WhatsApp:${reset} ${blue}$(human "$(size_of "$HOME/Library/Group Containers/group.net.whatsapp.WhatsApp.shared")")${reset}"; echo "   ${yellow}→${reset} In-app: Settings > Storage"; echo; manual_found=1; }

top_dirs=$(find "$HOME/workspace" -xdev -maxdepth 5 \( -name node_modules -o -name .venv -o -name target \) -type d -prune 2>/dev/null \
  | while read -r d; do printf "%s\t%s\n" "$(size_of "$d")" "$d"; done | sort -rn | head -10)
if [ -n "$top_dirs" ]; then
  echo "${cyan}📦 Top 10 rebuildable folders (idle projects):${reset}"
  echo "$top_dirs" | while IFS=$'\t' read -r kb d; do echo "   ${yellow}→${reset} $(human "$kb")  $d"; done
  manual_found=1
fi

[ "$manual_found" -eq 0 ] && echo "${green}✓ No manual candidates found${reset}"
echo

echo "${sep}"
echo "${bold}${blue}📊 FINAL RESULT${reset}"
echo "${sep}"
echo

END_FREE=$(free_kb)
if [ "$APPLY" -eq 1 ]; then
  freed=$((END_FREE - START_FREE))
  if [ "$freed" -gt 0 ]; then
    echo "${green}✓ Freed: ${bold}$(human "$freed")${reset}${green}${reset}"
  else
    echo "${yellow}⊘ No space freed${reset}"
  fi
  echo "  Free space now: ${cyan}$(human "$END_FREE")${reset}"
else
  echo "${yellow}Dry-run: nothing deleted.${reset}"
  echo "  Re-run with ${bold}--apply${reset}${yellow} to perform the cleanup.${reset}"
fi
echo
