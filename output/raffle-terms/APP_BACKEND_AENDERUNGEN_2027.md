# Verlosung 2027 – Änderungen für eine separate Umsetzungssitzung

Stand: 15.09.2026. Zentrale Sammlung aus der gemeinsamen Prüfung der [Teilnahmebedingungen](teilnahmebedingungen-2027-entwurf.md). Aufgaben sind offen, soweit nicht ausdrücklich ein lokaler Umsetzungsstand genannt ist. App- und Backend-Änderungen bleiben lokale Arbeitskopien; keine Veröffentlichung oder Freigabe.

Die Bedingungen sind weiterhin ein Entwurf. Diese Liste ist keine Freigabe zur Veröffentlichung, Aktivierung oder zum Deployment. Der Live-Stand wurde für diese Sammlung nicht geprüft; technische Aussagen beziehen sich auf den lokalen Workspace. Vorhandene Änderungen im Arbeitsbaum erhalten. Bei späterer Umsetzung die dann aktuellen AGENTS.md-Regeln beachten, insbesondere keine Änderungen an Projekt-, Signing- oder Bundle-Einstellungen ohne entsprechende Autorisierung.

Der [Abschlussvermerk](ABSCHLUSS_2027.md) dokumentiert die Bewertung, die im Abschlussdurchgang konkretisierten Verfahren und die verbleibenden Freigabevoraussetzungen. Die nachstehenden Zielvorgaben beziehen sich auf die konsolidierten Bedingungen.

## Verbindlich besprochene Regeln

- Anmeldung: 29.04.2027 00:00 Uhr inklusive bis 31.05.2027 23:00 Uhr exklusiv, Europe/Berlin.
- Bergtage: 13.–24.05.2027. Aktiver Check-in erforderlich, maximal ein gültiger Tagesstempel pro Person und Bergtag; gültige Stempel vor der Verlosungsanmeldung zählen.
- Regulärer Servereingang für Offline-Stempel: vor 31.05.2027 23:00 Uhr. Erstmalige Ziehung danach innerhalb von sieben Kalendertagen, spätestens 07.06.2027. Nach beschlossener Störungsverlängerung entsprechend später; Ersatzvergaben gesondert.
- Mindestens ein gültiger Tagesstempel. Gruppen absteigend nach Stempelzahl, innerhalb gleicher Stempelzahl per Los. Ein Preis pro Person. Erst nach Ausschöpfen einer Gruppe zur vorhandenen nächstniedrigeren Gruppe wechseln.
- Preise nacheinander in vorher bekanntgegebener Reihenfolge; konkrete Preise, Anzahl und Reihenfolge noch offen. Keine Barauszahlung oder Umtausch. Ohne weitere berechtigte Personen bleiben Preise unvergeben.
- Benachrichtigung ausschließlich per E-Mail; 14 Kalendertage nach Zugang zur Rückmeldung, konkretes Fristende und Verfallsfolge in der Nachricht. Ersatzgewinner aus der höchsten verbleibenden Gruppe bisher nicht mit einem Preis berücksichtigter Personen. Andere Zuteilungen bleiben bestehen; Ablehnende und Personen mit abgelaufener Rückmeldefrist erhalten keinen weiteren Preis.
- Ab 18 Jahren, Wohnsitz Deutschland; Ausschlusskreis nach § 4 Absatz 2. Altersbestätigung bei Anmeldung, geeigneter Altersnachweis im Gewinnfall nur bei begründeten Zweifeln.
- Keine Werbung, Newsletter oder Weitergabe der Kontaktdaten zu solchen Zwecken. **Kein Namensfeld mehr bei der Anmeldung, auch nicht optional.** Name erst im Gewinnfall, soweit für Abwicklung oder die vorgesehene Prüfung erforderlich.
- Nachgewiesene App-/Serverstörungen: nachvollziehbarer Bezug zum betroffenen Check-in, einheitliche Korrektur oder erforderliche Fristverlängerung. Keine automatische Anerkennung bloßer Behauptungen oder vergessener Check-ins.

## A01 – Namensfeld und zugehörige Datenverarbeitung entfernen

**Beschlossen.** Der 2027-Anmeldepfad wurde lokal angepasst: kein Namensfeld, keine Vorbelegung, kein Name im JSON-Payload oder neuen lokalen 2027-Fortschritt. Das Backend setzt auch von älteren Clients eingesandte 2027-Namen auf `NULL`; die 2027-Ziehungsabfrage enthält keinen Namen. Der historische 2026-Pfad und seine Migration bleiben erhalten. Die Änderung ist weder live geprüft noch veröffentlicht.

