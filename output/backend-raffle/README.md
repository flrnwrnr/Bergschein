# Saisongetrennter Verlosungsentwurf

Dieser Ordner enthält die lokale Backend-Arbeitskopie für die saisongetrennte
Verlosung. Er enthält keine Zugangsdaten und führt keine Live-Anfragen aus.

Die vollständige Sammlung der noch erforderlichen App- und Backend-Arbeiten
steht in [Änderungen für die separate Umsetzungssitzung](../raffle-terms/APP_BACKEND_AENDERUNGEN_2027.md).
Sie unterscheidet festgelegte Regeln von offenen Entscheidungen. Der
[Abschlussvermerk zur Überarbeitung](../raffle-terms/ABSCHLUSS_2027.md)
erläutert die konsolidierte Fassung und die Freigabevoraussetzungen.
Das optionale Namensfeld entfällt bei der Anmeldung; UI, Request und
Speicherung werden erst in der separaten Sitzung angepasst. Abschnitt A11
der Änderungsliste sammelt außerdem die Anpassungen der veröffentlichten
Datenschutzerklärung. Hosting und E-Mail über ALL-INKL sind bestätigt.

## Aktueller Stand

`bergschein-2026`, `bergschein-2027` und beide Test-Saisons sind serverseitig
für Anmeldungen geschlossen. Die App zeigt 2027 als Ankündigung mit „Preise
folgen“, aber ohne Formular. Der im Teilnahmebedingungen-Entwurf bestätigte
Anmeldezeitraum für 2027 ist 29.04.2027 00:00 bis 31.05.2027 23:00 Uhr
(Europe/Berlin; Start inklusive, Ende exklusiv). Gültige
Teilnahmebedingungen und Ziehungszeit sind noch nicht hinterlegt; die
Serverfreigabe bleibt ausgeschaltet. Der Zeitraum öffnet daher nicht
automatisch die Anmeldung.
Über `raffle.php` kann daher keine 2027-Anmeldung erfolgen. Die Eventdaten
für 2027 bleiben als Planungsdaten erhalten.

Die Allowlist umfasst ausschließlich `bergschein-2026`, `bergschein-2027`,
`test-bergschein-2026` und `test-bergschein-2027`. Einträge sind je Saison und
Installation eindeutig. Ziehungen koppeln Einträge und Analytics-Ereignisse an
dieselbe Saison.

## Dateien

- `raffle_seasons.php`: maßgebliche Allowlist und die Regeln je Saison.
- `raffle.php`: saisongebundene, idempotente Registrierung.
- `draw.php`: Basic-Auth-geschützte Ziehung nach Saisonende.
- `rollback/raffle_seasons.php`: geschlossene Sicherung vor der Terminplanung.
- `migrations/001_raffle_seasons.sql`: Schemaentwurf.
- `tests/raffle_seasons_test.php`: Regeltests ohne Datenbank.
- `tests/integration_raffle.sh`: lokaler End-to-End-Test mit gefälschten
  Zugangsdaten und einem kurzlebigen MariaDB-10.6-Container.

## Lokale Prüfung

```sh
php -l output/backend-raffle/raffle_seasons.php
php output/backend-raffle/tests/raffle_seasons_test.php
bash output/backend-raffle/tests/integration_raffle.sh
```

Der Integrationstest kopiert die drei PHP-Endpunkte in einen temporären Ordner
und ergänzt dort ausschließlich lokale, offene Fixture-Saisons. Er prüft, dass
die echten 2027- und Test-2027-Saisons geschlossen bleiben, ungültige
Saisonkennungen und Bedingungsversionen abgelehnt werden, Produktiv- und
Testdaten getrennt gespeichert werden und eine Ziehung nur die passende
Saison-Analytics verwendet. Er berührt weder ALL-INKL noch `config.php` und
räumt Container und Fixture-Daten wieder auf.

## Vorbereitung der echten 2027-Verlosung

Sobald Preis, vollständige Bedingungen und Ziehungsregel feststehen, werden
sie zusammen mit dem bereits geplanten Zeitraum geprüft. Bis zu einer
bewussten späteren Freigabe bleibt
`registration_enabled` auf `false`; die aktuelle Datei ist dafür der saubere
Ausgangspunkt.

Die Ziehung verwendet derzeit einen konfigurierbaren Mindestwert
`min_badges`. Für 2027 wurde am 15.09.2026 folgende abweichende Regel
festgelegt: höchstens ein Preis pro Person; Vergabe nach absteigender Zahl
gültiger Tagesstempel, innerhalb gleicher Stempelzahl per Los. Erst nach
Berücksichtigung aller Personen einer Gruppe geht es für verbleibende Preise
mit der vorhandenen nächstniedrigeren Gruppe weiter. Die Regel steht in
`../raffle-terms/teilnahmebedingungen-2027-entwurf.md`, § 7.

Diese Regel ist im Backend noch nicht umgesetzt. Vor der Freigabe sind
insbesondere die Gruppenauswahl, ein Personenabgleich über Installationen
hinweg, die Preisreihenfolge, ein verbindlicher Datenstand nach der
Übertragungsfrist und eine dauerhafte Ziehungsdokumentation umzusetzen.
Die bestehende Eindeutigkeit pro Installation genügt nicht für die Regel
„höchstens ein Preis pro Person“.

