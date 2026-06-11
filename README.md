# MoneyMoneyExport

Generisches Script zum Export von MoneyMoney-Umsätzen auf der lokalen Maschine
(AppleScript — MoneyMoney muss laufen und entsperrt sein).

## Nutzung

```
./mmexport.sh -a KONTO [-k KATEGORIE] [-t TEXTFILTER] [-d TAGE] [-f xls|csv] [-o ZIELORDNER]
./mmexport.sh --list
```

| Parameter | Bedeutung | Default |
|---|---|---|
| `-a, --account` | Konto: Name, IBAN oder UUID (Pflicht) | — |
| `-k, --category` | Kategorie, verschachtelt mit `\` (z. B. `"Auto\Tanken"`) | alle |
| `-t, --text` | Textfilter über alle Spalten, case-insensitive (nur `csv`) | — |
| `-d, --days` | Zeitraum: letzte N Tage | 90 |
| `-f, --format` | `xls` oder `csv` | `xls` |
| `-o, --outdir` | Zielordner | `./exports` |

## Beispiele

```
./mmexport.sh --list
./mmexport.sh -a DIBA
./mmexport.sh -a comdirect -d 30 -f csv
./mmexport.sh -a "1b2c3d4e-..." -k "Wohnen" -f csv -t "Stadtwerke"
```

Ausgabe: `exports/Umsaetze_<Konto>_<von>_<bis>.<ext>`

## Hinweise

- Bei mehrdeutigen Kontonamen (z. B. "DKB" in mehreren Gruppen) UUID aus `--list` verwenden.
- Beim ersten Lauf den macOS-Automation-Dialog bestätigen.
- Remote-Ausführung (z. B. von einem anderen Mac): `ssh user@host 'cd repo && ./mmexport.sh ...'`