- [x] Feld im 2027-Formular ausblenden und keine alten Namen vorbefüllen. Der gemeinsame SwiftUI-Zustand bleibt für 2026-Kompatibilität bestehen.
- [x] Namen aus neuen 2027-Anmelderequests und lokalem 2027-Fortschritt fernhalten; Backend speichert auch bei älteren/manipulierten Clients für 2027 keinen Namen.
- [x] Namen aus 2027-Ziehungsabfragen und Antworten entfernen; erforderliche spätere Gewinnabwicklungsdaten weiterhin getrennt behandeln.
- [ ] Kompatiblen Umgang mit älteren Requests und gespeicherten Daten planen. Keine pauschale Löschung historischer 2026-Daten; Datenbankänderungen und Migration separat prüfen.
- [ ] Namen für die Gewinnabwicklung bei Bedarf separat erfassen, nicht erneut als allgemeines Anmeldefeld einführen.

Dateien: `Views/Screens/ContentView+Tabs.swift` (`raffleEntrySheet`, `submitRaffleEntryFromSheet`), `Views/Screens/ContentView.swift` (`raffleEntryName`), `Services/AppServices.swift` (`RaffleEntryRequest`, `RaffleEntryPayload`), `Models/SeasonProgressStore.swift` (`SeasonRaffleProgress`, Altdatenmigration), `output/backend-raffle/raffle.php`, `draw.php`, Tests/Schema.

## A02 – Anmeldung und Information an die endgültigen Bedingungen anpassen

**Lokaler UI-Probelauf abgeschlossen:** Das temporäre Debug-/Testformular wurde nach Sichtprüfung wieder entfernt. Es hatte keinen Raffle-Request gesendet und keinen Teilnahmestatus geschrieben. Die produktive App-Phase bleibt `.announced`, `registration_enabled` im Backend bleibt `false`. Der Probelauf war keine Server- oder Datenschutzabnahme.

- [ ] Endgültigen 2027-Text und eigene Bedingungsversion in App und Backend hinterlegen. 2026-Fassung erhalten; kein Rückgriff auf 2026-Text für 2027.
- [ ] UI-Texte in Formular, Verlosungsbereich und Onboarding abgleichen. Aktuelles „unter den Teilnehmenden mit den meisten Stempeln“ um das Nachrücken für verbleibende Preise ergänzen.
- [ ] Teilnahmeberechtigung einschließlich Wohnsitz und Ausschlusskreis vor Anmeldung verständlich anzeigen. Das derzeitige Formular bestätigt lediglich Bedingungen, Volljährigkeit und Kontakt. Die Abschlussfassung verlangt auch die Bestätigung von Wohnsitz und Ausschlusskreis. Diese verständlich abbilden; Nachweise nur bei konkreten Zweifeln im Gewinnfall nach § 4 Absatz 6. Keine Adresssammlung bei Anmeldung ohne begründeten Bedarf.
- [ ] Kontakt-Hinweis auf alle erforderlichen Verlosungsnachrichten abstimmen, einschließlich Frist- und Störungsinformationen. Die aktuelle zusätzliche Pflichtbestätigung betrifft nur den Gewinnfall. Die Abschlussfassung stützt notwendige Verlosungskommunikation auf die Durchführung des Teilnahmeverhältnisses (Art. 6 Abs. 1 lit. b DSGVO). Die bisherige zusätzliche Kontakt-Einwilligung durch einen passenden Datenschutzhinweis ersetzen und die Zustimmung zu den Teilnahmebedingungen getrennt nachvollziehbar halten; vor Umsetzung rechtlich abgleichen.
- [ ] Zustimmungszeitpunkt und akzeptierte Version nachvollziehbar halten, auch bei erneuter Anmeldung. Aktuelles Upsert überschreibt diese Angaben.
- [ ] Fehler bei der Anmeldung verständlich anzeigen; lokale Erfolgsmeldung erst nach bestätigter Serverannahme. Die Anmeldung selbst besitzt derzeit keine Offline-Warteschlange; nicht als offline erfolgreich behandeln.
- [ ] Entscheiden, ob die Inhaberschaft der E-Mail-Adresse bei Anmeldung bestätigt werden soll. Der aktuelle Ablauf prüft nur das Format; ein Bestätigungslink ist weder umgesetzt noch bereits als neue Teilnahmevoraussetzung beschlossen.

Dateien: `Views/Screens/ContentView+Tabs.swift`, `ContentView+Onboarding.swift`, `Models/SeasonCatalog.swift` (`RaffleTermsCatalog`, `RaffleConfiguration`), `Services/AppServices.swift`, `output/backend-raffle/raffle.php`.

## A03 – Offline-Speicherung und bestätigte Übertragung absichern

**Vorhanden:** Stempel wird zuerst lokal gespeichert; erfolglose Ereignisübertragung wird danach in UserDefaults eingereiht. Wiederholung u. a. beim Aktivieren der App oder nach erfolgreicher Ereignisübertragung. Kein garantierter Hintergrundabgleich.