Für offline gespeicherte, im gültigen Tageszeitfenster abgeholte Stempel
ist im Teilnahmebedingungen-Entwurf eine Übertragungsfrist bis zum
31.05.2027 um 23:00 Uhr (Europe/Berlin, Ende exklusiv) festgelegt.
Die erstmalige Ziehung erfolgt innerhalb der folgenden sieben Kalendertage,
regulär spätestens am 07.06.2027. Wird die Übertragungsfrist wegen
nachgewiesener technischer Störungen nach § 7 Absatz 1b verlängert, beginnt
der siebentägige Ziehungszeitraum nach Ablauf der verlängerten Frist.
Die neue Frist und der späteste Ziehungstag sind bekanntzugeben.
Spätere Ersatzvergaben nach § 8 fallen nicht unter diesen Zeitraum.
Diese Vorgabe ist noch technisch und organisatorisch abzusichern;
die Ziehungsfreigabe bleibt ausgeschaltet. Vor Freigabe müssen ursprüngliche
Check-in-Zeit und tatsächlicher Servereingang getrennt geprüft und der
für die Ziehung maßgebliche Datenstand festgehalten werden. Der aktuelle
Filter auf `event_time` allein setzt diese Eingangsfrist nicht durch.
App-seitig ist außerdem die Lücke zwischen lokaler Stempelspeicherung
und Einreihung der Meldung nach einem fehlgeschlagenen Sendeversuch
abzusichern. Zu prüfen sind insbesondere fehlendes Netz, App-Abbruch,
Neustart, Nachsenden und Servereingänge unmittelbar vor sowie ab Fristende.
Für nachgewiesene App- oder Serverstörungen sieht § 7 Absatz 1b des
Entwurfs einen sachgerechten Ausgleich durch Korrektur oder Verlängerung
der Übertragungsfrist nach einheitlichen Maßstäben vor. Störung und
Auswirkung auf den jeweiligen Vorgang müssen nachvollziehbar festgestellt
werden; bloße Behauptungen oder vergessene Check-ins genügen nicht.
Das konkrete Melde- und Prüfverfahren sowie die tatsächlich verfügbaren
Nachweise sind noch festzulegen. Genannte Fehlerprotokolle und Screenshots
sind Beispiele, keine bereits umgesetzte Nachweisfunktion.
Vor einer Ziehung müssen freigegebene Korrekturen und etwaige verlängerte
Fristen im maßgeblichen Datenstand berücksichtigt sein; der Umgang mit
offenen Störungsmeldungen ist noch zu definieren.

§ 8 des Teilnahmebedingungen-Entwurfs legt die Gewinnbenachrichtigung
ausschließlich per E-Mail an die Anmeldeadresse und eine Rückmeldefrist
von 14 Kalendertagen nach Zugang fest. Die Nachricht nennt das konkrete
Fristende und die Folge einer Ablehnung oder ausbleibenden Rückmeldung.
Ersatzgewinner werden anhand desselben maßgeblichen Stempelstands aus
der höchsten verbleibenden Gruppe bislang nicht mit einem Preis
berücksichtigter Personen bestimmt; innerhalb einer Gruppe entscheidet
das Los. Bereits zugeteilte andere Preise bleiben bestehen. Wer einen
Preis ablehnt oder die Rückmeldefrist verstreichen lässt, nimmt an
weiteren Vergaben nicht erneut teil. Ersatzgewinner erhalten ebenfalls
14 Kalendertage zur Rückmeldung. Sind bei der erstmaligen Vergabe oder
nach Ablehnungen bzw. ausgebliebenen fristgerechten Rückmeldungen keine
berücksichtigungsfähigen Personen mehr vorhanden, bleiben die übrigen
Preise unvergeben (§ 7 Absatz 5 und § 8 Absatz 5). Dies gilt auch, wenn
von Anfang an keine berechtigten Teilnehmenden vorhanden sind. Die
Begrenzung auf einen Preis pro Person bleibt bestehen; der Abschluss
mit unvergebenen Preisen ist zu dokumentieren.

Diese Abwicklung ist noch nicht implementiert. Die Abschlussfassung regelt
Fristberechnung, erneute Zustellversuche, einen privaten Adresskorrekturhinweis
in der App und die Reservierung eines Preises bei ungeklärtem Zugang.
Versand allein belegt keinen Zugang. Die praktische Einrichtung einschließlich
Zustell- und Rückmeldenachweisen steht in A07. Zuteilungen, Benachrichtigungen,
Rückmeldungen und Ersatzvergaben müssen für die erforderliche Dauer
nachvollziehbar sein; Löschung und begrenzte Ausnahmen richten sich nach § 13.

Die Kontaktdaten der Verlosung dürfen ausschließlich für deren Durchführung
und Abwicklung verwendet werden. Werbung und Newsletter sowie eine
Weitergabe zu diesen Zwecken sind ausdrücklich ausgeschlossen (§ 13).
Eine Werbeeinwilligung ist nicht vorgesehen. Der bestehende Formulartext
zur Kontaktaufnahme im Gewinnfall ist noch mit sämtlichen notwendigen
Verlosungsnachrichten, insbesondere Störungs- und Fristinformationen,
abzustimmen; Zweck und Rechtsgrundlage bleiben abschließend zu prüfen.

## Historie des kurzen Piloten

Der Pilot vom 15.09.2026 wurde beendet: Die Live-Datei wurde durch die
geschlossene Fassung ersetzt und der Pilot-Eintrag wurde vom Nutzer gesichert
und entfernt. `rollback/raffle_seasons.php` bleibt als nachvollziehbare
Sicherung erhalten. Es gibt keine aktive oder vorbereitete Pilot-Regel.

Die Live-Migration vom 14.09.2026 ordnete 25 Bestandszeilen der Produktion
2026 zu und ersetzte den eindeutigen Installationsindex durch
`UNIQUE (season_id, install_id)`. `analytics_events.season_id` war dabei
bereits vorhanden.
