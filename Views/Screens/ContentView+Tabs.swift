import MapKit
import SwiftUI

extension ContentView {
    var locationTab: some View {
        CheckInView(
            appBackgroundGradient: appBackgroundGradient,
            statusGradient: statusGradient,
            checkInHeadlineLabel: checkInHeadlineLabel,
            checkInHeadlineValue: checkInHeadlineValue,
            statusForegroundColor: statusForegroundColor,
            claimStatusText: claimStatusText,
            canClaimToday: canClaimToday,
            hasEventEnded: hasEventEnded,
            hasOfficialOpeningStarted: hasOfficialOpeningStarted,
            currentBadgeImageName: currentBadge.flatMap(resolvedImageName(for:)),
            isCurrentBadgeUnlocked: isCurrentBadgeUnlocked,
            stampStatusSymbol: stampStatusSymbol,
            currentStreak: currentStreak,
            darkForest: darkForest,
            locationPermissionWarningText: locationPermissionWarningText,
            isInAllowedRegion: locationController.isInAllowedRegion,
            shouldShowDistanceHint: shouldShowDistanceHint,
            distanceText: locationController.distanceToRegionText,
            directionAngle: locationController.directionAngle,
            currentAdBanner: currentAdBanner,
            isShowingMapsPrompt: $isShowingMapsPrompt,
            onClaimTap: {
                triggerSuccessHaptic()
                claimBadge()
            },
            onOpenMaps: openMapsToRegion
        )
        .onAppear {
            refreshMorningOutsideBannerVariant()
            if !useSimulatedDate {
                syncCurrentDate()
            } else {
                ensureTestEventStartDay()
            }
            evaluateMissedDayNotice()
            syncMapPosition()
            if hasSeenOnboarding {
                locationController.requestLocationAccess()
            }
        }
        .onReceive(clock) { date in
            if useSimulatedDate {
                currentDate = simulatedDate(for: currentDate, usingTimeFrom: date)
            } else {
                currentDate = date
            }
            evaluateMissedDayNotice()
        }
        .onReceive(locationRefreshClock) { _ in
            if hasSeenOnboarding {
                locationController.requestLocationAccess()
            }
        }
        .onChange(of: locationController.activePolygonName) { _, _ in
            syncMapPosition()
        }
        .onChange(of: currentBadge?.id) { _, _ in
            evaluateMissedDayNotice()
        }
        .onChange(of: unlockedBadgeIdentifiers) { _, _ in
            evaluateMissedDayNotice()
        }
    }

    var badgesTab: some View {
        BergscheinView(
            appBackgroundGradient: appBackgroundGradient,
            badgeDefinitions: badgeDefinitions,
            unlockedBadges: unlockedBadges,
            blockingMissedBadge: blockingMissedBadge,
            dismissedMissedBadgeIdentifier: dismissedMissedBadgeIdentifier,
            darkForest: darkForest,
            overlayPresentationAnimation: overlayPresentationAnimation,
            standardBadges: standardBadges(in:),
            featuredBadge: featuredBadge(in:),
            resolvedImageName: resolvedImageName(for:),
            onMissedBadgeTap: { blockedBadge in
                activeMissedDayAlert = MissedDayAlertPresentation(missedBadge: blockedBadge)
            },
            onBadgeTap: { badge in
                activeBadgeOverlay = BadgeOverlayPresentation(
                    badge: badge,
                    title: badge.overlayTitle,
                    buttonTitle: "Schließen",
                    switchesToBadgeTab: false
                )
            },
            onShareTap: {
                if let shareImage = makeBergscheinShareImage() {
                    activeBadgeShareSheet = BadgeShareSheetItem(image: shareImage)
                }
            }
        )
    }