- [ ] Lücke bei App-Abbruch zwischen lokaler Stempelspeicherung und Einreihung der fehlgeschlagenen Meldung schließen. Wiederherstellung nach Neustart sicherstellen.
- [ ] Wiederholtes Senden idempotent gestalten; keine Doppelzählung. Fehlgeschlagene und parallel hinzukommende Meldungen erhalten.
- [ ] Queue-Grenzen und Verhalten bei Speicher-/Netzwerkfehlern prüfen, damit relevante Check-ins nicht unbemerkt verloren gehen.
- [ ] Bestätigten Servereingang von bloß lokal vorhandenem Stempel unterscheiden. Verständlichen Übertragungsstatus und Handlungshinweis vor Fristende anzeigen.
- [ ] Umgang mit Gerätewechsel, Neuinstallation und Wiederherstellung festlegen; lokale Sammlung, Anmeldung und Servereinträge konsistent halten.

Dateien: `Bergschein/ViewModels/ContentViewStore.swift` (`claimBadge`), `Models/SeasonProgressStore.swift`, `Services/AppServices.swift` (`track`, `flushPendingEvents`, Queue), `Views/Screens/ContentView.swift` (Lebenszyklus), `ContentView+Badges.swift`.

## A04 – Gültige Check-ins, Servereingang und verbindlichen Datenstand prüfen

- [ ] Ursprünglichen Check-in-Zeitpunkt, Bergtag und tatsächlichen Servereingang getrennt verarbeiten. Einheitliche Umrechnung zwischen UTC und Europe/Berlin, einschließlich Tagesgrenzen.
- [ ] Server-Eingangsfrist durchsetzen und verspätete Meldungen von zulässigen Korrekturen unterscheiden. Aktuelles `draw.php` filtert nur `event_time`, nicht den Eingang.
- [ ] Gültigkeit der Check-ins nachvollziehbar absichern. Das aktuelle Maximum eines vom Client gemeldeten Stempelzählers ist kein unabhängiger Beleg für gültige einzelne Tagesstempel. Standortprüfung erfolgt derzeit in der App; das passende Missbrauchsschutzverfahren ist noch zu wählen.
- [ ] Maximal ein gültiger Tagesstempel je Person/Bergtag, keine Challenge- oder Testdaten in der Verlosungswertung. Stempel vor Anmeldung sowie während der Bergtage gültig entstandene spätere Uploads berücksichtigen.
- [ ] Nach Fristende einen unveränderlichen, dokumentierten Ausgangsdatenstand für Erst- und Ersatzvergaben sichern; berechtigte Korrekturen mit Grund und Version dokumentieren.

Dateien: `output/backend-season/track.php`, `output/backend-raffle/draw.php`, `raffle_seasons.php`, `Services/AppServices.swift`, `Bergschein/ViewModels/ContentViewStore.swift`.

Aktueller App-Stand: erster Tag ab 17:00 Uhr, weitere Tage ab 10:00 Uhr, jeweils vor 23:00 Uhr; Polygonprüfung des Berggeländes. Die Abschlussfassung übernimmt diese Zeiten ausdrücklich. Den verbindlichen Bereich für 2027 für reguläre Nutzer vor dem Check-in verständlich sichtbar machen und mit den Bedingungen abgleichen. Eine Polygonkarte wurde bisher nur im Testbereich gefunden; nicht als vorhandene öffentliche Funktion voraussetzen. Standortfreigabe, Randfälle und Messfehler behandeln.

## A05 – Personen statt Installationen eindeutig berücksichtigen

- [ ] Verfahren für Mehrfachanmeldungen über mehrere Geräte/E-Mail-Adressen festlegen und umsetzen. Aktuelles `UNIQUE (season_id, install_id)` verhindert nur doppelte Einträge derselben Installation.
- [ ] Weder gleiche Namen noch E-Mail-Adressen ungeprüft als eindeutigen Identitätsbeleg behandeln. Wegfall des Namensfelds berücksichtigen; keine pauschalen Ausweiskopien einführen.
- [ ] Zusammenführung zulässiger eigener Check-ins und Ausschluss missbräuchlicher Zusatzlose nachvollziehbar regeln. Kein doppelter Tagesstempel bei Zusammenführung.
- [ ] Gewinnzuteilung und Ausschlüsse personengebunden über Erst- und Ersatzvergaben sichern.
- [ ] Ausschlussgrund und Entscheidung nachvollziehbar dokumentieren und bei Ziehungen berücksichtigen, einschließlich des bestätigten Ausschlusskreises aus Veranstalter, unmittelbar Beteiligten und benannten Angehörigen. Die Abschlussfassung sieht die Bestätigung der Teilnahmeberechtigung im Formular sowie eine gezielte Prüfung bei konkreten Zweifeln im Gewinnfall vor (§§ 4 und 6).

**Verfahren im Entwurf konkretisiert:** erkennbare Mehrfachanmeldungen vor Ziehung zusammenführen, gleiche Bergtage nur einmal zählen, bei später erkannter Mehrfachzuteilung höchstens die erste regelkonforme Zuteilung erhalten. Weitere noch nicht übergebene Preise nach § 8 neu vergeben; keine pauschale Rückforderung bereits übergebener Preise. **Technisch offen:** konkretes Identitäts-/Missbrauchsschutzverfahren. Betroffene Stellen: Registrierung, Stempelzuordnung, Ziehung, spätere Gewinnprüfung und Datenschutzinformationen.

