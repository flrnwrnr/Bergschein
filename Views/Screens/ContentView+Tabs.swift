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
