#!/bin/bash
#
# mm_export_pf.sh — Export des MoneyMoney-Wertpapierbestands (Portfolio)
#
# Läuft auf dem Rechner, auf dem MoneyMoney installiert ist (AppleScript).
# MoneyMoney muss laufen und entsperrt sein.
# MoneyMoney liefert das Portfolio nur als XML-Property-List; das Script
# wandelt sie standardmäßig in eine CSV-Datei um (Spalten = alle Felder).
#
# Nutzung:
#   ./mm_export_pf.sh [-a KONTO] [-f csv|plist] [-o ZIELORDNER]
#
# Parameter:
#   -a, --account   Depot: Name, Nummer oder UUID (optional; ohne Angabe: gesamter Bestand)
#   -f, --format    csv (Default) oder plist (Rohdaten)
#   -o, --outdir    Zielordner (Default: ./exports neben dem Script)
#   -h, --help      diese Hilfe

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

ACCOUNT=""
FORMAT="csv"
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

if [[ "$FORMAT" != "csv" && "$FORMAT" != "plist" ]]; then
  echo "FEHLER: Format muss csv oder plist sein (-f)." >&2; exit 1
fi

ACCOUNT_CLAUSE=""
[[ -n "$ACCOUNT" ]] && ACCOUNT_CLAUSE=" from account \"${ACCOUNT}\""

mkdir -p "$OUTDIR"
SAFE_NAME=$(echo "${ACCOUNT:-Alle}" | tr ' /' '__')
STAMP=$(date +%Y-%m-%d)
DEST="${OUTDIR}/Portfolio_${SAFE_NAME}_${STAMP}.${FORMAT}"

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

data = plistlib.loads(sys.stdin.buffer.read())

# Wertpapier-Dicts einsammeln (Container-Knoten mit Unterlisten überspringen)
def collect(node):
    if isinstance(node, list):
        for x in node:
            yield from collect(x)
    elif isinstance(node, dict):
        sublists = [k for k in ("securities", "portfolio", "accounts") if isinstance(node.get(k), list)]
        if sublists:
            for k in sublists:
                yield from collect(node[k])
        else:
            yield node

def fmt(v):
    if isinstance(v, datetime.datetime):
        return v.strftime("%Y-%m-%d")
    if isinstance(v, bool):
        return "ja" if v else "nein"
    if isinstance(v, (list, dict, bytes)):
        return ""
    return v

rows = list(collect(data))
if not rows:
    sys.exit("Keine Wertpapiere im Export gefunden.")

# Spalten: Union aller Felder, gängige zuerst
preferred = ["name", "isin", "securityNumber", "quantity", "price",
             "currencyOfPrice", "amount", "currencyOfAmount",
             "purchasePrice", "currencyOfPurchasePrice", "tradeTimestamp"]
keys = sorted({k for r in rows for k in r}, key=lambda k: (preferred.index(k) if k in preferred else 99, k))

w = csv.writer(sys.stdout, delimiter=";")
w.writerow(keys)
for r in rows:
    w.writerow([fmt(r.get(k, "")) for k in keys])
print(len(rows), file=sys.stderr)
' 2>&1 >"$DEST" )

[[ "$COUNT" =~ ^[0-9]+$ ]] || { echo "FEHLER: ${COUNT}" >&2; rm -f "$DEST"; exit 1; }
echo "✓ ${DEST} (${COUNT} Positionen)"