    var settingsTab: some View {
        NavigationStack {
            ZStack {
                appBackgroundGradient
                    .ignoresSafeArea()

                List {
                    Section("Einstellungen") {
                        Toggle(isOn: $hapticsEnabled) {
                            Label("Haptisches Feedback", systemImage: "hand.tap")
                        }

                        Toggle(isOn: $notificationsEnabled) {
                            Label("Benachrichtigungen", systemImage: "bell")
                        }
                        .disabled(!notificationsAreSystemAuthorized)

                        if !notificationsAreSystemAuthorized {
                            Text("Benachrichtigungen sind in den Systemeinstellungen für diese App deaktiviert.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if notificationsEnabled {
                            Toggle(isOn: $stampNotificationsEnabled) {
                                Label("Stempel-Benachrichtigungen", systemImage: "rosette")
                            }

                            Toggle(isOn: $challengeNotificationsEnabled) {
                                Label("Challenge-Benachrichtigungen", systemImage: "location.magnifyingglass")
                            }
                        }
                    }

                    Section("Unterstützung") {
                        Button {
                            if let subject = "Feedback".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                               let url = URL(string: "mailto:kontakt@derbergschein.de?subject=\(subject)") {
                                openURL(url)
                            }
                        } label: {
                            Label("Feedback", systemImage: "bubble.left.and.bubble.right")
                        }
                        .tint(.primary)

                        Button {
                            settingsRoute = .tips
                        } label: {
                            Label("Trinkgeld", systemImage: "heart")
                        }
                        .tint(.primary)

                        ShareLink(item: URL(string: "https://derbergschein.de")!) {
                            Label("Teilen", systemImage: "square.and.arrow.up")
                        }
                        .tint(.primary)
                    }

                    Section("Sonstiges") {
                        Button {
                            settingsRoute = .changeLog
                        } label: {
                            HStack {
                                Label("Change Log", systemImage: "list.bullet.clipboard")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .tint(.primary)

                        Button {
                            settingsRoute = .raffle
                        } label: {
                            HStack {
                                Label("Verlosung", systemImage: "ticket")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .tint(.primary)

                        Button {
                            openURL(URL(string: "https://derbergschein.de")!)
                        } label: {
                            Label("Webseite", systemImage: "globe")
                        }
                        .tint(.primary)

                        Button {
                            settingsRoute = .credits
                        } label: {
                            HStack {
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: "info.circle.fill")
                                    Text("Entwickelt von FFWD Ventures")
                                }
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    if isDebugMenuUnlocked {
                        Section("Status") {
                            LabeledContent {
                                Text(formattedCurrentDate)
                            } label: {
                                Label("Datum und Uhrzeit", systemImage: "calendar")
                            }
                            LabeledContent {
                                Text(locationController.isInAllowedRegion ? "In Region" : "Außerhalb")
                            } label: {
                                Label("Region", systemImage: "location")
                            }
                            LabeledContent {
                                Text("\(unlockedBadges.count) / \(badgeDefinitions.count)")
                            } label: {
                                Label("Freigeschaltet", systemImage: "rosette")
                            }
                            LabeledContent {
                                Text(currentBadgeLabel)
                            } label: {
                                Label("Heutiger Tag", systemImage: "seal")
                            }
                        }

                        Section("Tests") {
                            Button {
                                triggerSelectionHaptic()
                                goToNextDay()
                            } label: {
                                Label("Zum nächsten Tag", systemImage: "forward.fill")
                            }

                            Button {
                                triggerSelectionHaptic()
                                locationController.toggleTestPolygon()
                            } label: {
                                Label("Region wechseln", systemImage: "map")
                            }

                            LabeledContent {
                                Text(locationController.activePolygonName)
                            } label: {
                                Label("Testpolygon", systemImage: "point.3.connected.trianglepath.dotted")
                            }

                            Picker("Banner-Slot", selection: $adSlotOverride) {
                                ForEach(AdSlotOverride.allCases) { slot in
                                    Text(slot.rawValue).tag(slot)
                                }
                            }

                            Button {
                                triggerSelectionHaptic()
                                refreshMorningOutsideBannerVariant()
                            } label: {
                                Label("Banner neu würfeln", systemImage: "arrow.triangle.2.circlepath")
                            }

                            Button(role: .destructive) {
                                triggerWarningHaptic()
                                deactivateTestMode()
                            } label: {
                                Label("Testmodus deaktivieren", systemImage: "xmark.circle")
                            }
                        }

                        Section("Testregion auf Karte") {
                            Map(position: $mapPosition) {
                                MapPolygon(coordinates: locationController.activePolygon)
                                    .foregroundStyle(.green.opacity(0.2))
                                    .stroke(.green, lineWidth: 3)
                            }
                            .frame(height: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        Section("Testdaten") {
                            Button(role: .destructive) {
                                triggerWarningHaptic()
                                resetProgress()
                            } label: {
                                Label("Fortschritt zurücksetzen", systemImage: "arrow.counterclockwise")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Mehr")
            .navigationDestination(item: $settingsRoute) { route in
                switch route {
                case .changeLog:
                    changelogView
                case .credits:
                    creditsView
                case .raffle:
                    raffleView
                case .tips:
                    tipJarView
                }
            }
        }
    }

    var changelogView: some View {
        ChangeLogView(backgroundGradient: appBackgroundGradient)
    }

    var tipJarView: some View {
        TipJarView(
            backgroundGradient: appBackgroundGradient,
            darkForest: darkForest,
            tipJarStore: tipJarStore,
            overlayDismissAnimation: overlayDismissAnimation,
            onTipSuccess: triggerSuccessHaptic
        )
    }

    var creditsView: some View {
        CreditsView(
            backgroundGradient: appBackgroundGradient,
            onLogoTap: handleFFWDLogoTap
        )
    }

    var raffleView: some View {
        ScrollView {
            Text(raffleTermsText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .padding(.bottom, 24)
        }
        .navigationTitle("Verlosung")
    }

    var raffleTermsText: String {
        """
        Teilnahmebedingungen Verlosung „Der Bergschein“
        Stand: 02.04.2026

        ⸻

        1. Veranstalter

        Veranstalter der Verlosung ist:
        FFWD Florian Werner Digital Ventures
        Florian Werner
        Marquardsenstraße 4
        91054 Erlangen
        E-Mail: kontakt@derbergschein.de

        ⸻

        2. Gegenstand der Verlosung

        (1) Der Veranstalter führt eine unentgeltliche Verlosung innerhalb der App „Der Bergschein“ durch.
        (2) Verlost werden die in der App konkret benannten Preise.
        (3) Die Verlosung dient ausschließlich der App-Aktivierung und ist kein Glücksspiel mit Entgelt.

        ⸻

        3. Teilnahmezeitraum

        Die Teilnahme ist nur im in der App angegebenen Zeitraum möglich.

        ⸻

        4. Teilnahmeberechtigung

        (1) Teilnahmeberechtigt sind natürliche Personen ab 18 Jahren mit Wohnsitz in Deutschland.
        (2) Mitarbeitende des Veranstalters sowie deren Angehörige sind ausgeschlossen.
        (3) Der Veranstalter kann einen Alters- und Identitätsnachweis verlangen.

        ⸻

        5. Kostenfreie Teilnahme / Kein Kaufzwang

        (1) Die Nutzung der App sowie das Sammeln von Check-ins ist kostenlos.
        (2) Ein Kauf, eine Zahlung oder sonstige entgeltliche Leistung ist nicht erforderlich und erhöht weder die Teilnahme- noch die Gewinnchance.

        ⸻

        6. Teilnahmehandlung

        (1) Die Teilnahme an der Verlosung setzt voraus, dass die teilnehmende Person innerhalb der App den Teilnahmebedingungen ausdrücklich zustimmt.
        (2) Die bloße Nutzung der App oder das Sammeln von Check-ins begründet noch keine Teilnahme an der Verlosung.
        (3) Maßgeblich für die Teilnahme an der Verlosung ist ausschließlich die Einordnung gemäß § 7.

        ⸻

        7. Teilnahme an der Verlosung und Gewinnerermittlung

        (1) Die Teilnahme an der Verlosung erfolgt in Teilnahmegruppen, die sich nach der Anzahl der innerhalb des Teilnahmezeitraums erreichten gültigen Check-ins (Bergtage) richten. Die Anzahl der Check-ins dient ausschließlich der Zuordnung zu diesen Teilnahmegruppen und stellt keine Bewertung von Leistung, Geschick oder Können dar.

        (2) Haben eine oder mehrere Personen alle Bergtage erfolgreich eingecheckt („großer Bergschein“), wird die Verlosung ausschließlich unter diesen Personen durchgeführt.

        (3) Gibt es keine Person mit Check-ins an allen Bergtagen, wird die Verlosung unter denjenigen Teilnehmenden mit der jeweils nächstniedrigeren Check-in-Anzahl durchgeführt.

        (4) Die Auswahl der Gewinner erfolgt innerhalb der jeweiligen Teilnahmegruppe ausschließlich durch ein Zufallsverfahren (Losentscheid).

        (5) Die Check-ins begründen keinen Wettbewerb zwischen Teilnehmenden und führen nicht zu unterschiedlichen Gewinnchancen innerhalb der jeweiligen Teilnahmegruppe.

        (6) Challenges, Aufgabeninhalte oder sonstige In-App-Aktivitäten haben keinen Einfluss auf die Teilnahme an der Verlosung oder die Gewinnchance innerhalb der teilnahmeberechtigten Gruppe.

        (7) Die Gewinnchance innerhalb der zur Verlosung zugelassenen Gruppe ist für alle Teilnehmenden gleich.

        (8) Die Gewinnchance ist nicht vom Konsum alkoholischer Getränke abhängig.

        (9) Ziel der Gruppeneinteilung ist ausschließlich die Strukturierung der Verlosung, nicht die Förderung oder Bewertung individueller Leistungen.

        ⸻

        8. Gewinnbenachrichtigung und Verfall

        (1) Die Gewinner werden per In-App-Mitteilung und/oder E-Mail benachrichtigt.
        (2) Meldet sich ein Gewinner nicht innerhalb von 7 Kalendertagen nach Benachrichtigung zurück, verfällt der Gewinnanspruch; es kann ein Ersatzgewinner ermittelt werden.

        ⸻

        9. Sicherheits- und Verhaltensregeln

        (1) Die App und Verlosung fordern weder unmittelbar noch mittelbar zu riskantem Verhalten auf.
        (2) Es besteht kein Zwang, an Challenges teilzunehmen oder sich körperlich zu verausgaben.
        (3) Eine Teilnahme während des Führens von Fahrzeugen oder in sonstigen Gefahrensituationen ist untersagt.
        (4) Teilnehmende handeln jederzeit eigenverantwortlich und haben geltende Gesetze (insbesondere Straßenverkehrs- und Jugendschutzrecht) einzuhalten.

        ⸻

        10. Ausschluss von Teilnehmenden

        Der Veranstalter kann Personen bei Verstößen gegen diese Bedingungen, bei Manipulationsversuchen, Mehrfachkonten, falschen Angaben oder sonstigem Missbrauch von der Teilnahme ausschließen und Gewinne aberkennen.

        ⸻

        11. Änderung, Unterbrechung, Beendigung

        Der Veranstalter kann die Verlosung aus wichtigem Grund (z. B. technische Störungen, Missbrauch, rechtliche Gründe, behördliche Anordnungen oder wenn eine ordnungsgemäße Durchführung wirtschaftlich oder organisatorisch nicht mehr gewährleistet werden kann) ganz oder teilweise ändern, aussetzen oder beenden, sofern dies erforderlich ist und die Teilnehmenden hierdurch nicht unangemessen benachteiligt werden.

        ⸻

        12. Haftung

        (1) Der Veranstalter haftet unbeschränkt bei Vorsatz und grober Fahrlässigkeit, bei Verletzung von Leben, Körper oder Gesundheit sowie nach zwingenden gesetzlichen Vorschriften.
        (2) Bei leicht fahrlässiger Verletzung wesentlicher Vertragspflichten ist die Haftung auf den vertragstypischen, vorhersehbaren Schaden begrenzt.
        (3) Im Übrigen ist die Haftung des Veranstalters ausgeschlossen.
        (4) Soweit die Haftung ausgeschlossen oder beschränkt ist, gilt dies auch zugunsten von gesetzlichen Vertretern, Mitarbeitenden und Erfüllungsgehilfen des Veranstalters.

        ⸻

        13. Freistellung

        Teilnehmende stellen den Veranstalter im gesetzlich zulässigen Umfang von Ansprüchen Dritter frei, die aus schuldhaften Verstößen der Teilnehmenden gegen diese Teilnahmebedingungen oder gegen geltendes Recht resultieren, einschließlich angemessener Kosten der Rechtsverteidigung.

        ⸻

        14. Datenschutz

        (1) Verantwortlich: FFWD Florian Werner Digital Ventures, Kontakt: kontakt@derbergschein.de
        (2) Verarbeitete Daten: insbesondere Nutzer-ID, Check-in-Status, Kontaktdaten, Zustimmungszeitpunkt sowie Daten zur Gewinnabwicklung.
        (3) Zweck: Durchführung und Abwicklung der Verlosung sowie Missbrauchsverhinderung.
        (4) Rechtsgrundlagen: Art. 6 Abs. 1 lit. b DSGVO sowie Art. 6 Abs. 1 lit. f DSGVO.
        (5) Im Falle eines Gewinns können personenbezogene Daten an Dienstleister (z. B. Versanddienstleister) weitergegeben werden, soweit dies zur Abwicklung erforderlich ist.
        (6) Speicherdauer: nur solange erforderlich; danach Löschung, soweit keine gesetzlichen Aufbewahrungspflichten bestehen.
        (7) Betroffenenrechte (Auskunft, Berichtigung, Löschung usw.) können über kontakt@derbergschein.de geltend gemacht werden.
        (8) Ergänzend gilt die Datenschutzerklärung der App/Website.

        ⸻

        15. Apple-Hinweis

        Diese Verlosung steht in keiner Verbindung zu Apple und wird in keiner Weise von Apple gesponsert, unterstützt oder organisiert. Apple ist nicht Ansprechpartner für die Verlosung.

        ⸻

        16. Schlussbestimmungen

        (1) Es gilt deutsches Recht unter Ausschluss des UN-Kaufrechts.
        (2) Der Rechtsweg ist hinsichtlich der Gewinnentscheidung ausgeschlossen, soweit gesetzlich zulässig.
        (3) Sollten einzelne Bestimmungen unwirksam sein oder werden, bleibt die Wirksamkeit der übrigen Bestimmungen unberührt.

        ⸻
        """
    }

    var challengeTab: some View {
        ChallengeView(
            appBackgroundGradient: appBackgroundGradient,
            darkForest: darkForest,
            hasChallengeSeasonEnded: hasChallengeSeasonEnded,
            activeChallenge: activeChallenge,
            completedChallengesCount: completedChallengesCount,
            totalChallengesCount: totalChallengesCount,
            shouldShowChallengeButton: shouldShowChallengeButton,
            activeChallengeButtonTitle: activeChallengeButtonTitle,
            canCheckInForActiveChallenge: canCheckInForActiveChallenge,
            challengeStatusText: challengeStatusText,
            isChallengeCompleted: isChallengeCompleted(_:),
            isWithinChallengeRadius: isWithinChallengeRadius(_:),
            challengeDistanceText: challengeDistanceText(for:),
            challengeDirectionAngle: challengeDirectionAngle(for:),
            unlockedChallengeRewards: unlockedChallengeRewards,
            isChallengeRewardRedeemed: isChallengeRewardRedeemed,
            onLocationTap: { challenge in
                challengeMapsDestination = challenge
            },
            onClaimChallenge: claimActiveChallenge,
            onRedeemChallengeReward: redeemChallengeReward,
            challengeMapsAlertIsPresented: challengeMapsAlertBinding,
            onConfirmOpenMaps: {
                if let challengeMapsDestination {
                    openMapsToChallengeLocation(challengeMapsDestination)
                }
                challengeMapsDestination = nil
            },
            onDismissOpenMaps: {
                challengeMapsDestination = nil
            }
        )
    }

    var onboardingBinding: Binding<Bool> {
        Binding(
            get: { !hasSeenOnboarding },
            set: { isPresented in
                if !isPresented {
                    hasSeenOnboarding = true
                    locationController.requestLocationAccess()
                }
            }
        )
    }

    var challengeMapsAlertBinding: Binding<Bool> {
        Binding(
            get: { challengeMapsDestination != nil },
            set: { isPresented in
                if !isPresented {
                    challengeMapsDestination = nil
                }
            }
        )
    }
}
