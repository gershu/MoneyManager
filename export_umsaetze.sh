#!/bin/bash
#
# export_umsaetze.sh — MoneyMoney-Umsätze von nova-hub als Excel (.xlsx) holen
#
# Läuft auf nova-w1. Startet den Export per SSH auf nova-hub (dort läuft
# MoneyMoney) und kopiert die Dateien per scp in EXPORT_DIR — eine Datei
# pro Konto, Zeitraum: letzte DAYS Tage.
#
# Nutzung:
#   ./export_umsaetze.sh           # Export ausführen
#   ./export_umsaetze.sh --list    # verfügbare Kontonamen anzeigen
#
# Voraussetzungen:
#   - SSH-Zugang zu nova-hub (Entfernte Anmeldung aktiv, idealerweise SSH-Key)
#   - Auf nova-hub: MoneyMoney läuft, Datenbank entsperrt, Benutzer angemeldet
#   - Erster Lauf: Automation-Dialog erscheint AUF NOVA-HUB → dort bestätigen

set -euo pipefail

# ===================== KONFIGURATION =====================

# SSH-Ziel (ggf. "benutzer@nova-hub" oder Host-Alias aus ~/.ssh/config)
REMOTE_HOST="stefan_mac@nova-hub"

# Konten: Name, IBAN oder UUID (UUID per ./export_umsaetze.sh --list).
# Bei doppelten Namen (z. B. "DKB" unter Girokonten UND Tagesgeld)
# unbedingt UUID oder IBAN verwenden!
ACCOUNTS=(
  "DIBA"
  "comdirect"
  "consors"
  # "DKB"   # doppelt vorhanden → UUID aus --list eintragen
)

# Zeitraum: letzte N Tage
DAYS=90

# Zielordner auf nova-w1
EXPORT_DIR="$HOME/Documents/Claude/Projects/MoneyManager/exports"

# =========================================================

remote_osascript() {
  ssh "$REMOTE_HOST" osascript - <<EOF
$1
EOF
}

# Vorab-Check: MoneyMoney muss auf nova-hub bereits laufen (aus einer
# SSH-Sitzung kann macOS keine GUI-App starten → Fehler -10810).
check_remote() {
  local ssh_user console_user
  if ! ssh "$REMOTE_HOST" pgrep -xq MoneyMoney; then
    echo "FEHLER: MoneyMoney läuft nicht auf ${REMOTE_HOST}." >&2
    echo "        Bitte dort starten (und entsperren), dann erneut versuchen." >&2
    exit 1
  fi
  ssh_user=$(ssh "$REMOTE_HOST" whoami)
  console_user=$(ssh "$REMOTE_HOST" stat -f %Su /dev/console)
  if [[ "$ssh_user" != "$console_user" ]]; then
    echo "WARNUNG: SSH-Benutzer '${ssh_user}' ≠ angemeldeter Benutzer '${console_user}' auf ${REMOTE_HOST}." >&2
    echo "         osascript erreicht MoneyMoney nur in der Sitzung desselben Benutzers." >&2
    echo "         REMOTE_HOST=\"${console_user}@nova-hub\" setzen und SSH-Key dafür einrichten." >&2
  fi
}

check_remote

if [[ "${1:-}" == "--list" ]]; then
  echo "Konten in MoneyMoney auf ${REMOTE_HOST} (Name [UUID]):"
  remote_osascript 'tell application "MoneyMoney" to export accounts' \
    | python3 -c 'import plistlib, sys
data = plistlib.loads(sys.stdin.buffer.read())
items = data if isinstance(data, list) else data.get("accounts", [])
def walk(items, depth=0):
    for it in items:
        ind = int(it.get("indentation", depth))
        uuid = it.get("uuid", "")
        print("  " * ind + "- " + it.get("name", "?") + ("  [" + uuid + "]" if uuid else ""))
        walk(it.get("accounts", []), depth + 1)
walk(items)'
  exit 0
fi

FROM_DATE=$(date -v -"${DAYS}"d +%Y-%m-%d)
TO_DATE=$(date +%Y-%m-%d)
STAMP=$(date +%Y-%m-%d)

mkdir -p "$EXPORT_DIR"

echo "Exportiere Umsätze ${FROM_DATE} bis ${TO_DATE} von ${REMOTE_HOST} ..."

for ACCOUNT in "${ACCOUNTS[@]}"; do
  echo "→ ${ACCOUNT}"
  TMP_FILE=$(remote_osascript "tell application \"MoneyMoney\"
  export transactions from account \"${ACCOUNT}\" from date \"${FROM_DATE}\" to date \"${TO_DATE}\" as \"xls\"
end tell" || true)

  if [[ -z "$TMP_FILE" ]]; then
    echo "  FEHLER: Export für '${ACCOUNT}' fehlgeschlagen (Konto vorhanden? MoneyMoney entsperrt? Automation erlaubt?)" >&2
    continue
  fi

  SAFE_NAME=$(echo "$ACCOUNT" | tr ' /' '__')
  EXT="${TMP_FILE##*.}"
  DEST="${EXPORT_DIR}/Umsaetze_${SAFE_NAME}_${STAMP}.${EXT}"

  scp -q "${REMOTE_HOST}:${TMP_FILE}" "$DEST"
  ssh "$REMOTE_HOST" "rm -f \"${TMP_FILE}\""
  echo "  ✓ ${DEST}"
done

echo "Fertig."