## A06 – Ziehung mit absteigenden Stempelgruppen implementieren

**Aktuell:** frei übergebener `min_badges`-Schwellwert und `ORDER BY RAND() LIMIT`; keine dauerhafte Ziehungs- oder Preiszuordnung.

- [ ] Höchste vorhandene berechtigte Gruppe bestimmen, innerhalb der Gruppe zufällig ohne Wiederholung ziehen, erst danach in die nächstniedrigere vorhandene Gruppe wechseln.
- [ ] Vorab festgelegte Preisanzahl und Preisreihenfolge verwenden. Keine unveränderliche Annahme „drei Preise“ oder stille Begrenzung durch den aktuellen Default/Request-Limit; tatsächliche Preisliste maßgeblich machen.
- [ ] Ein-Personen-Gruppe direkt berücksichtigen; keine Berechtigten bzw. weniger Berechtigte als Preise korrekt behandeln. Verbleibende Preise als unvergeben abschließen.
- [ ] Ergebnis einschließlich Preis, Person, Ausgangsgruppe, Datenstand und Zeitpunkt dauerhaft speichern. Wiederholte/gleichzeitige Aufrufe dürfen keine zweite unabhängige Erstziehung auslösen.
- [ ] Zufallsverfahren nachvollziehbar dokumentieren und Ergebnis gegen nachträgliches willkürliches Neuziehen schützen.

Dateien: `output/backend-raffle/draw.php`, Datenbankschema und Integrationstests; ggf. späterer Verwaltungsablauf.

## A07 – Gewinnkommunikation, Rückmeldung und Ersatzvergaben

- [ ] E-Mail-Benachrichtigung mit Preis, Rückmeldeweg, konkretem Fristende und Verfallsfolge umsetzen bzw. einen dokumentierten manuellen Ablauf schaffen. Ein automatisiertes Versandsystem ist nicht zwingend beschlossen.
- [ ] Versand, Zugang/Zustellprobleme und Rückmeldung unterscheiden; 14 Kalendertage nach Zugang korrekt berechnen. Tagesberechnung, Wochenenden und Feiertage nach § 8 Absatz 2 beachten; Versand nicht als Zugang fingieren. Bei Zustellfehler Ursache prüfen und spätestens nach sieben Tagen erneut versuchen (bei anhaltender technischer Störung nach Behebung). Privaten Hinweis zur E-Mail-Korrektur in der betroffenen Anmeldung vorsehen; die eigentliche Gewinnbenachrichtigung bleibt per E-Mail. Ohne feststellbaren Zugang Preis reservieren, spätestens nach 28 Tagen und danach regelmäßig prüfen. Kein automatischer Verfall nach Versand oder nach 28 Tagen; übrige Teilnahmen weiter abwickeln.
- [ ] Annahme, Ablehnung und Fristablauf dokumentieren. Ersatz nur aus der höchsten verbleibenden Gruppe bisher unberücksichtigter Personen, gleicher Datenstand und keine Neuverteilung anderer Preise.
- [ ] Für Ersatzgewinner erneut volle Rückmeldefrist; wiederholen bis Abwicklung oder Erschöpfung der Berechtigten. Ablehnende/Fristversäumer nicht erneut berücksichtigen.
- [ ] Erforderliche Angaben für Übergabe/Versand erst im Gewinnfall erheben. Datensparsamen Altersnachweis bei begründeten Zweifeln ermöglichen; kein Automatismus zur Ausweisprüfung aller Gewinner.

**Im Abschlussentwurf geregelt:** Nachweisprüfung bei begründeten Zweifeln mit mindestens 14 Tagen, konkreter Rückfrage und gegebenenfalls mindestens sieben Tagen Nachfrist; geeignete Einsichtnahme oder datensparsame Fernprüfung, Ergebnis dokumentieren und nicht erforderliche Nachweiskopien löschen. Vor Ausschluss mindestens 14 Tage Stellungnahme nach § 10. Keine Aberkennung allein aufgrund einer Anforderung oder unverschuldeter Nachweisprobleme; gesetzliche Beweislast beachten. Nachträglicher berechtigter Ausschluss: noch nicht übergebenen Preis nach § 8 ersetzen. **Praktisch einzurichten:** sicherer Fernprüfweg, Zustellnachweise und manuelle Fallbearbeitung. **Mit den Preisen offen:** Übergabe-/Versandmodalitäten und Versandpartner.

## A08 – Nachgewiesene Störungen, Korrekturen und Bekanntgabe

