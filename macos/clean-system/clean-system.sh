#!/bin/bash
# clean-system.sh - safe cache/temp cleanup for macOS.
# Run with -h or --help for usage. See LEGGIMI.txt for details.

set -u

usage() {
  cat <<'EOF'
clean-system.sh - pulizia sicura di cache, log, temp e Docker su macOS

USO
  ./clean-system.sh [opzioni]

COMPORTAMENTO DI DEFAULT
  Dry-run: mostra cosa verrebbe liberato, non cancella nulla.

OPZIONI
  --apply            Cancella davvero, chiedendo conferma per ogni gruppo
  --yes              Con --apply: nessuna domanda, cancella tutto
  --docker-volumes   Con Docker acceso: prune anche dei volumi non usati
                     (ATTENZIONE: possibile perdita di dati dei container)
  --gradle           Cancella anche ~/.gradle/caches (si riscarica, lento)
  --projects         Cancella anche .venv e node_modules dei progetti in
                     ~/workspace (cartella cambiabile con WORKSPACE=/percorso).
                     Salta i progetti senza requirements.txt/pyproject.toml/
                     Pipfile/setup.py (per .venv) o package.json (node_modules),
                     perche' non sarebbero ricostruibili. Non tocca .env.
  -h, --help         Mostra questo aiuto

ESEMPI
  ./clean-system.sh                  # anteprima
  ./clean-system.sh --apply          # pulizia interattiva
  ./clean-system.sh --apply --yes    # pulizia automatica
  ./clean-system.sh --projects       # anteprima incluso .venv/node_modules
  ./clean-system.sh --apply --projects

NON TOCCA MAI
  ~/Library/Preferences, Application Support (config), Keychains,
  LaunchAgents, /var/folders, i tuoi file e progetti.

NON CANCELLA AUTOMATICAMENTE (solo suggerisce)
  Modelli Ollama, emulatori Android, SDK, .venv/node_modules dei progetti.
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
    *) echo "Opzione sconosciuta: $a"; exit 1 ;;
  esac
done

[ "$(uname)" = "Darwin" ] || { echo "Solo macOS."; exit 1; }

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
  read -r -p "  Procedo? [s/N] " r
  [[ "$r" =~ ^[sSyY]$ ]]
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
      case "$p" in ""|"/"|"$HOME"|"$HOME/") echo "   ${red}✗ rifiuto: $p${reset}"; continue ;; esac
      if [ -d "$p" ]; then
        find "$p" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null
      else
        rm -f "$p"
      fi
    done
    echo "   ${green}✓ ok${reset}"
  else
    echo "   ${yellow}⊘ saltato${reset}"
  fi
}

# cmd_group "<title>" "<command>" : tool-native cleanup, only if tool exists
cmd_group() {
  local title="$1" tool="$2"; shift 2
  command -v "$tool" >/dev/null 2>&1 || return
  echo "${bold}${cyan}⚙ $title${reset}"
  echo "   ${yellow}→${reset} $*"
  [ "$APPLY" -eq 0 ] && return
  if confirm; then "$@" >/dev/null 2>&1 && echo "   ${green}✓ ok${reset}" || echo "   ${yellow}⚠ errore/ignorato${reset}"
  else echo "   ${yellow}⊘ saltato${reset}"; fi
}

echo
echo "$sep"
echo "${bold}${blue}🧹 PULIZIA SISTEMA$( [ $APPLY -eq 1 ] && echo " - APPLY" || echo " - DRY-RUN")${reset}"
echo "$sep"
echo
echo "${blue}Spazio libero ora:${reset} ${cyan}$(human "$START_FREE")${reset}"
echo

# ---- Temp / logs / trash ----
echo "${sep}"
echo "${bold}${blue}🗑️  CESTINO & LOG${reset}"
echo "${sep}"
echo
group "Cestino" "$HOME/.Trash"
group "Log utente" "$HOME/Library/Logs"
group "Crash report" "$HOME/Library/Logs/DiagnosticReports"
group "Temp utente" "${TMPDIR:-/tmp}"/com.apple.* 2>/dev/null
echo

