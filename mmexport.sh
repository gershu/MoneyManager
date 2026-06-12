#!/bin/bash
#
# mmexport.sh — generischer Export von MoneyMoney-Umsätzen (lokale Maschine)
#
# Läuft auf dem Rechner, auf dem MoneyMoney installiert ist (AppleScript).
# MoneyMoney muss laufen und entsperrt sein.
#
# Nutzung:
#   ./mmexport.sh -a KONTO [-k KATEGORIE] [-t TEXTFILTER] [-d TAGE | -s VON [-e BIS]] [-f xls|csv] [-o ZIELORDNER]
#   ./mmexport.sh --list        Konten (Name [UUID]) anzeigen
#
# Parameter:
#   -a, --account   Konto: Name, IBAN oder UUID (Pflicht; bei mehrdeutigen Namen UUID nutzen)
#   -k, --category  Kategorie (optional; verschachtelt mit \ trennen, z. B. "Auto\Tanken")
#   -t, --text      Textfilter (optional; case-insensitive über alle Spalten;
#                   bei xls wird intern csv exportiert und als .xlsx geschrieben → benötigt openpyxl)
#   -d, --days      Zeitraum: letzte N Tage (Default: 90; wird von -s/-e übersteuert)
#   -s, --from      Startdatum YYYY-MM-DD (optional; ohne -e: bis heute)
#   -e, --to        Enddatum YYYY-MM-DD (optional; ohne -s: ab BIS minus -d Tage)
#   -f, --format    xls (Default) oder csv
#   -o, --outdir    Zielordner (Default: ./exports neben dem Script)
#   -l, --list      verfügbare Konten anzeigen
#   -h, --help      diese Hilfe

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ACCOUNT=""
CATEGORY=""
TEXTFILTER=""
DAYS=90
FROM=""
TO=""
FORMAT="xls"
OUTDIR="${SCRIPT_DIR}/exports"
DO_LIST=0

usage() { awk 'NR>2 && /^#/ { sub(/^# ?/, ""); print; next } NR>2 { exit }' "$0"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--account)  ACCOUNT="$2"; shift 2 ;;
    -k|--category) CATEGORY="$2"; shift 2 ;;
    -t|--text)     TEXTFILTER="$2"; shift 2 ;;
    -d|--days)     DAYS="$2"; shift 2 ;;
    -s|--from)     FROM="$2"; shift 2 ;;
    -e|--to)       TO="$2"; shift 2 ;;
    -f|--format)   FORMAT="$2"; shift 2 ;;
    -o|--outdir)   OUTDIR="$2"; shift 2 ;;
    -l|--list)     DO_LIST=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *) echo "Unbekannter Parameter: $1" >&2; usage; exit 1 ;;
  esac
done

if (( DO_LIST )); then
  echo "Konten in MoneyMoney (Name [UUID]):"
  osascript -e 'tell application "MoneyMoney" to export accounts' \
    | plutil -convert json -o - - \
    | python3 -c 'import json,sys
def walk(items, depth=0):
    for it in items:
        uuid = it.get("uuid", "")
        print("  " * depth + "- " + it.get("name", "?") + ("  [" + uuid + "]" if uuid else ""))
        walk(it.get("accounts", []), depth + 1)
walk(json.load(sys.stdin))'
  exit 0
fi

[[ -n "$ACCOUNT" ]] || { echo "FEHLER: Konto fehlt (-a). Konten anzeigen: --list" >&2; exit 1; }

if [[ "$FORMAT" != "xls" && "$FORMAT" != "csv" ]]; then
  echo "FEHLER: Format muss xls oder csv sein (-f)." >&2; exit 1
fi

# MoneyMoney kennt keinen Textfilter — gefiltert wird nach dem Export.
# Bei xls: intern csv exportieren, filtern, als .xlsx schreiben (openpyxl nötig).
EXPORT_FORMAT="$FORMAT"
if [[ -n "$TEXTFILTER" && "$FORMAT" == "xls" ]]; then
  python3 -c 'import openpyxl' 2>/dev/null || {
    echo "FEHLER: Textfilter mit xls benötigt openpyxl (pip3 install openpyxl) — alternativ -f csv." >&2; exit 1; }
  EXPORT_FORMAT="csv"
fi

[[ "$DAYS" =~ ^[0-9]+$ ]] || { echo "FEHLER: -d erwartet eine Zahl (Tage)." >&2; exit 1; }