- [ ] Meldeweg laut Abschlussfassung: kontakt@derbergschein.de, möglichst zeitnah und vor Übertragungsende, aber ohne zusätzliche starre Ausschlussfrist. Ergebnis und wesentliche Gründe per E-Mail mitteilen. Tatsächlich verfügbare Belege und Verantwortlichkeit festlegen; keine bestimmte Nachweisart vorschreiben. Ein Screenshot ist kein automatischer Nachweis; eigene Systemkenntnisse einbeziehen.
- [ ] Prüfung und Entscheidung dokumentieren; Störung und Betroffenheit des konkreten Check-ins feststellen. Bei Korrekturen übrige Check-in-Voraussetzungen berücksichtigen. Vergessene Check-ins nicht als Störung anerkennen.
- [ ] Einheitliche Korrekturen bzw. nötige Übertragungsfristverlängerungen sicher in App und Backend abbilden; neue Frist und spätesten Ziehungstag synchron halten.
- [ ] Offene Störungsmeldungen vor der Ziehung behandeln; Späte bestätigte Fehler auf Auswirkungen und mögliche Abhilfe prüfen, ohne automatische Neuziehung oder Aufhebung fremder Gewinnansprüche. Gesetzliche Ansprüche erhalten. Eine Unterbrechung nur nach § 11; bei Fortsetzung die Frist nach § 7 Absatz 1c abbilden.
- [ ] Nach §§ 7 und 11 notwendige Informationen in der App bereitstellen; bereits Angemeldete nach § 11 zusätzlich per E-Mail informieren. Umfang, Grund, Dauer, neue Fristen und etwaige Beendigung nachvollziehbar bekanntgeben.
- [ ] Bei Fortsetzung gültige Anmeldungen und Stempel erhalten; keine freie Änderung von Gewinnchancen oder Ein-Preis-Regel durch administrative Einstellungen.

**Vorhandene Belege erst prüfen:** keine umfassende Protokollierung oder automatische Nachweisfunktion zugesagt. Organisatorische Verfahren müssen nicht alle als neue App-Funktion umgesetzt werden.

## A09 – Datenumfang, Datenschutzinformationen und Löschung

**Lokaler Datenabgleich 15.09.2026:** `raffle_entries` erhält für neue 2027-Anmeldungen Installations- und Saisonkennung, E-Mail, Bedingungsversion, Alters-/Kontaktbestätigung, Server-Zustimmungszeitpunkt sowie den Stempelwert beim POST. Name, Challenge-Zähler und Vollständigkeitsflag werden im lokalen 2027-Anmeldepfad nicht mehr gesendet oder gespeichert; historische DB-Spalten bleiben kompatibel. `analytics_events` enthält unabhängig davon zuordenbare Stempel- und Challenge-Ereignisse mit Ereigniszeit, Tageskennung und Zählern; `draw.php` liest bisher nur Badge-Ereignisse und deren gemeldeten Stempelzähler. Ein eigenständiger Server-Eingangszeitpunkt pro Ereignis, ein unveränderliches Ziehungsprotokoll und ein Löschverfahren sind im lokalen Code noch nicht vorhanden. App-seitige Fehlversuche werden in UserDefaults zwischengespeichert; Verlosungsanmeldungen haben keine Offline-Queue. Dieser Codeabgleich bestätigt weder Live-Einstellungen, API-/Webserverlogs, E-Mail-Aufbewahrung noch Backups bei ALL-INKL.