# ---- Cache app (regenerable) ----
echo "${sep}"
echo "${bold}${blue}💾 CACHE APP${reset}"
echo "${sep}"
echo
C="$HOME/Library/Caches"
group "Cache JetBrains (indici/aggiornamenti, non le impostazioni)" "$C/JetBrains"
group "Cache Playwright (browser, riscaricati al bisogno)" "$C/ms-playwright"
group "Cache Google/Chrome" "$C/Google"
group "Cache Firefox" "$C/Firefox"
group "Cache pip/virtualenv/node-gyp/typescript" "$C/pip" "$C/virtualenv" "$C/node-gyp" "$C/typescript"
group "Cache draw.io updater" "$C/draw.io-updater"
group "Residui installer Docker Desktop" "$HOME/Library/Application Support/com.docker.install"
group "Cache VS Code" "$HOME/Library/Application Support/Code/CachedData" "$HOME/Library/Application Support/Code/CachedExtensionVSIXs" "$HOME/Library/Application Support/Code/Cache"
group "Cache npm/yarn" "$HOME/.npm/_cacache" "$HOME/.cache"
[ "$GRADLE" -eq 1 ] && group "Cache Gradle (lenta da ricostruire)" "$HOME/.gradle/caches" "$HOME/.gradle/daemon"
group "Android emulator: snapshot RAM (si rigenera)" "$HOME/.android/avd/Pixel_8a.avd/snapshots"

# ---- Tool-native cleanup ----
echo "${sep}"
echo "${bold}${blue}🛠️  STRUMENTI${reset}"
echo "${sep}"
echo
cmd_group "Homebrew: cache e vecchie versioni" brew brew cleanup -s --prune=all
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
    echo "${bold}${cyan}📊 Utilizzo Docker:${reset}"
    docker system df | sed 's/^/  /'
    echo
    if [ "$DOCKER_VOLUMES" -eq 1 ]; then
      cmd_group "Docker prune -a + volumi NON usati" docker docker system prune -a --volumes -f
    else
      cmd_group "Docker prune -a (immagini/container/network non usati)" docker docker system prune -a -f
    fi
  else
    echo "${yellow}⚠ Docker installato ma daemon spento${reset}"
    echo "   Avvia Docker Desktop per pulire."
    echo
    echo "   ${blue}💡 Tip: Il file Docker.raw sotto${reset}"
    echo "      ${blue}~/Library/Containers/com.docker.docker${reset}"
    echo "      ${blue}spesso occupa molto spazio in 'Dati di sistema'${reset}"
  fi
else
  echo "${yellow}⊘ Docker non installato${reset}"
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
    echo "${bold}${cyan}📸 Snapshot Time Machine locali: ${blue}$snaps${reset}"
    echo "   ${yellow}→${reset} sudo tmutil thinlocalsnapshots / 99999999999 4"
  else
    echo "${green}✓ Nessuno snapshot locale${reset}"
  fi
else
  echo "${yellow}💡 Lancia con ${bold}--apply${reset}${yellow} per gestire gli snapshot${reset}"
fi
echo

