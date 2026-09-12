# Bergschein – Jahreswechsel 2026 → 2027

Diese Liste dient als gemeinsame Erinnerungs- und Planungsgrundlage für die Saison 2027.

## Erforderlich

- [ ] **Badges für 2027 erneuern**
  - Neue Stempel-/Badge-Motive erstellen und hinterlegen.
  - Nicht die gleichen Badges wie 2026 erneut anzeigen.
  - Prüfen, ob Badge-IDs, Saison-Zuordnung und Bild-Assets angepasst werden müssen.

- [ ] **Neue Challenges definieren**
  - Ideensammlung für die 12 Challenges: [CHALLENGES_2027.md](CHALLENGES_2027.md) (bisher fünf Favoriten, sieben Plätze offen).
  - Für jede Challenge eine neue Idee, Zielbedingung, Beschreibung und gegebenenfalls Belohnung festlegen.
  - Challenges anschließend in der App und den zugehörigen Daten/API-Konfigurationen hinterlegen.

- [ ] **Highscore und Community-Sicht überprüfen**
  - Entscheiden, ob Darstellung, Regeln oder Inhalte überarbeitet werden sollen.
  - Daten von 2026 erhalten; neue Saison über `season_id` getrennt auswerten.
  - Backend-Paket und Migration live eingespielt: [Migration und Anleitung](output/backend-season/README.md).
  - Alte Apps ohne Saisonkennung bleiben fest bei 2026. Zunächst nur Stempelvergleich.

- [ ] **Testmodus im Backend getrennt erfassen (verbindlich vereinbart)**
  - Testmodus sendet `test-bergschein-YYYY`, regulärer Betrieb `bergschein-YYYY`; auch beim Community-Abruf.
  - Kennung bereits beim Erzeugen von Offline-Ereignissen festhalten, nicht erst beim Versand bestimmen.
  - Bestehende Offline-Testereignisse vor Aktivierung prüfen.
  - Vier bestätigte Server-Testereignisse von Mai 2027 separat erhalten; 404 Ereignisse aus 2026 bleiben regulär.
  - Keine automatische Testerkennung anhand des Datums. Kein separater Testserver erforderlich.

- [ ] **Verlosung für 2027 vorbereiten**
  - Neue Preise auswählen und in der App hinterlegen.
  - Die bestehende Verlosungsmechanik kann voraussichtlich unverändert bleiben.

## Optional – sinnvolle Ergänzungen

- [ ] Saisonwechsel als eigenen Testfall prüfen: neue Saison, leere Rangliste, neue Challenges, neue Badges und Verlosungspreise.
- [ ] Alte 2026-Daten archivieren, bevor Highscore- oder Community-Daten zurückgesetzt werden.
- [ ] Einen klaren Stichtag und eine kommunikative Ankündigung für den Wechsel zu 2027 festlegen.
- [ ] Prüfen, ob ein kurzer Jahresrückblick für 2026 oder ein Startbildschirm für 2027 sinnvoll ist.
- [ ] Die Datenstruktur so vorbereiten, dass künftige Saisonwechsel möglichst über Konfiguration statt Code-Anpassungen erfolgen.

## Community / Backend (Stand 11.09.2026)

Die Sicherung und das Live-Einspielen sind abgeschlossen:
1. SQL-Daten sowie die zuvor gehosteten `track.php` und `community.php` wurden gesichert.
2. Der geprüfte Export enthält 404
   reguläre Ereignisse 2026 und die vier bestätigten Testereignisse vom
   13.–14.05.2027. Import und vorbereitete Migration wurden mit diesem Backup
   lokal unter MariaDB 10.6.28 erfolgreich geprüft.
3. Migration und PHP-Paket wurden anschließend live eingespielt. Die alte App zeigte
   danach weiterhin die 2026-Verteilung.

Vorbereitetes Paket: `output/backend-season/` mit `track.php`, `community.php`, `migrations/001_seasons.sql`, `README.md`, `TEST_REPORT.md`, `verify_migration.sql` und `test_seasons.py`.
Prüfung: beide PHP-Syntaxprüfungen und 16 Saisonvalidierungen erfolgreich; lokale MariaDB-Migration mit dem vollständigen Backup erfolgreich und alle ursprünglichen Werte der 408 Zeilen erhalten. Die gehärtete Migration ergab auf einem frischen Import erneut 404/4, und alle elf SQL-Kompatibilitätsprüfungen bestanden. Die Live-Migration und der PHP-Upload wurden bestätigt; explizite Saisonabfragen aus dem neuen App-Build sind noch manuell zu prüfen.

### Danach: Umsetzung in dieser Reihenfolge