- [ ] Erforderliche Daten inventarisieren: App-Speicher, Raffle-Tabelle, Analytics-Verknüpfung, spätere Ziehungsprotokolle, E-Mail-Verkehr, Nachweise, Exporte, Serverlogs, Backups und Dienstleister.
- [ ] **Beschlossen:** kein Name bei Anmeldung (A01), keine Werbung/Newsletter, keine Weitergabe dafür.
- [ ] **Bestätigter Kontakt für Datenschutzanfragen:** kontakt@derbergschein.de. Diesen Kontakt in den Datenschutzinformationen und dem Verfahren zur Bearbeitung von Betroffenenanfragen berücksichtigen.
- [x] **Beschlossen und lokal umgesetzt:** zusätzliche Challenge-Zähler und Vollständigkeitsflag aus neuen 2027-Anmeldungen entfernt; ältere Clients können sie für 2027 nicht neu speichern. `draw.php` und `community.php` nutzen sie nicht für die Auswahl. Die Analytics-/Challenge-Ereignisse haben einen getrennten älteren Datenvertrag und bleiben unberührt. Historische Daten und Datenbankspalten nicht pauschal löschen.
- [ ] Die nach Zwecken aufgeteilten Rechtsgrundlagen der Abschlussfassung (Teilnahmeverhältnis lit. b, konkrete gesetzliche Pflicht lit. c, erforderliche Sicherheit/Missbrauchsschutz/Rechtsverteidigung nach Abwägung lit. f) mit der tatsächlichen Verarbeitung prüfen und in Datenschutzerklärung und In-App-Hinweisen korrekt abbilden. Hosting und E-Mail über ALL-INKL sowie https://derbergschein.de/privacy/ sind vom Nutzer bestätigt. Standortdaten lokal/übertragen und Serverlogs ausdrücklich prüfen, nicht aus dem Raffle-Payload auf das gesamte Hosting schließen.
- [ ] **Beschlossene Löschregel umsetzen:** personenbezogene Verlosungsdaten nur solange für Durchführung und Abwicklung einschließlich Ersatzvergaben erforderlich speichern; nach Abschluss unverzüglich löschen. Abschluss bedeutet: sämtliche Preise übergeben oder endgültig unvergeben und Ersatzvergabeverfahren beendet. Diesen Abschluss nachvollziehbar erfassen und die Löschung auslösen; nicht schon nach der Erstziehung löschen.
- [ ] Eng begrenzte Ausnahmen für gesetzliche Aufbewahrungspflichten oder erforderliche Rechtsverteidigung dokumentieren. Nur die benötigten Daten für die erforderliche Dauer zurückhalten, anschließend ebenfalls löschen. Ein einzelner Streit-, Zustell- oder Nachweisfall darf die Löschung aller übrigen Teilnehmerdaten nicht blockieren. Bereits vorher nicht mehr erforderliche Daten einzelner Teilnahmen schon vor dem Gesamtabschluss löschen. Konkrete Belegarten, Fristen/Prüfkriterien und Nachweisführung sind noch festzulegen; keine pauschale Aufbewahrung für 30/90 Tage oder drei Jahre beschlossen.
- [ ] Lokale Kontaktdaten und Altdatenmigration bei Löschung berücksichtigen; keine spätere Wiederherstellung bereits gelöschter Kontaktdaten aus Legacy-Schlüsseln oder Backups.
- [ ] Verknüpfte Analytics-Daten, Exporte und E-Mails ebenfalls nach geltendem Zweck behandeln; Löschen der Raffle-Zeile allein ist nicht automatisch vollständige Löschung/Anonymisierung.
- [ ] Verfahren für Auskunft, Berichtigung, Löschung und Rücknahme der Teilnahme ermöglichen. Kontaktänderung und Rücknahme über kontakt@derbergschein.de nach § 6 ermöglichen, Zuordnung angemessen prüfen. Rücknahme beendet die weitere Teilnahme; bereits entstandene Gewinne nicht ohne ausdrückliche Ablehnung aufheben. Für bereits gespeicherte Daten verbleibende Zwecke und Löschregeln beachten.
- [ ] Persönliche lokale Stempelsammlung von den Kontaktdaten der Verlosung unterscheiden; keine pauschale Löschung der Sammlung aufgrund einer Raffle-Löschfrist.

## A10 – Finale Inhalte und bewusste Freigabe

- [ ] Endgültige Preise, Beschreibung, Anzahl, Vergabereihenfolge und Bedingungen in App/Backend abgleichen. Bis dahin Ankündigung mit „Preise folgen“ erhalten.
- [ ] Finalen Stand der Teilnahmebedingungen einschließlich Veranstalter, Kostenfreiheit, Ausschlusskreis, Haftung, Datenschutz, Apple-Hinweis und Schlussbestimmungen übernehmen; keine Freistellungsklausel aus 2026 in 2027 übernehmen.
- [ ] Alle Datumsgrenzen, einheitliche Zeitzone, Ziehungszeitraum und eventuelle Verlängerungen abgleichen. Grunddaten sind bereits konfiguriert; keine Neuentwicklung der vorhandenen Saisontrennung nötig.
- [ ] Produktions-, Test- und Altsaisons weiterhin strikt trennen. 2027 ist derzeit angekündigt, Terms-Version und Ziehungsfreigabe fehlen/stehen aus; `registration_enabled` bleibt bis separater bewusster Freigabe `false`.
- [ ] Tatsächlichen Live-Stand erst in einer späteren autorisierten Umsetzung/Veröffentlichung prüfen. Keine Konfiguration oder Migration allein aufgrund dieser Sammlung aktivieren.

## A11 – Bestehende Datenschutzerklärung und Website-Texte aktualisieren

