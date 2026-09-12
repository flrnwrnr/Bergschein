# Saison-Erweiterung – am 11.09.2026 live eingespielt

Upload-Dateien: track.php und community.php. config.php unverändert lassen.
Keine Accounts, keine neue Datenbank, kein Challenge-Vergleich.

## Vertrag

POST track.php: optionales JSON-Feld season_id.
GET community.php: optionaler Queryparameter season_id.
Fehlend (auch JSON null) bedeutet fest bergschein-2026, niemals aktuelles Jahr.
Zulässig: bergschein-2026, bergschein-2027, test-bergschein-2026,
test-bergschein-2027. Andere Werte werden mit HTTP 422 abgewiesen.
Die bisherigen Antwortfelder und max_checkins bleiben erhalten.
Neue Saisons künftig in beiden PHP-Allowlisten ergänzen.

## Einspielen auf ALL-INKL

1. analytics_events mit Struktur UND Daten exportieren; bisherige PHP-Dateien sichern.
2. Während der Migration keine App-Tests/Uploads starten. Bestand erneut prüfen:

```sql
SELECT YEAR(event_time), COUNT(*) FROM analytics_events GROUP BY YEAR(event_time);
SELECT id, event_time FROM analytics_events
WHERE event_time >= '2027-05-13 15:00:00'
  AND event_time <= '2027-05-14 15:17:00';
```

Erwartet: 404 Ereignisse 2026 und genau vier bestätigte Testereignisse mit den
IDs 572, 573, 574 und 575 im angegebenen Intervall. Bei Abweichung Migration
vorher überprüfen. Das UPDATE verlangt sowohl diese exakten IDs als auch das
Zeitfenster. Dadurch werden später hinzugekommene, zeitlich passende Ereignisse
nicht versehentlich als Testdaten umgeordnet.
3. migrations/001_seasons.sql einmalig über phpMyAdmin ausführen.
   DDL ist nicht durch ROLLBACK rückgängig zu machen. Keine Zeilen werden gelöscht.
4. Ergebnis prüfen: bergschein-2026 = 404, test-bergschein-2027 = 4,
   bergschein-2027 noch ohne Ereignisse (sofern Bestand unverändert).
5. track.php und community.php hochladen. Die vorhandene config.php nicht ersetzen.
6. Mit bestehendem App-Token lokal prüfen: GET ohne Saison liefert 2026,
   explizites 2026 dieselbe Verteilung, 2027 eine leere Verteilung,
   test-bergschein-2027 die Testverteilung, unbekannte Saison HTTP 422.
   Token nicht in Screenshots, Shell-History oder Dokumentation ablegen.
7. Erst danach die App-Saisonanbindung aktivieren.

Die alten PHP-Dateien funktionieren auch mit der erweiterten Tabelle weiter
(DEFAULT 2026). Ein Rückwechsel zur alten community.php hebt allerdings die
Saisonfilterung wieder auf und würde Testdaten mit auswerten.

## Testmodus der App

Die App sendet bei simulierten Check-ins ausdrücklich test-bergschein-YYYY,
bei regulären Ereignissen bergschein-YYYY. Dieselbe Kennung beim Community-Abruf
verwenden. Beim Erzeugen eines Offline-Ereignisses festhalten und beim späteren
Versand beibehalten, auch wenn inzwischen der Testmodus gewechselt wurde.
Bereits vorhandene Offline-Testereignisse vor dem ersten Versand prüfen; sie
enthalten bisher möglicherweise keine Unterscheidung zum Produktivmodus.
Keine automatische Erkennung anhand zukünftiger Daten oder allein des Debug-Builds.
Dies ist eine logische Datentrennung auf demselben Backend, kein eigener Testserver.
Die App-Anbindung und die Migration vorhandener Vorab-Testdaten sind umgesetzt.

## Validierung

PHP-Syntax, Saisonvalidierung und Datenbankmigration wurden lokal geprüft. Die
Live-Migration und der Upload beider PHP-Dateien wurden am 11.09.2026 bestätigt.
Die alte App zeigte danach weiterhin die 2026-Verteilung. Explizite Saisonabfragen
aus dem neuen App-Build sind noch manuell auf einem Gerät zu prüfen.
Auch kpis.php/draw.php sind nicht angepasst: deren mögliche saisonübergreifende
Auswertungen vor einer späteren Nutzung separat prüfen.
