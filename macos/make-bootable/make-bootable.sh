#!/bin/bash
# make-bootable.sh - wizard to write an ISO to a USB drive (macOS)
# Usage: ./make-bootable.sh [path/to/image.iso]

set -u

show_help() {
  cat << 'EOF'
make-bootable.sh - Crea USB bootabile da ISO su macOS

USO:
  ./make-bootable.sh [path/to/image.iso]
  ./make-bootable.sh -h, --help

ARGOMENTI:
  path/to/image.iso   Percorso all'immagine ISO (opzionale)
                      Se omesso, scegli da ISO in ~/Downloads o digita percorso

OPZIONI:
  -h, --help          Mostra questo messaggio

FUNZIONALITÀ:
  • Rileva automaticamente ISO in ~/Downloads
  • Elenca dischi USB esterni disponibili
  • Verifica che ISO non sia più grande del disco
  • Chiede conferma prima di cancellare il disco
  • Supporta barra di progresso su macOS recenti
  • Empiega il raw device (/dev/rdisk) per scrittura veloce

PREREQUISITI:
  • macOS (non supportato su Linux/Windows)
  • sudo (per accesso disco)
  • Full Disk Access su Terminale (se richiesto)

ESEMPIO:
  ./make-bootable.sh ~/Downloads/xubuntu-26.04-desktop-amd64.iso
  ./make-bootable.sh  # Scegli ISO interattivamente

LIMITAZIONI:
  • Cancella tutto sul disco scelto (irreversibile)
  • Richiede password sudo
  • Solo dischi esterni fisici
EOF
  exit 0
}

case "${1:-}" in
  -h|--help) show_help ;;
esac

if [ "$(uname)" != "Darwin" ]; then
  echo "Questo script funziona solo su macOS."
  exit 1
fi

bold=$'\033[1m'; red=$'\033[31m'; green=$'\033[32m'; blue=$'\033[34m'; yellow=$'\033[33m'; cyan=$'\033[36m'; reset=$'\033[0m'
sep="${cyan}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}"

# ---------- 1. Scelta ISO ----------
echo
echo "${sep}"
echo "${bold}${blue}📦 SCELTA IMMAGINE ISO${reset}"
echo "${sep}"
echo

ISO="${1:-}"

