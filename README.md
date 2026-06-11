# MoneyManager

Scripts zum Export von MoneyMoney-Umsätzen nach Excel/CSV.

## mmexport.sh — generischer Export (lokal)

Läuft auf dem Rechner, auf dem MoneyMoney installiert ist (nova-hub).
MoneyMoney muss laufen und entsperrt sein.

```
./mmexport.sh -a KONTO [-k KATEGORIE] [-t TEXTFILTER] [-d TAGE] [-f xls|csv] [-o ZIELORDNER]
./mmexport.sh --list
```

| Parameter | Bedeutung | Default |
|---|---|---|
| `-a, --account` | Konto: Name, IBAN oder UUID (Pflicht) | — |
| `-k, --category` | Kategorie, verschachtelt mit `\` (z. B. `"Auto\Tanken"`) | alle |
| `-t, --text` | Textfilter über alle Spalten, case-insensitive | — |
| `-d, --days` | Zeitraum: letzte N Tage | 90 |
| `-f, --format` | `xls` oder `csv` | `xls` |
| `-o, --outdir` | Zielordner | `./exports` |

Beispiele:

```
./mmexport.sh --list
./mmexport.sh -a DIBA
./mmexport.sh -a comdirect -d 30 -f csv
./mmexport.sh -a "1b2c3d4e-..." -k "Wohnen" -f csv -t "Stadtwerke"
```

## export_umsaetze.sh — Remote-Export per SSH (nova-w1 ← nova-hub)

Läuft auf nova-w1, startet den Export per SSH auf nova-hub und holt die
Dateien nach `exports/`. Konfiguration (Konten, Zeitraum, Zielordner) im
Script-Kopf. Konten mit `./export_umsaetze.sh --list` anzeigen.

Einrichtung: SSH-Key (`ssh-copy-id nova-hub`), beim ersten Lauf
Automation-Dialog **auf nova-hub** bestätigen.

## Hinweise

- Bei mehrdeutigen Kontonamen (z. B. "DKB" in mehreren Gruppen) UUID aus `--list` verwenden.
- Textfilter + `xls`: MoneyMoney selbst kann nicht filtern — das Script exportiert intern CSV,
  filtert und schreibt das Ergebnis als `.xlsx`. Benötigt einmalig `pip3 install openpyxl`.
  Zellen sind dabei Text (keine Zahlen-/Datumsformate); ungefiltertes `xls` bleibt nativer MoneyMoney-Export.
- `exports/` enthält Bankdaten und ist per `.gitignore` vom Repo ausgeschlossen.