4. Live-Kompatibilität prüfen: alte Anfragen ohne Saisonkennung liefern fest 2026; explizite 2027-Abfrage startet leer; Testdaten bleiben separat.
5. App-Anbindung umsetzen: Saisonkennung bei Tracking und Community-Abruf übertragen. Testmodus ausdrücklich mit `test-bergschein-YYYY` kennzeichnen, Produktion mit `bergschein-YYYY`. Kennung bereits bei Ereigniserzeugung dauerhaft in der Offline-Queue speichern; vorhandene Offline-Testdaten und Decoder/Migration prüfen. Keine Ableitung des Testmodus allein aus Datum oder Debug-Build.
6. Community-UI nur für Stempel überarbeiten: eigener Stand und Anteile mit weniger, gleich vielen und mehr Stempeln; Rangnummern entfernen. Berechnungen außerhalb der View testen. Bisherige Darstellung wurde noch nicht geändert.
7. Details vor UI-Umsetzung abschließend festlegen: Mindestteilnahme (20 bisher nur Vorschlag), Darstellung ohne eigenen Stempel, Rundung und leere/fehlerhafte/offline Zustände. Vergleichsbasis: Installationen mit mindestens einem gemeldeten Stempel derselben Saison; keine öffentliche Teilnehmerzahl.
8. App-Build und passende XCTest-Prüfungen ausführen: Saisontrennung, Gleichstände, Prozentwerte, Offline-Versand nach Testmoduswechsel und alte Daten. Tatsächliches Scheme/Simulator prüfen (AGENTS.md nennt AppList/iPhone 16).

Weiterhin ausgeschlossen: Challenge-Vergleich, Accounts, Spitznamen, Freundesgruppen und gemeinsame Saisonziele. Erreichte Community-Meilensteine sind nur eine mögliche spätere Erweiterung, nicht beauftragt. Keine Veröffentlichung der App ohne gesonderten Auftrag.

### Live-Fortschritt: Datenbankmigration bestätigt

Der Nutzer hat die Migration in phpMyAdmin ausgeführt und per Screenshot bestätigt:
ALTER TABLE erfolgreich, UPDATE genau vier Datensätze; Ergebnis bergschein-2026 = 404,
test-bergschein-2027 = 4. Migration NICHT erneut ausführen.
SQL- und bisherige PHP-Sicherungen liegen im Backend-Ordner unter backup/.
Nächster Schritt: vorbereitete output/backend-season/track.php und community.php
auf dem Webhosting ersetzen; Upload noch nicht bestätigt. Anschließend Endpunkte
auf alte Anfragen und explizite Saison-/Testkennung prüfen, dann App-Anbindung.
Diese Bestätigung ersetzt frühere Hinweise, dass die Live-Datenbank unverändert sei.

### Live-Fortschritt: PHP-Upload vom Nutzer bestätigt

Der Nutzer bestätigt den Upload der vorbereiteten track.php und community.php.
Datenbankmigration bereits per Screenshot bestätigt (404 reguläre / 4 Testereignisse).
Noch offen: authentifizierter Live-Test der Community-Abfrage ohne Saisonkennung,
mit 2026, mit 2027 und mit Testkennung; danach App-Saison-/Testmodus-Anbindung.

### App-Anbindung Saison/Testmodus umgesetzt (11.09.2026)

- Tracking und Community-Abruf übertragen dieselbe explizite Saisonkennung.
- Lokaler Fortschritt im Testmodus liegt getrennt unter test-bergschein-YYYY.
- Vorhandener, vom Nutzer bestätigter 2027-Vorab-Testfortschritt wird einmalig dorthin verschoben; die regulären 2026-Daten bleiben erhalten.
- Offline-V1 der veröffentlichten 2026-App bleibt 2026. Alte V2-Ereignisse der 2027-Vorabtests werden einmalig der Testkennung zugeordnet. Neue Ereignisse behalten ihre beim Sammeln festgelegte Kennung auch nach Moduswechsel. Nicht zuordenbare V2-Einträge bleiben lokal erhalten und werden nicht hochgeladen.
- Gemeinsamer AnalyticsService und Schutz der Warteschlange gegen überlappende Uploads/neue Einträge.
- Community zeigt standardmäßig dieselbe Saison wie der lokale Stand. Im Testmodus gibt es die ausdrücklich beschriftete Option „Vergleich mit 2026-Daten“ als reine Darstellungsvorschau.
- Der bestehende übergreifende Testmodus (simuliertes Datum, Testregion oder Banner-Override) bestimmt die Testzuordnung. Kein Ableiten allein aus Debug-Build oder Ereignisdatum.
- Backend für diesen App-Schritt nicht erneut verändert. Keine Projekt-/Signing-Dateien verändert.

Nächste manuelle Prüfung auf dem Gerät nach Installation dieses Builds: Testmodus aktivieren, erhaltene Teststempel und Test-Community prüfen, 2026-Vorschau ein-/ausschalten, Testmodus verlassen und getrennten regulären Stand prüfen. Live-Testabfragen mit expliziter Kennung aus dem neuen Build stehen noch aus.
Danach folgt separat die besprochene neue Darstellung „weniger / gleich viele / mehr Stempel“; die Rangdarstellung ist in diesem Integrationsschritt noch erhalten. Mindestteilnahme und Rundungsregeln vor diesem UI-Schritt festlegen.

Validierung des finalen App-Stands: Build erfolgreich; vollständiger XCTest-Lauf erfolgreich mit 32 Tests, 0 Fehlern. Tatsächlich verwendetes Scheme: Bergschein; Simulator: iPhone 17 Pro (iOS 26.5), da AppList/iPhone 16 hier nicht vorhanden sind. Ergebnisbundle: /tmp/bergschein-season-tests-final.xcresult. Keine neuen Swift-Compilerwarnungen beobachtet; Xcode meldet lediglich übersprungene AppIntents-Metadatenextraktion mangels Framework-Abhängigkeit. git diff --check sauber. Kein Commit, kein App-Release.