**Vom Nutzer ausdrücklich zur späteren Bearbeitung angefordert.** Grundlage: [veröffentlichte Datenschutzerklärung](https://derbergschein.de/privacy/), am 15.09.2026 im Browser gelesen, Stand 2026. Hosting und E-Mail laufen laut Nutzer beide über ALL-INKL. Die Website wurde hier nur gelesen, nicht geändert.

- [ ] **Abschnitt 1 – Kontakt:** Florian Werner/FFWD und Anschrift sind bereits enthalten. kontakt@derbergschein.de als Kontakt für Verlosung und Datenschutz ergänzen beziehungsweise konsistent ausweisen. Die bisherige allgemeine Adresse contact@ffwdventures.de muss nicht allein deshalb gelöscht werden.
- [ ] **Abschnitt 3a – Serverlogs:** tatsächlich erfasste Felder, technische Zwecke und Rechtsgrundlage sowie konkrete Fristen oder nachvollziehbare Löschkriterien prüfen und angeben. Die gegenwärtige Aussage zu gekürzten/anonymisierten IP-Adressen nur beibehalten, soweit sie für die konkrete Einrichtung stimmt. Website-Logs und API-Logs unterscheiden; keine ALL-INKL-Frist für dessen eigene Website ungeprüft übernehmen.
- [ ] **Abschnitt 3b – E-Mail:** Hosting/Postfach und Versand über ALL-INKL benennen. Verlosungsnachrichten, Support/Störungsmeldungen, Datenschutzanfragen und eventuelle Nachweise mit jeweiligen Zwecken, Rechtsgrundlagen und Löschung abbilden. Keine Newsletter-/Werbeeinwilligung aufnehmen.
- [ ] **Abschnitt 4a – Standort:** lokale Standortprüfung von der anschließenden Übermittlung zuordenbarer Check-in-Ereignisse unterscheiden. Keine GPS-Übertragung behaupten, wenn tatsächlich nur das Prüfergebnis/Ereignis übertragen wird; nach der finalen Missbrauchsschutz-Umsetzung erneut abgleichen. Lokale Verarbeitung ist nicht gleichbedeutend mit überhaupt keiner personenbezogenen Verarbeitung.
- [ ] **Abschnitt 4b – Fortschritt und Serverübertragung:** Aussage „Es erfolgt keine automatische Übertragung an externe Server“ korrigieren. Im lokalen Code werden Stempel-/Challenge-Ereignisse mit Installationskennung und Saison übermittelt; fehlgeschlagene Ereignisse werden lokal zwischengespeichert und später erneut gesendet. Tatsächliche Daten und Zwecke erklären. Allgemeine App-Auswertung und Verlosungswertung getrennt beschreiben.
- [ ] **Neuer Abschnitt Verlosung 2027:** technische Kennung/Saison, E-Mail, Teilnahmeerklärungen und Zeitpunkte, akzeptierte Version, Stempel-/Übertragungsdaten, Gültigkeits- und Personenprüfung, Ziehung/Preiszuordnung, Kommunikation, Ersatzvergaben und Gewinnabwicklung ergänzen. Verknüpfung mit Check-in-Ereignissen erklären. Name, Challenge-Zähler und Vollständigkeitsflag entfallen in neuen 2027-Anmeldungen; weitere Namen/Zustelldaten erst bei Bedarf im Gewinnfall. Unabhängige Analytics-/Challenge-Ereignisse getrennt beschreiben.
- [ ] **Rechtsgrundlagen und Pflichtangaben:** § 13 der Teilnahmebedingungen nach Zwecken korrekt abbilden; erforderliche Daten, freiwillige Teilnahme und Folgen der Nichtbereitstellung erklären. Kein pauschales Einwilligungsmodell für ohnehin notwendige Verlosungskommunikation. Rechtsgrundlage und Erforderlichkeit allgemeiner App-Analytics gesondert prüfen; nicht automatisch aus dem Teilnahmeverhältnis ableiten, insbesondere vor Anmeldung oder bei Nichtteilnehmenden.
- [ ] **Abschnitt 4c – Werbung/Sponsoren:** klarstellen, dass Kontaktdaten der Verlosung nicht für Werbung oder Newsletter verwendet und nicht dafür weitergegeben werden. Die bestehende Aussage über allgemeine Sponsoreninhalte anhand des tatsächlichen App-Verhaltens prüfen. Das Verbot der Kontaktnutzung bedeutet nicht automatisch, dass sämtliche bestehenden Sponsoreneinblendungen entfernt werden sollen.
- [ ] **Abschnitt 5 – Empfänger:** ALL-INKL als Hosting-/E-Mail-Dienstleister konkret benennen. Bestehenden Auftragsverarbeitungsvertrag und tatsächliche Unterauftragnehmer/Verarbeitung prüfen. Spätere Versand-/Einlösestellen nach Preisfestlegung ergänzen. Etwaige Drittlandübermittlungen und erforderliche Garantien transparent abbilden; keine ungeprüfte Aussage „keine Drittlandübermittlung“ allein wegen deutschen Hostings.
- [ ] **Abschnitt 6 – Speicherung/Löschung:** Verlosungsdaten nur bis zum Wegfall des jeweiligen Zwecks, einschließlich erforderlicher Ersatzvergaben, speichern. Abschluss pro Teilnahme berücksichtigen; ein offener Einzelvorgang hält nicht alle Daten zurück. Konkrete Unterlagen bei gesetzlichen Pflichten/Rechtsverteidigung eingrenzen; Fristen oder Kriterien angeben. E-Mails, Nachweiskopien, Exporte, lokale Kontakt-/Altwerte, Logs und Backups einbeziehen. Persönliche Stempelsammlung getrennt behandeln.
- [ ] **Abschnitt 7 – Betroffenenrechte:** gesetzliche Voraussetzungen präzisieren; Auskunft, Berichtigung, Löschung, Einschränkung und Datenübertragbarkeit, besonderes Widerspruchsrecht bei Interessenabwägung sowie Beschwerdemöglichkeit beim BayLDA und anderen zuständigen Aufsichtsbehörden abbilden. Kontaktadresse nennen. Nur soweit tatsächlich auf Einwilligung gestützt, über deren Widerruf informieren; Teilnahme-Rücknahme und Datenschutzrechte unterscheiden.
- [ ] **Automatisierte Entscheidung/Datenschutzbeauftragter:** tatsächlichen Ziehungs- und Kontrollablauf prüfen. Gegebenenfalls Artikel 13 Absatz 2 Buchstabe f und Artikel 22 DSGVO samt Informationen und Schutzmaßnahmen berücksichtigen; keine unbestätigte Negativaussage. Einen Datenschutzbeauftragten nur angeben, wenn tatsächlich bestellt beziehungsweise erforderlich.
- [ ] **Abschnitte 8–9 und Verfügbarkeit:** Sicherheitsangaben mit der tatsächlichen Umsetzung abgleichen; Stand aktualisieren und vollständige Hinweise vor Anmeldung in der App erreichbar machen. Datenschutzlink in § 13(8) ist bereits https://derbergschein.de/privacy/.
- [ ] **Website-FAQ ebenfalls abgleichen:** Die Startseite beschreibt Fortschritte/Daten ebenfalls als grundsätzlich lokal und ohne Tracking/Weitergabe, soweit nicht ausdrücklich angegeben. Diese Aussagen mit der konkret erklärten Serverübertragung und Verlosung abstimmen, damit Website und Datenschutzerklärung einander nicht widersprechen.

**Abnahme:** finalen Text gegen tatsächliche App-/Backend-Datenflüsse, ALL-INKL-Einstellungen, Kommunikationsablauf und Teilnahmebedingungen lesen. Keine erfundenen Dienstleister, Speicherdauern oder Zusagen verwenden. Erst danach veröffentlichen.

## Gezielte Abnahmefälle für die spätere Umsetzung

- Kein Namensfeld/Name im neuen 2027-Anmeldevorgang; alte Datensätze kompatibel und kein versehentliches Mitsenden vorbefüllter Namen.
- Offline-Check-in, App-Abbruch vor/nach Sendeversuch, Neustart, Wiederholung, parallele Queue-Ereignisse und kein doppelter Stempel.
- Gültiger Stempel vor Anmeldung zählt; bloßer Besuch, unzulässiger Tag/Zeitpunkt, Challenge und Testsaison zählen nicht.
- Exakt vor/ab Anmelde- und Übertragungsende; UTC/Ortszeit und Tagesgrenzen; begründete Verlängerung einschließlich spätester Ziehung.
- Drei Preise: eine Person mit zwölf Stempeln und mehrere mit elf; zwei Personen mit zwölf und nächste Gruppe mit zehn; mehr Berechtigte als Preise; niemand bzw. weniger Personen als Preise.
- Dieselbe Person auf mehreren Installationen: höchstens ein Tagesstempel je Bergtag, keine Zusatzlose und höchstens ein Preis.
- Wiederholte/gleichzeitige Ziehungsaufrufe liefern dieselbe dokumentierte Erstziehung.
- Ablehnung/Nichtantwort, Ersatzvergabe und erneuter Ersatz, unveränderte andere Preise, Erschöpfung der Berechtigten. Unzustellbare E-Mail ohne fingierten Zugang, erneuter Versand, privater Korrekturhinweis und reservierter Einzelpreis.
- 14-Tage-Annahmefrist und abweichende Nachweisfristen, Zugangstag/Tagesende, Samstag/Sonntag/Feiertage, Empfangsstörung sowie Anhörung vor Ausschluss.
- Sichtbarer regulärer Check-in-Bereich; Gerätewechsel, zusammengeführte Stempel und erst später erkannte Mehrfachzuteilung.
- Bestätigte Störung vs. bloße Behauptung/vergessener Check-in; dokumentierte Korrektur und erhaltene Einträge nach Unterbrechung.
- Löschung nach beschlossener Regel, erforderliche Ausnahmefälle, keine Wiederherstellung aus lokalen Altwerten; Stempelsammlung bleibt davon getrennt.

Für Swift-Änderungen passende XCTest-Fälle ergänzen und den tatsächlichen Scheme-/Simulatornamen prüfen; AGENTS.md nennt `AppList`/`iPhone 16`. PHP-Regel- und Integrationstests liegen unter `output/backend-raffle/tests/`. In dieser Dokumentationssitzung wurden keine Funktionstests ausgeführt.

## Einstieg in die separate Sitzung

Zuerst aktuelle Teilnahmebedingungen und diese Liste lesen, offene fachliche Punkte abgleichen und nur beschlossene Regeln umsetzen. Empfohlene Reihenfolge: Datenvertrag/Identität/Fristen festlegen → Formular und Offline-Speicherung → Servervalidierung und Datenstand → Ziehung/Ersatzvergaben → Kommunikation/Datenschutz → gemeinsame Abnahme. Nicht automatisch ein neues Codex-Task anlegen oder produktiv schalten.
