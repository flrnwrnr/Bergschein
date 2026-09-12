# Lokaler Migrationstest

Testumgebung: MariaDB 10.6.28, lokale Datenbankkopie ohne Verbindung zum
Produktivsystem.

## Bestanden

- Das vollständige SQL-Backup ließ sich importieren.
- `migrations/001_seasons.sql` ließ sich auf dem importierten Bestand ausführen.
- Danach waren 404 Ereignisse `bergschein-2026` und vier Ereignisse
  `test-bergschein-2027` zugeordnet.
- Ein Vergleich mit einer unveränderten Kopie vor der Migration bestätigte,
  dass alle ursprünglichen Werte aller 408 Zeilen erhalten blieben. Geändert
  wurde ausschließlich die beabsichtigte Saisonzuordnung der vier Testzeilen;
  die neue Spalte und der neue Eindeutigkeitsindex kamen hinzu.
- Ein frischer Import mit der gehärteten Migration ergab erneut die erwartete
  Aufteilung von 404 und vier Ereignissen.
- Alle elf Prüfungen in `verify_migration.sql` bestanden. Dazu gehören der
  Legacy-Default, getrennte gleiche Ereignisschlüssel über Saisons hinweg, das
  Upsert innerhalb derselben Saison und der vollständige Rollback der
  synthetischen Testzeilen.
- Beide PHP-Dateien bestanden die Syntaxprüfung; alle 16 lokalen Prüfungen der
  Saisonvalidierung bestanden.

## Noch offen

- Eine vollständige HTTP-/PHP-/Datenbankintegration wurde noch nicht ausgeführt.