# ---- Optional: project dependencies (.venv / node_modules) ----
echo "${sep}"
echo "${bold}${blue}📦 DIPENDENZE PROGETTI${reset}"
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
    echo "${bold}${cyan}📁 .venv / node_modules ricostruibili${reset}  ${blue}$(human "$proj_kb")${reset}  ${cyan}(${#proj[@]} cartelle)${reset}"
    echo
    for d in "${proj[@]}"; do echo "   ${yellow}→${reset} $(human "$(size_of "$d")")  $d"; done
    echo
    if [ "$APPLY" -eq 1 ]; then
      if confirm; then
        for d in "${proj[@]}"; do
          case "$(basename "$d")" in .venv|node_modules) rm -rf "$d" ;; esac
        done
        echo "   ${green}✓ ok${reset}"
        echo "   ${blue}💡 Ricrea con: 'pip install -r requirements.txt' o 'npm install'${reset}"
      else echo "   ${yellow}⊘ saltato${reset}"; fi
    fi
  else
    echo "${yellow}⊘ Nessun .venv/node_modules ricostruibile in $WS${reset}"
  fi
  if [ ${#skipped[@]} -gt 0 ]; then
    echo
    echo "${yellow}⚠ Saltati (nessun file dipendenze, non ricostruibili):${reset}"
    for d in "${skipped[@]}"; do echo "   ${yellow}→${reset} $d"; done
  fi
else
  echo "${yellow}💡 Usa ${bold}--projects${reset}${yellow} per gestire .venv/node_modules${reset}"
fi
echo

# ---- Proposals (never auto-deleted) ----
echo "${sep}"
echo "${bold}${blue}💭 CANDIDATI MANUALI${reset}"
echo "${sep}"
echo

manual_found=0
[ -d "$HOME/.ollama" ] && { echo "${cyan}🤖 Modelli Ollama:${reset} ${blue}$(human "$(size_of "$HOME/.ollama")")${reset}"; echo "   ${yellow}→${reset} 'ollama list' poi 'ollama rm <modello>'"; echo; manual_found=1; }
[ -d "$HOME/.android/avd" ] && { echo "${cyan}📱 Emulatori Android:${reset} ${blue}$(human "$(size_of "$HOME/.android/avd")")${reset}"; echo "   ${yellow}→${reset} Android Studio > Device Manager"; echo; manual_found=1; }
[ -d "$HOME/Library/Android/sdk" ] && { echo "${cyan}📚 Android SDK:${reset} ${blue}$(human "$(size_of "$HOME/Library/Android/sdk")")${reset}"; echo "   ${yellow}→${reset} SDK Manager, togli system image/versioni vecchie"; echo; manual_found=1; }
[ -d "$HOME/Library/Application Support/JetBrains" ] && { echo "${cyan}🧠 JetBrains config:${reset} ${blue}$(human "$(size_of "$HOME/Library/Application Support/JetBrains")")${reset}"; echo "   ${yellow}→${reset} Elimina cartelle IDE vecchie (es. IdeaIC2025.1)"; echo; manual_found=1; }
[ -d "$HOME/Library/Group Containers/group.net.whatsapp.WhatsApp.shared" ] && { echo "${cyan}💬 WhatsApp:${reset} ${blue}$(human "$(size_of "$HOME/Library/Group Containers/group.net.whatsapp.WhatsApp.shared")")${reset}"; echo "   ${yellow}→${reset} In-app: Impostazioni > Spazio/Archiviazione"; echo; manual_found=1; }

top_dirs=$(find "$HOME/workspace" -xdev -maxdepth 5 \( -name node_modules -o -name .venv -o -name target \) -type d -prune 2>/dev/null \
  | while read -r d; do printf "%s\t%s\n" "$(size_of "$d")" "$d"; done | sort -rn | head -10)
if [ -n "$top_dirs" ]; then
  echo "${cyan}📦 Top 10 cartelle rigenerabili (progetti fermi):${reset}"
  echo "$top_dirs" | while IFS=$'\t' read -r kb d; do echo "   ${yellow}→${reset} $(human "$kb")  $d"; done
  manual_found=1
fi

[ "$manual_found" -eq 0 ] && echo "${green}✓ Nessun candidato manuale trovato${reset}"
echo

echo "${sep}"
echo "${bold}${blue}📊 RISULTATO FINALE${reset}"
echo "${sep}"
echo

END_FREE=$(free_kb)
if [ "$APPLY" -eq 1 ]; then
  freed=$((END_FREE - START_FREE))
  if [ "$freed" -gt 0 ]; then
    echo "${green}✓ Liberati: ${bold}$(human "$freed")${reset}${green}${reset}"
  else
    echo "${yellow}⊘ Nessuno spazio liberato${reset}"
  fi
  echo "  Spazio disponibile ora: ${cyan}$(human "$END_FREE")${reset}"
else
  echo "${yellow}Dry-run: nulla cancellato.${reset}"
  echo "  Rilancia con ${bold}--apply${reset}${yellow} per eseguire la pulizia.${reset}"
fi
echo
