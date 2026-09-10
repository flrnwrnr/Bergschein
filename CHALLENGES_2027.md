# Bergschein – 12 Challenges für 2027

Stand: 10. September 2026. Gemeinsame Ideensammlung, noch keine finale Auswahl oder technische Umsetzung. Namen sind Arbeitstitel.

## Leitlinien

- Insgesamt 12 Challenges.
- Alle Challenges müssen automatisch durch die App überprüfbar sein; keine manuelle Freigabe oder Gruppenbestätigung.
- Erlebnisse, Entdecken und Rätsel statt ausschließlich einfacher Geo-Check-ins.
- Standort, Kamera und geeignete iPhone-Sensoren kombinieren.

## Bisherige Favoriten

| Nr. | Arbeitstitel | Aufgabe | Automatische Prüfung | Noch zu klären |
| --- | --- | --- | --- | --- |
| 1 | Hoch hinaus | Beim Riesenrad eine vorgegebene Höhe erreichen, um den Check-in freizuschalten. | Standort im Bereich des Riesenrads plus Erreichen eines barometrisch gemessenen Höhenanstiegs gegenüber einer vor dem Einsteigen am Boden gestarteten Referenzmessung. Ein vollständiger Fahrtverlauf oder Abstieg ist nicht erforderlich. | Höhen-Schwelle und Standortradius festlegen; Referenzmessung am Boden im Ablauf vorsehen, Geräteverfügbarkeit und Messrauschen berücksichtigen. Ein Vorabtest am Riesenrad ist nicht möglich, da es noch nicht aufgebaut ist, und wird nicht vorausgesetzt. |
| 2 | Herzenssache | Ein Lebkuchenherz finden und mit der Kamera erfassen. | Objekterkennung im Kamerabild. | Erkennungsverfahren und Zuverlässigkeit testen. Optional ein bestimmtes Wort auf dem Herz erkennen; bisher nur Zusatzidee. |
| 3 | Adlerauge | Das Original zu einem vorgegebenen Bildausschnitt finden. | Kameraabgleich mit vorbereiteten Referenzbildern; Standort kann die Suche eingrenzen. | Geeignete dauerhafte Motive auswählen und bei unterschiedlichen Lichtverhältnissen testen. |
| 4 | Zeitreise | Den Standort und die Perspektive eines historischen Fotos wiederfinden. | Abgleich noch vorhandener Gebäudedetails und ihrer Anordnung im Kamerabild; Standort unterstützt die Prüfung. | Historische Bilder und Nutzungsrechte, stabile Merkmale und passende Toleranzen bestimmen. |
| 5 | Einmal quer über den Berg | Innerhalb eines Zeitfensters vom Anfang der Bergkirchweih bis zum anderen Ende gehen. | Bewusster Start in einer Startzone, laufende Standortmessung, Zwischenzonen und Ankunft in der Zielzone innerhalb des Limits. | Strecke und großzügiges Zeitlimit vor Ort festlegen; GPS-Ungenauigkeit berücksichtigen. Vorschlag: keine Geschwindigkeitsrangliste. |
| 6 | Offen | | | |
| 7 | Offen | | | |
| 8 | Offen | | | |
| 9 | Offen | | | |
| 10 | Offen | | | |
| 11 | Offen | | | |
| 12 | Offen | | | |

## Optionale Variante

**Berg-Express:** Die Bergquerung aus Nr. 5 mit zwei Kameraaufgaben unterwegs kombinieren, beispielsweise Lebkuchenherz und Bildausschnitt. Noch nicht ausgewählt; vorerst keine zusätzliche Challenge und keine Doppelzählung.

## Technische Referenzen

- [Apple: Relative Höhenmessung mit CMAltimeter](https://developer.apple.com/documentation/coremotion/cmaltimeter/startrelativealtitudeupdates(to:withhandler:)) – Grundlage für die Höhen-Schwelle beim Riesenrad; benötigt eine Referenzmessung vor dem Aufstieg.
- [Apple: Standortupdates mit Core Location](https://developer.apple.com/documentation/CoreLocation/monitoring-location-changes-with-core-location) – Grundlage für die Strecken-Challenge.
