#!/bin/bash
#
# mm_export_pf.sh — Export des MoneyMoney-Wertpapierbestands (Portfolio)
#
# Läuft auf dem Rechner, auf dem MoneyMoney installiert ist (AppleScript).
# MoneyMoney muss laufen und entsperrt sein.
# MoneyMoney liefert das Portfolio nur als XML-Property-List; das Script
# wandelt sie in xls (.xlsx, Default) oder csv um. Erste Spalte: Depotname.
#
# Nutzung:
#   ./mm_export_pf.sh [-a KONTO] [-f xls|csv|plist] [-o ZIELORDNER]
#
# Parameter:
#   -a, --account   Depot: Name, Nummer oder UUID (optional; ohne Angabe: gesamter Bestand)
#   -f, --format    xls (Default, benötigt openpyxl), csv oder plist (Rohdaten)
#   -o, --outdir    Zielordner (Default: ./exports neben dem Script)
#   -h, --help      diese Hilfe

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ACCOUNT=""
FORMAT="xls"
OUTDIR="${SCRIPT_DIR}/exports"

usage() { awk 'NR>2 && /^#/ { sub(/^# ?/, ""); print; next } NR>2 { exit }' "$0"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -a|--account) ACCOUNT="$2"; shift 2 ;;
    -f|--format)  FORMAT="$2"; shift 2 ;;
    -o|--outdir)  OUTDIR="$2"; shift 2 ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "Unbekannter Parameter: $1" >&2; usage; exit 1 ;;
  esac
done

case "$FORMAT" in
  xls)
    python3 -c 'import openpyxl' 2>/dev/null || {
      echo "FEHLER: Format xls benötigt openpyxl (pip3 install openpyxl) — alternativ -f csv." >&2; exit 1; }
    EXT="xlsx" ;;
  csv)   EXT="csv" ;;
  plist) EXT="plist" ;;
  *) echo "FEHLER: Format muss xls, csv oder plist sein (-f)." >&2; exit 1 ;;
esac

ACCOUNT_CLAUSE=""
[[ -n "$ACCOUNT" ]] && ACCOUNT_CLAUSE=" from account \"${ACCOUNT}\""

mkdir -p "$OUTDIR"
SAFE_NAME=$(echo "${ACCOUNT:-Alle}" | tr ' /' '__')
STAMP=$(date +%Y-%m-%d)
DEST="${OUTDIR}/Portfolio_${SAFE_NAME}_${STAMP}.${EXT}"

echo "Exportiere Portfolio${ACCOUNT:+ '${ACCOUNT}'} als ${FORMAT} ..."

PLIST=$(osascript <<EOF
tell application "MoneyMoney"
  export portfolio${ACCOUNT_CLAUSE} as "plist"
end tell
EOF
)

[[ -n "$PLIST" ]] || { echo "FEHLER: Export fehlgeschlagen (Depot vorhanden? MoneyMoney entsperrt?)" >&2; exit 1; }

if [[ "$FORMAT" == "plist" ]]; then
  printf '%s\n' "$PLIST" > "$DEST"
  echo "✓ ${DEST}"
  exit 0
fi

COUNT=$(printf '%s' "$PLIST" | python3 -c '
import csv, plistlib, sys, datetime

dest, fmt, account = sys.argv[1], sys.argv[2], sys.argv[3]
data = plistlib.loads(sys.stdin.buffer.read())

# Wertpapier-Dicts einsammeln; Depotname aus dem umschließenden Container übernehmen
def collect(node, depot):
    if isinstance(node, list):
        for x in node:
            yield from collect(x, depot)
    elif isinstance(node, dict):
        sublists = [k for k in ("securities", "portfolio", "accounts") if isinstance(node.get(k), list)]
        if sublists:
            d = node.get("name", depot)
            for k in sublists:
                yield from collect(node[k], d)
        else:
            yield depot, node

def cell(v):
    if isinstance(v, datetime.datetime):
        return v.strftime("%Y-%m-%d")
    if isinstance(v, bool):
        return "ja" if v else "nein"
    if isinstance(v, (list, dict, bytes)):
        return ""
    return v

rows = list(collect(data, account))
if not rows:
    sys.exit("Keine Wertpapiere im Export gefunden.")

# Spalten: Depot zuerst, dann Union aller Felder (gängige zuerst)
preferred = ["name", "isin", "securityNumber", "quantity", "price",
             "currencyOfPrice", "amount", "currencyOfAmount",
             "purchasePrice", "currencyOfPurchasePrice", "tradeTimestamp"]
keys = sorted({k for _, r in rows for k in r}, key=lambda k: (preferred.index(k) if k in preferred else 99, k))
header = ["depot"] + keys

if fmt == "csv":
    with open(dest, "w", newline="") as f:
        w = csv.writer(f, delimiter=";")
        w.writerow(header)
        for depot, r in rows:
            w.writerow([depot] + [cell(r.get(k, "")) for k in keys])
else:
    import openpyxl
    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Portfolio"
    ws.append(header)
    for depot, r in rows:
        ws.append([depot] + [cell(r.get(k, "")) for k in keys])
    wb.save(dest)

print(len(rows))
' "$DEST" "$FORMAT" "${ACCOUNT}" )

[[ "$COUNT" =~ ^[0-9]+$ ]] || { echo "FEHLER: ${COUNT}" >&2; rm -f "$DEST"; exit 1; }
echo "✓ ${DEST} (${COUNT} Positionen)"
