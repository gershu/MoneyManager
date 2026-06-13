# MoneyManager

Scripts zum Export von MoneyMoney-Umsätzen nach Excel/CSV.

## mmexport.sh — generischer Export (lokal)

Läuft auf dem Rechner, auf dem MoneyMoney installiert ist.
MoneyMoney muss laufen und entsperrt sein.

```
./mmexport.sh -a KONTO [-k KATEGORIE] [-t TEXTFILTER] [-d TAGE | -s VON [-e BIS]] [-f xls|csv] [-o ZIELORDNER]
./mmexport.sh --list
```

| Parameter | Bedeutung | Default |
|---|---|---|
| `-a, --account` | Konto: Name, IBAN oder UUID (Pflicht) | — |
| `-k, --category` | Kategorie, verschachtelt mit `\` (z. B. `"Auto\Tanken"`) | alle |
| `-t, --text` | Textfilter über alle Spalten, case-insensitive | — |
| `-d, --days` | Zeitraum: letzte N Tage (wird von `-s`/`-e` übersteuert) | 90 |
| `-s, --from` | Startdatum `YYYY-MM-DD`; ohne `-e`: bis heute | — |
| `-e, --to` | Enddatum `YYYY-MM-DD`; ohne `-s`: ab BIS minus `-d` Tage | — |
| `-f, --format` | `xls` oder `csv` | `xls` |
| `-o, --outdir` | Zielordner | `./exports` |

Beispiele:

```
./mmexport.sh --list
./mmexport.sh -a DIBA
./mmexport.sh -a comdirect -d 30 -f csv
./mmexport.sh -a "1b2c3d4e-..." -k "Wohnen" -f csv -t "Stadtwerke"
./mmexport.sh -a DIBA -s 2026-01-01 -e 2026-03-31     # 1. Quartal 2026
./mmexport.sh -a DIBA -s 2026-01-01                   # seit Jahresbeginn
```

## mm_export_pf.sh — Portfolio-Export (lokal)

Exportiert den Wertpapierbestand. MoneyMoney liefert das Portfolio nur als
Property-List; das Script wandelt sie in `.xlsx` (Default, benötigt openpyxl)
oder CSV um. Erste Spalte ist der Depotname, danach alle gelieferten Felder
(gängige zuerst).

```
./mm_export_pf.sh [-a DEPOT] [-f xls|csv|plist] [-o ZIELORDNER]
```

Ohne `-a` wird der gesamte Bestand exportiert (Depotname je Position aus der Plist).
Ausgabe: `exports/Portfolio_<Depot|Alle>_<Datum>.xlsx`
