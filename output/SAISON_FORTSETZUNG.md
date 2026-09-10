# Saisonrefactoring – Übergabe

Stand: 10.09.2026, nach Wiederaufnahme. Kein Commit und kein Deployment wurden erstellt.

## Implementiert

- `Models/SeasonCatalog.swift` ist der zentrale, versionierte Katalog: stabile IDs (`bergschein-2026`, `bergschein-2027`), Zeitzone `Europe/Berlin`, explizite Öffnungs-, Ende- und Archivzeitpunkte, Phasen, Badges, Challenges, Rewards, Sponsoren in den Badge-/Reward-Daten und Verlosung mit Preisen. `SeasonCatalog.validate()` prüft IDs, Zeitreihen, doppelte Inhalte, Reward-Verweise und überlappende aktive Saisons; im Debug-Start wird sie per `precondition` ausgeführt.
- `Models/SeasonProgressStore.swift` speichert Fortschritt als JSON-Dictionary nach Saison-ID. Die einmalig markierte, additive Migration übernimmt 2026-Legacy-Badges, Challenges, freigeschaltete/eingelöste Rewards und Verlosung sowie vorhandene 2027-Badge-/Challenge-Werte. Legacy-Keys bleiben erhalten. Der Marker verhindert, dass ein späterer bewusster Reset alte Werte erneut einspielt.
- Badge- und Challenge-Logik (`ContentView+Badges.swift`, `ContentView+Challenges.swift`) verwendet den Store und Katalog. Nur die Phase `active` erlaubt Claims; die 2027-Vorschau kann keine Platzhalter-Claims erzeugen. Archiv-Auswahl verändert keine Aktionen.
- Rewards hängen über `DailyChallenge.rewardID` an Challenges; ihre Einlösefenster und optionale URL liegen in `ChallengeReward`. 2026-Altbelohnungen bleiben auch beim späteren Öffnen der App sichtbar und einlösbar, soweit das konfigurierte Fenster es erlaubt.
- Verlosung in `ContentView+Tabs.swift` liest Preise, Frist, Terms-Version und Teilnahme aus der Saison-/Fortschrittsstruktur. Die globale 2026-Teilnahme wird migriert.
- `AnalyticsService` behält die existierenden API-Payloads unverändert. `seasonID` wird nur im neuen lokalen V2-Offlinequeue geführt; V1-Queues werden einmal übernommen und die V1-Daten nicht gelöscht. Ein `season_id`-Feld wird erst gesendet, wenn das Backend es ausdrücklich unterstützt.
- Projektintegration für `SeasonCatalog.swift` und `SeasonProgressStore.swift` ist in `Bergschein.xcodeproj/project.pbxproj` ergänzt.
- Lokale Notifications verwenden die Saison-ID in ihren Request-IDs, den Kalender der Saison (`Europe/Berlin`) und keine Jahres-Enum-/`Calendar.current`-Ableitungen. Während der Vorschau werden Öffnung sowie nur echte, innerhalb der aktiven Saison liegende Stempel- und Challenge-Termine angelegt; Platzhalter und Vorbereitungs-/Archivphasen erzeugen keine Requests.
- `SeasonProgressStore` überschreibt einen nicht decodierbaren vorhandenen Fortschritts-Blob nicht und setzt den Migrationsmarker erst nach erfolgreicher Persistenz. Reward-IDs werden über alle Saisons validiert. Verlosungsmetriken stammen immer aus dem Fortschritt der Verlosungssaison; die Frist ist exklusiv.
- Der minimale XCTest-Target `BergscheinTests` und `SeasonCatalogTests.swift` sind in Projekt und gemeinsamer Scheme-Testaktion eingebunden. Die Tests decken Zeitgrenzen, leere aktive Zeitfenster, bekannte/unbekannte Jahre, Mitternachts-Challenges, Reward-Fenster, globale Reward-IDs sowie additive 2026-/2027-Migration, beschädigte Persistenz und die V1-Analytics-Kompatibilität ab.

## Offene externe Abhängigkeit

Vor dem produktiven Senden von `season_id` muss der Serververtrag für Analytics, Verlosung und Community abgestimmt werden. Im Workspace liegt kein PHP-/SQL-Backend; die bestehenden Netzwerk-Payloads bleiben daher unverändert. Die lokale V2-Offlinequeue führt die Saison-ID schon getrennt und kann V1-Payloads weiterhin als Saison 2026 decodieren.

## Verifikation am 10.09.2026

- `git diff --check`, `plutil -lint Bergschein.xcodeproj/project.pbxproj` und `xmllint --noout Bergschein.xcodeproj/xcshareddata/xcschemes/Bergschein.xcscheme` erfolgreich.
- Vollständiger Simulator-Build erfolgreich (Xcode 26.6, iOS Simulator 26.5):

  ```sh
  xcodebuild -quiet -project Bergschein.xcodeproj -scheme Bergschein -sdk iphonesimulator -configuration Debug -derivedDataPath /private/tmp/BergscheinSeasonBuild-20260910 build CODE_SIGNING_ALLOWED=NO
  ```

- XCTest erfolgreich auf `Bergschein Jahresauswahl QA` (iPhone 17 Pro, iOS 26.5): 7 bestanden, 0 fehlgeschlagen, 0 übersprungen. Der Ergebnisbericht liegt temporär unter `/private/tmp/BergscheinSeasonTest-20260910/Logs/Test/Test-Bergschein-2026.09.10_17-16-34-+0200.xcresult`.
- Anschließend lief der neu ergänzte, gezielte V1-Queue-Kompatibilitätstest mit 1 bestanden, 0 fehlgeschlagen, 0 übersprungen. Er prüft, dass eine alte Analytics-Payload ohne `season_id` als Saison 2026 decodiert wird und `season_id` beim Senden weiter fehlt. Ergebnis: `/private/tmp/BergscheinSeasonQueueTest-20260910/Logs/Test/Test-Bergschein-2026.09.10_17-19-07-+0200.xcresult`.
- Der vollständige Build fand einen Compilerfehler in der neuen Offlinequeue: `EventPayload` erhielt eine `seasonID`, hatte aber keinen passenden Initialisierer. `Services/AppServices.swift` enthält nun einen expliziten Initialisierer und eine V1-Decodierung mit Saison 2026 als Rückfall. `season_id` wird weiterhin nicht serialisiert und somit nicht an den bestehenden Server gesendet.

## Arbeitsbaum

Der Arbeitsbaum war bereits vor dieser Arbeit stark verändert: u.a. `Helpers/AppDateHelpers.swift`, mehrere Views, `Bergschein.xcodeproj/project.pbxproj`, `PROJEKT_NOTIZEN.md`, `output/` und `CHALLENGES_2027.md`. Diese Änderungen sind nicht zurückzusetzen oder pauschal zu bereinigen. Die hier neu angelegten Kern-Dateien sind `Models/SeasonCatalog.swift`, `Models/SeasonProgressStore.swift` und diese Übergabe.