if [ -z "$ISO" ]; then
  isos=()
  while IFS= read -r f; do isos+=("$f"); done < <(ls -t "$HOME"/Downloads/*.iso 2>/dev/null)

  if [ ${#isos[@]} -eq 0 ]; then
    echo "${yellow}⚠  Nessuna ISO trovata in ~/Downloads${reset}"
    echo
    read -r -p "${bold}Inserisci percorso ISO:${reset} " ISO
  else
    echo "${green}✓ ISO trovate in ~/Downloads:${reset}"
    echo
    i=1
    for f in "${isos[@]}"; do
      size=$(stat -f%z "$f" | awk '{printf "%.2f GB", $1/1073741824}')
      printf "  ${cyan}%d)${reset} %s\n" "$i" "$(basename "$f")"
      printf "     ${blue}%s${reset}\n" "$size"
      i=$((i + 1))
    done
    echo
    printf "  ${cyan}0)${reset} ${yellow}Inserisci un percorso diverso${reset}\n"
    echo
    read -r -p "${bold}Scelta:${reset} " n
    if [ "$n" = "0" ]; then
      read -r -p "${bold}Percorso ISO:${reset} " ISO
    elif [ "$n" -ge 1 ] 2>/dev/null && [ "$n" -le ${#isos[@]} ]; then
      ISO="${isos[$((n - 1))]}"
    else
      echo "${red}✗ Scelta non valida${reset}"; exit 1
    fi
  fi
fi

ISO="${ISO/#\~/$HOME}"
if [ ! -f "$ISO" ]; then
  echo "${red}✗ ISO non trovata: $ISO${reset}"; exit 1
fi
ISO_SIZE=$(stat -f%z "$ISO")
echo "${green}✓ ISO caricata: $(basename "$ISO")${reset}"
echo "  Dimensione: $(echo "$ISO_SIZE" | awk '{printf "%.2f GB", $1/1073741824}')"
echo

# ---------- 2. Scelta disco (solo esterni fisici) ----------
echo "${sep}"
echo "${bold}${blue}💾 SCELTA DISCO USB${reset}"
echo "${sep}"
echo

disks=()
while IFS= read -r d; do disks+=("$d"); done \
  < <(diskutil list external physical | awk '/^\/dev\/disk/ {print $1}')

if [ ${#disks[@]} -eq 0 ]; then
  echo "${red}✗ Nessun disco esterno trovato.${reset}"
  echo "${yellow}Collega la pendrive USB e riprova.${reset}"
  exit 1
fi

echo "${green}✓ Dischi esterni rilevati:${reset}"
echo
i=1
for d in "${disks[@]}"; do
  info=$(diskutil info "$d")
  name=$(echo "$info" | awk -F': *' '/Media Name/ {print $2; exit}')
  size=$(echo "$info" | awk -F': *' '/Disk Size/ {print $2; exit}' | cut -d'(' -f1)
  vols=$(diskutil list "$d" | awk 'NR>2 && $NF ~ /^disk/ {print}' | wc -l | tr -d ' ')
  printf "  ${cyan}%d)${reset} ${bold}%s${reset}\n" "$i" "$d"
  printf "     Nome: ${blue}%s${reset}\n" "${name:-?}"
  printf "     Dimensione: ${blue}%s${reset}\n" "$size"
  printf "     Partizioni: ${blue}%s${reset}\n" "$vols"
  echo
  i=$((i + 1))
done

printf "  ${cyan}q)${reset} ${yellow}Esci${reset}\n"
echo
read -r -p "${bold}Quale disco usare?${reset} " n
[ "$n" = "q" ] && exit 0
if ! { [ "$n" -ge 1 ] 2>/dev/null && [ "$n" -le ${#disks[@]} ]; }; then
  echo "${red}✗ Scelta non valida${reset}"; exit 1
fi
DISK="${disks[$((n - 1))]}"
RDISK="/dev/r${DISK#/dev/}"
echo "${green}✓ Disco selezionato: $DISK${reset}"
echo

# ---------- 3. Controlli ----------
echo "${sep}"
echo "${bold}${blue}🔍 VERIFICA COMPATIBILITÀ${reset}"
echo "${sep}"
echo

DISK_SIZE=$(diskutil info -plist "$DISK" | plutil -extract TotalSize raw - 2>/dev/null || echo 0)
if [ "$DISK_SIZE" -gt 0 ] 2>/dev/null && [ "$ISO_SIZE" -gt "$DISK_SIZE" ]; then
  echo "${red}✗ ISO più grande del disco disponibile${reset}"
  echo "  ISO: $(echo "$ISO_SIZE" | awk '{printf "%.2f GB", $1/1073741824}')"
  echo "  Disco: $(echo "$DISK_SIZE" | awk '{printf "%.2f GB", $1/1073741824}')"
  exit 1
fi
echo "${green}✓ ISO e disco compatibili${reset}"
echo

# ---------- 4. Conferma ----------
echo "${sep}"
echo "${bold}${blue}📋 RIEPILOGO OPERAZIONE${reset}"
echo "${sep}"
echo

echo "${bold}Immagine:${reset}"
echo "  ${cyan}$(basename "$ISO")${reset}"
echo "  Dimensione: $(echo "$ISO_SIZE" | awk '{printf "%.2f GB", $1/1073741824}')"
echo

echo "${bold}Disco di destinazione:${reset}"
diskutil list "$DISK" 2>/dev/null | head -n 8 | sed 's/^/  /'
echo

echo "${red}${bold}⚠ ATTENZIONE: TUTTO il contenuto di $DISK sarà CANCELLATO!${reset}"
echo

diskname="${DISK#/dev/}"
read -r -p "${bold}Per confermare, scrivi ${cyan}${diskname}${reset}${bold}:${reset} " confirm
if [ "$confirm" != "$diskname" ]; then
  echo "${yellow}Operazione annullata.${reset}"; exit 0
fi
echo

# ---------- 5. Scrittura ----------
echo "${sep}"
echo "${bold}${blue}⚙ SCRITTURA IMMAGINE${reset}"
echo "${sep}"
echo

diskutil unmountDisk "$DISK" 2>/dev/null || { echo "${red}✗ Unmount fallito.${reset}"; exit 1; }
echo "${green}✓ Disco smontato${reset}"
echo

# status=progress supportato solo su macOS recenti
if dd if=/dev/null of=/dev/null status=progress >/dev/null 2>&1; then
  PROG="status=progress"
else
  PROG=""
  echo "${yellow}💡 Tip: Premi ${bold}Ctrl+T${reset}${yellow} per vedere lo stato della scrittura${reset}"
  echo
fi

echo "${bold}Scrittura in corso...${reset}"
echo "${yellow}Verrà richiesta la password sudo${reset}"
echo

# shellcheck disable=SC2086
if ! sudo dd if="$ISO" of="$RDISK" bs=4m $PROG; then
  echo
  echo "${red}✗ Errore durante la scrittura${reset}"
  echo
  echo "${yellow}Se vedi 'Operation not permitted':${reset}"
  echo "  1. Apri ${bold}Impostazioni di Sistema${reset}"
  echo "  2. Vai a ${bold}Privacy e sicurezza${reset}"
  echo "  3. Seleziona ${bold}Accesso completo al disco${reset}"
  echo "  4. Abilita ${bold}Terminale${reset}"
  echo "  5. Riavvia Terminale"
  exit 1
fi
echo

sync
echo "${green}✓ Immagine scritta con successo${reset}"

diskutil eject "$DISK" 2>/dev/null
echo "${green}✓ Disco espulso${reset}"
echo

echo "${sep}"
echo "${bold}${green}✓ COMPLETATO!${reset}"
echo "${sep}"
echo
echo "${green}${bold}USB bootabile pronta!${reset}"
echo "Puoi staccare la pendrive e usarla per l'installazione."
echo
