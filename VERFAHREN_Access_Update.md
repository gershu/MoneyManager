# Verfahren: Zahlungseingänge → Access-Datenbank (Paid Date)

Ziel: MoneyMoney-Umsätze (nova-hub) mit offenen Payments in der Access-DB
(Windows-PC/VM) abgleichen und `Paid Date` setzen.

## Pipeline

```
nova-hub (MoneyMoney)
   │  Export per AppleScript/SSH (bestehendes Script, Format "csv")
   ▼
nova-w1: match_payments.py
   │  liest Umsatz-CSV, ordnet Zahlungen zu (Kundennr./Betrag/Datum)
   │  erzeugt payments_update.csv  (CustNr, PaymentNumber, PaidDate, Amount)
   ▼
Windows (Access)
   CSV in Staging-Tabelle importieren → Update-Abfrage setzt Paid Date
```

## Schritte

1. **Backup**: Kopie der `.mdb`/`.accdb` vor jedem Lauf (Script-Schritt auf Windows-Seite).

2. **Export**: Bestehendes `export_umsaetze.sh` zusätzlich mit Format `"csv"`
   laufen lassen — CSV enthält Buchungsdatum, Betrag, Verwendungszweck, Name.

3. **Matching** (`match_payments.py` auf nova-w1):
   - Offene Payments als CSV aus Access exportieren (oder Sollwerte: monatlich, fester Betrag)
   - Zuordnung: Kundennummer im Verwendungszweck → sonst Name + Betrag + Zeitfenster um Due Date
   - Ausgabe: `payments_update.csv` + Protokoll der nicht zuordenbaren Umsätze (manuelle Prüfung)

4. **Update in Access** (Windows):
   - CSV in Staging-Tabelle `tmp_PaymentUpdates` importieren
   - Update-Abfrage (Beispiel, Feldnamen anpassen):

     ```sql
     UPDATE Payments INNER JOIN tmp_PaymentUpdates U
       ON Payments.PaymentNumber = U.PaymentNumber
     SET Payments.PaidDate = U.PaidDate
     WHERE Payments.PaidDate IS NULL;
     ```

   - Alternativ ohne Handarbeit: Python + `pyodbc` auf dem Windows-Rechner
     (Treiber „Microsoft Access Driver"), per Aufgabenplanung automatisierbar.

5. **Transfer nova-w1 ↔ Windows**: gemeinsamer Ordner (SMB-Freigabe) oder scp,
   falls auf Windows OpenSSH aktiv ist.

## Noch zu klären

- Exakte Tabellen-/Feldnamen der Payments-Tabelle in Access
- Beispiel-Verwendungszweck eines Zahlungseingangs (für die Matching-Regel)
- Währung: Payments in $, Bankumsätze in € — Umrechnung oder Festbetrag?

## Hinweis

DB enthält sensible Echtdaten (SSN, Passwörter, Bankdaten) — Entwicklung/Test
nur mit anonymisierter Kopie; Transferordner zugriffsbeschränkt halten.