# Datum validieren (Format + Kalender-Plausibilität, BSD-date)
valid_date() {
  [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] \
    && [[ "$(date -j -f "%Y-%m-%d" "$1" +%Y-%m-%d 2>/dev/null)" == "$1" ]]
}

if [[ -n "$FROM" || -n "$TO" ]]; then
  [[ -z "$TO" ]] && TO=$(date +%Y-%m-%d)
  for D in "$FROM" "$TO"; do
    [[ -z "$D" ]] || valid_date "$D" || { echo "FEHLER: Ungültiges Datum '$D' (erwartet YYYY-MM-DD)." >&2; exit 1; }
  done
  [[ -z "$FROM" ]] && FROM=$(date -j -v -"${DAYS}"d -f "%Y-%m-%d" "$TO" +%Y-%m-%d)
  [[ "$FROM" > "$TO" ]] && { echo "FEHLER: VON (${FROM}) liegt nach BIS (${TO})." >&2; exit 1; }
  FROM_DATE="$FROM"
  TO_DATE="$TO"
else
  FROM_DATE=$(date -v -"${DAYS}"d +%Y-%m-%d)
  TO_DATE=$(date +%Y-%m-%d)
fi

CATEGORY_CLAUSE=""
# Backslash (Trenner verschachtelter Kategorien) für AppleScript-String verdoppeln
[[ -n "$CATEGORY" ]] && CATEGORY_CLAUSE=" from category \"${CATEGORY//\\/\\\\}\""

echo "Exportiere '${ACCOUNT}'${CATEGORY:+ (Kategorie: ${CATEGORY})} ${FROM_DATE} bis ${TO_DATE} als ${FORMAT} ..."

TMP_FILE=$(osascript <<EOF
tell application "MoneyMoney"
  export transactions from account "${ACCOUNT}"${CATEGORY_CLAUSE} from date "${FROM_DATE}" to date "${TO_DATE}" as "${EXPORT_FORMAT}"
end tell
EOF
)

[[ -n "$TMP_FILE" && -f "$TMP_FILE" ]] || { echo "FEHLER: Export fehlgeschlagen (Konto vorhanden? MoneyMoney entsperrt?)" >&2; exit 1; }

mkdir -p "$OUTDIR"
SAFE_NAME=$(echo "$ACCOUNT" | tr ' /' '__')
EXT="${TMP_FILE##*.}"
DEST="${OUTDIR}/Umsaetze_${SAFE_NAME}_${FROM_DATE}_${TO_DATE}.${EXT}"

if [[ -n "$TEXTFILTER" && "$FORMAT" == "xls" ]]; then
  # CSV filtern und als .xlsx schreiben
  DEST="${OUTDIR}/Umsaetze_${SAFE_NAME}_${FROM_DATE}_${TO_DATE}.xlsx"
  COUNT=$(python3 - "$TMP_FILE" "$DEST" "$TEXTFILTER" <<'PYEOF'
import csv, sys
import openpyxl
src, dst, needle = sys.argv[1], sys.argv[2], sys.argv[3].lower()
try:
    text = open(src, newline="", encoding="utf-8-sig").read()
except UnicodeDecodeError:
    text = open(src, newline="", encoding="latin-1").read()
rows = list(csv.reader(text.splitlines(), delimiter=";"))
wb = openpyxl.Workbook(); ws = wb.active; ws.title = "Umsätze"
ws.append(rows[0])
n = 0
for r in rows[1:]:
    if needle in ";".join(r).lower():
        ws.append(r); n += 1
wb.save(dst); print(n)
PYEOF
  )
  rm -f "$TMP_FILE"
  echo "✓ ${DEST} (${COUNT} Umsätze nach Filter '${TEXTFILTER}')"
elif [[ -n "$TEXTFILTER" ]]; then
  # Headerzeile behalten, restliche Zeilen case-insensitive filtern
  { head -n 1 "$TMP_FILE"; tail -n +2 "$TMP_FILE" | grep -i -- "$TEXTFILTER" || true; } > "$DEST"
  rm -f "$TMP_FILE"
  COUNT=$(( $(wc -l < "$DEST") - 1 ))
  echo "✓ ${DEST} (${COUNT} Umsätze nach Filter '${TEXTFILTER}')"
else
  mv "$TMP_FILE" "$DEST"
  echo "✓ ${DEST}"
fi
