//
//  ContentView.swift
//  Bergschein
//
//  Created by Florian Werner on 20.03.26.
//

import Combine
import CoreLocation
import MapKit
import SwiftUI
import UIKit
import UserNotifications

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    private enum AppTab: Hashable {
        case checkIn
        case bergschein
        case challenge
        case mehr
    }

    private enum SettingsRoute: Hashable, Identifiable {
        case changeLog
        case credits
        case tips

        var id: Self { self }
    }

    private enum MorningOutsideBannerVariant {
        case ffwd
        case ching
        case tb
    }

    private enum AdSlotOverride: String, CaseIterable, Identifiable {
        case automatic = "Automatisch"
        case morning = "06:00–15:00"
        case afternoon = "15:00–23:00"
        case overnight = "23:00–06:00"

        var id: String { rawValue }
    }

    private let claimStartHour = 10
    private let claimEndHour = 23
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let locationRefreshClock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    private let badgeDefinitions = BadgeDefinition.all
    private let challengeDefinitions = DailyChallenge.all
    private let overlayPresentationAnimation = Animation.spring(response: 0.42, dampingFraction: 0.82)
    private let overlayDismissAnimation = Animation.easeInOut(duration: 0.22)

    @StateObject private var locationController = LocationController()
    @StateObject private var tipJarStore = TipJarStore()
    @AppStorage("unlockedBadgeIdentifiers") private var unlockedBadgeIdentifiers = ""
    @AppStorage("completedChallengeIdentifiers") private var completedChallengeIdentifiers = ""
    @AppStorage("testEventStartDay") private var testEventStartDay = ""
    @AppStorage("dismissedMissedBadgeIdentifier") private var dismissedMissedBadgeIdentifier = ""
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("isDebugMenuUnlocked") private var isDebugMenuUnlocked = false
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("stampNotificationsEnabled") private var stampNotificationsEnabled = true
    @AppStorage("challengeNotificationsEnabled") private var challengeNotificationsEnabled = true
    @State private var activeBadgeOverlay: BadgeOverlayPresentation?
    @State private var activeChallengeOverlay: ChallengeOverlayPresentation?
    @State private var activeMissedDayAlert: MissedDayAlertPresentation?
    @State private var activeBadgeShareSheet: BadgeShareSheetItem?
    @State private var currentDate = Date()
    @State private var useSimulatedDate = false
    @State private var mapPosition = MapCameraPosition.automatic
    @State private var selectedTab: AppTab = .checkIn
    @State private var settingsRoute: SettingsRoute?
    @State private var isShowingMapsPrompt = false
    @State private var challengeMapsDestination: DailyChallenge?
    @State private var notificationsAreSystemAuthorized = true
    @State private var onboardingSelection = 0
    @State private var morningOutsideBannerVariant: MorningOutsideBannerVariant = .ffwd
    @State private var adSlotOverride: AdSlotOverride = .automatic
    @State private var ffwdLogoTapCount = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            locationTab
                .tag(AppTab.checkIn)
                .tabItem {
                    Label("Check-in", systemImage: "location.fill")
                }

            badgesTab
                .tag(AppTab.bergschein)
                .tabItem {
                    Label("Bergschein", systemImage: "rosette")
                }

            challengeTab
                .tag(AppTab.challenge)
                .tabItem {
                    Label("Challenge", systemImage: "location.magnifyingglass")
                }

            settingsTab
                .tag(AppTab.mehr)
                .tabItem {
                    Label("Mehr", systemImage: "ellipsis")
                }
        }
        .fontDesign(.rounded)
        .onChange(of: selectedTab) { _, _ in
            if selectedTab == .checkIn {
                refreshMorningOutsideBannerVariant()
                if hasSeenOnboarding {
                    locationController.requestLocationAccess()
                }
            }
            triggerSelectionHaptic()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                if selectedTab == .checkIn {
                    refreshMorningOutsideBannerVariant()
                }
                if hasSeenOnboarding {
                    locationController.requestLocationAccess()
                }
                refreshNotificationAuthorizationState()
                applyPendingNotificationDestinationIfNeeded()
                refreshScheduledNotifications()
            }
        }
        .onChange(of: hasSeenOnboarding) { _, hasSeenOnboarding in
            if hasSeenOnboarding {
                refreshScheduledNotifications()
            }
        }
        .onChange(of: unlockedBadgeIdentifiers) { _, _ in
            refreshScheduledNotifications()
        }
        .onChange(of: notificationsEnabled) { _, isEnabled in
            if isEnabled {
                stampNotificationsEnabled = true
                challengeNotificationsEnabled = true
            } else {
                stampNotificationsEnabled = false
                challengeNotificationsEnabled = false
            }
            refreshScheduledNotifications()
        }
        .onChange(of: stampNotificationsEnabled) { _, isEnabled in
            if isEnabled && !notificationsEnabled {
                notificationsEnabled = true
            } else if !isEnabled && !challengeNotificationsEnabled {
                notificationsEnabled = false
            } else {
                refreshScheduledNotifications()
            }
        }
        .onChange(of: challengeNotificationsEnabled) { _, isEnabled in
            if isEnabled && !notificationsEnabled {
                notificationsEnabled = true
            } else if !isEnabled && !stampNotificationsEnabled {
                notificationsEnabled = false
            } else {
                refreshScheduledNotifications()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .bergscheinOpenNotificationDestination)) { notification in
            guard let destination = notification.object as? NotificationDestination else {
                return
            }
            openNotificationDestination(destination)
        }
        .overlay {
            if let activeBadgeOverlay {
                BadgeOverlayView(
                    presentation: activeBadgeOverlay,
                    imageName: resolvedImageName(for: activeBadgeOverlay.badge),
                    darkForest: darkForest,
                    onShare: {
                        let imageName = resolvedImageName(for: activeBadgeOverlay.badge)
                        if let shareImage = makeBadgeShareImage(for: activeBadgeOverlay, imageName: imageName) {
                            activeBadgeShareSheet = BadgeShareSheetItem(image: shareImage)
                        }
                    },
                    onDismiss: {
                        withAnimation(overlayDismissAnimation) {
                            if activeBadgeOverlay.switchesToBadgeTab {
                                selectedTab = .bergschein
                            }
                            self.activeBadgeOverlay = nil
                        }
                    }
                )
            } else if let activeChallengeOverlay {
                ChallengeOverlayView(
                    presentation: activeChallengeOverlay,
                    darkForest: darkForest,
                    onDismiss: {
                        withAnimation(overlayDismissAnimation) {
                            self.activeChallengeOverlay = nil
                        }
                    }
                )
            } else if let activeMissedDayAlert {
                MissedDayOverlayView(
                    presentation: activeMissedDayAlert,
                    darkForest: darkForest,
                    onDismiss: {
                        withAnimation(overlayDismissAnimation) {
                            dismissedMissedBadgeIdentifier = activeMissedDayAlert.missedBadge.id
                            self.activeMissedDayAlert = nil
                        }
                    }
                )
            }
        }
        .fullScreenCover(isPresented: onboardingBinding) {
            onboardingView
        }
        .sheet(item: $activeBadgeShareSheet) { shareItem in
            ActivityShareSheet(activityItems: [shareItem.image])
        }
        .onAppear {
            refreshNotificationAuthorizationState()
            applyPendingNotificationDestinationIfNeeded()
            refreshScheduledNotifications()
        }
    }

    private var locationTab: some View {
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

    private var badgesTab: some View {
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

    private var settingsTab: some View {
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

//                        Button {
//                        } label: {
//                            Label("Bewerten", systemImage: "star")
//                        }
//                        .tint(.primary)

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

    private var changelogView: some View {
        ChangeLogView(backgroundGradient: appBackgroundGradient)
    }

    private var tipJarView: some View {
        TipJarView(
            backgroundGradient: appBackgroundGradient,
            darkForest: darkForest,
            tipJarStore: tipJarStore,
            overlayDismissAnimation: overlayDismissAnimation,
            onTipSuccess: triggerSuccessHaptic
        )
    }

    private var creditsView: some View {
        CreditsView(
            backgroundGradient: appBackgroundGradient,
            onLogoTap: handleFFWDLogoTap
        )
    }

    private var challengeTab: some View {
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
            onLocationTap: { challenge in
                challengeMapsDestination = challenge
            },
            onClaimChallenge: claimActiveChallenge,
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

    private var onboardingBinding: Binding<Bool> {
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

    private var challengeMapsAlertBinding: Binding<Bool> {
        Binding(
            get: { challengeMapsDestination != nil },
            set: { isPresented in
                if !isPresented {
                    challengeMapsDestination = nil
                }
            }
        )
    }

    private var onboardingView: some View {
        let pages = onboardingPages

        return ZStack {
            LinearGradient(
                colors: onboardingBackgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                TabView(selection: $onboardingSelection) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: 24) {
                            VStack {
                                Image("AppIconPreview")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                    .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
                            }
                            .frame(height: 96, alignment: .top)

                            Spacer()

                            if page.usesEmojiIcon {
                                Text(page.icon)
                                    .font(.system(size: 88))
                            } else {
                                Image(systemName: page.icon)
                                    .font(.system(size: 68, weight: .bold))
                                    .foregroundStyle(Color.accentColor)
                            }

                            Text(page.title)
                                .font(.custom(BrandFont.primaryName, size: 34))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(darkForest)

                            Text(page.text)
                                .font(.title3)
                                .fontDesign(.rounded)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 24)

                            if page.requiresLocationAuthorization {
                                Button {
                                    locationController.requestAccessForOnboarding()
                                } label: {
                                    Label(
                                        locationController.hasLocationAccess ? "Zugelassen" : "Zulassen",
                                        systemImage: locationController.hasLocationAccess ? "checkmark" : "location.fill"
                                    )
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .font(.headline.weight(.bold))
                                .disabled(locationController.hasLocationAccess)
                            }

                            Spacer()
                        }
                        .padding(24)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .gesture(
                    DragGesture().onEnded { value in
                        let isLocationPage = onboardingSelection == 1
                        let wantsToAdvance = value.translation.width < -40

                        if isLocationPage && wantsToAdvance && !locationController.hasLocationAccess {
                            onboardingSelection = 1
                        }
                    }
                )
                .onChange(of: onboardingSelection) { _, newValue in
                    if newValue > 1 && !locationController.hasLocationAccess {
                        onboardingSelection = 1
                    }
                }
                .onChange(of: locationController.authorizationStatus) { _, _ in
                    if onboardingSelection == 1 && locationController.hasLocationAccess {
                        triggerSelectionHaptic()
                    }
                }

                Button(onboardingSelection == pages.count - 1 ? "Los geht’s" : "Weiter") {
                    if onboardingSelection == pages.count - 1 {
                        hasSeenOnboarding = true
                        locationController.requestLocationAccess()
                    } else {
                        if onboardingSelection == 1 && !locationController.hasLocationAccess {
                            locationController.requestAccessForOnboarding()
                            return
                        }
                        onboardingSelection += 1
                        triggerSelectionHaptic()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(.headline.weight(.bold))
                .disabled(onboardingSelection == 1 && !locationController.hasLocationAccess)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    private var onboardingPages: [OnboardingPage] {
        [
            OnboardingPage(
                icon: "🍻",
                title: "Der Bergschein ist zurück!",
                text: "Hol dir für jeden Tag deinen Stempel am Berg ab und mach den großen Bergschein."
            ),
            OnboardingPage(
                icon: "location.fill",
                title: "Standort-\nzugriff ist nötig",
                text: "Die App prüft deinen Standort, da der Check-in nur direkt am Berg möglich ist.",
                requiresLocationAuthorization: true
            ),
            OnboardingPage(
                icon: "checkmark.shield.fill",
                title: "Einfach und kostenlos",
                text: "Die App ist kostenlos, benötigt keinen Account und speichert keine persönlichen Daten. Was will man mehr?"
            )
        ]
    }

    private var statusGradient: LinearGradient {
        LinearGradient(
            colors: statusGradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var appBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: appBackgroundColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var currentAdBanner: AdBanner {
        let slot = currentAdSlot
        let isSpecialDay = isWeekendOrSpecialBannerDay
        let isInsideRegion = locationController.isInAllowedRegion

        switch (isInsideRegion, isSpecialDay, slot) {
        case (_, _, .automatic):
            return .ffwd
        case (false, _, .morning):
            switch morningOutsideBannerVariant {
            case .ffwd:
                return .ffwd
            case .ching:
                return .ching
            case .tb:
                return .tb
            }
        case (false, _, .afternoon):
            switch morningOutsideBannerVariant {
            case .ffwd:
                return .ffwd
            case .ching:
                return .ching
            case .tb:
                return .tb
            }
        case (false, _, .overnight):
            return .zirkel
        case (true, false, .morning):
            return .ffwd
        case (true, false, .afternoon):
            return .erich
        case (true, false, .overnight):
            return .zirkel
        case (true, true, .morning), (true, true, .afternoon):
            return .erich
        case (true, true, .overnight):
            return .zirkel
        }
    }

    private var currentAdSlot: AdSlotOverride {
        switch adSlotOverride {
        case .automatic:
            break
        case .morning, .afternoon, .overnight:
            return adSlotOverride
        }

        let hour = Calendar.current.component(.hour, from: currentDate)
        if hour >= 6 && hour < 15 {
            return .morning
        }
        if hour >= 15 && hour < 23 {
            return .afternoon
        }
        return .overnight
    }

    private var isWeekendOrSpecialBannerDay: Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: currentDate)
        let month = calendar.component(.month, from: currentDate)
        let day = calendar.component(.day, from: currentDate)

        let isWeekend = weekday == 1 || weekday == 7
        let isSpecialDate = month == 5 && day == 25

        return isWeekend || isSpecialDate
    }

    private func refreshMorningOutsideBannerVariant() {
        guard (currentAdSlot == .morning || currentAdSlot == .afternoon), !locationController.isInAllowedRegion else {
            morningOutsideBannerVariant = .ffwd
            return
        }

        let randomValue = Int.random(in: 1...10)
        switch randomValue {
        case 1...4:
            morningOutsideBannerVariant = .ffwd
        case 5...8:
            morningOutsideBannerVariant = .ching
        default:
            morningOutsideBannerVariant = .tb
        }
    }

    private func handleFFWDLogoTap() {
        guard !isDebugMenuUnlocked else { return }

        ffwdLogoTapCount += 1
        if ffwdLogoTapCount >= 10 {
            isDebugMenuUnlocked = true
            ffwdLogoTapCount = 0
            triggerSuccessHaptic()
        }
    }

    private var darkForest: Color {
        colorScheme == .dark ? Color(uiColor: .label) : Color(red: 0.169, green: 0.227, blue: 0.184)
    }

    private var appBackgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(uiColor: .systemBackground),
                Color.accentColor.opacity(0.14),
                Color(uiColor: .secondarySystemBackground)
            ]
        }

        return [Color(.systemGray6), Color.accentColor.opacity(0.10)]
    }

    private var onboardingBackgroundColors: [Color] {
        if colorScheme == .dark {
            return [
                Color(uiColor: .systemBackground),
                Color.accentColor.opacity(0.22),
                Color(uiColor: .secondarySystemBackground)
            ]
        }

        return [Color(.systemGray6), Color.accentColor.opacity(0.18)]
    }

    private var completedChallenges: Set<String> {
        Set(
            completedChallengeIdentifiers
                .split(separator: ",")
                .map(String.init)
        )
    }

    private var completedChallengesCount: Int {
        challengeDefinitions.filter { completedChallenges.contains($0.id) }.count
    }

    private var totalChallengesCount: Int {
        challengeDefinitions.count
    }

    private var activeChallenge: DailyChallenge? {
        guard let firstChallenge = challengeDefinitions.first else {
            return nil
        }

        let currentDay = Calendar.current.startOfDay(for: currentDate)
        let firstChallengeDay = Calendar.current.startOfDay(for: firstChallenge.date)

        if currentDay < firstChallengeDay {
            return firstChallenge
        }

        if let overnightChallenge = challengeDefinitions.first(where: { challenge in
            guard challenge.spansMidnight, let startDate = challenge.startDate, let endDate = challenge.endDate else {
                return false
            }

            return currentDate >= startDate && currentDate <= endDate
        }) {
            return overnightChallenge
        }

        return challengeDefinitions.first {
            Calendar.current.isDate($0.date, inSameDayAs: currentDate)
        }
    }

    private var canCheckInForActiveChallenge: Bool {
        guard let activeChallenge else {
            return false
        }

        guard activeChallenge.requiresLocationCheckIn,
              Calendar.current.isDate(activeChallenge.date, inSameDayAs: currentDate),
              !isChallengeCompleted(activeChallenge),
              isWithinChallengeWindow(activeChallenge),
              isWithinChallengeRadius(activeChallenge) else {
            return false
        }

        return true
    }

    private var shouldShowChallengeButton: Bool {
        guard let activeChallenge else {
            return false
        }

        return activeChallenge.requiresLocationCheckIn && !isChallengeCompleted(activeChallenge)
    }

    private var activeChallengeButtonTitle: String {
        "Abhaken"
    }

    private var challengeStatusText: String {
        guard let activeChallenge else {
            return "Für heute gibt es keine Challenge mehr."
        }

        if isChallengeCompleted(activeChallenge) {
            return "Challenge für heute erledigt."
        }

        let currentDay = Calendar.current.startOfDay(for: currentDate)
        let challengeDay = Calendar.current.startOfDay(for: activeChallenge.date)

        if currentDay < challengeDay {
            return ""
        }

        if !activeChallenge.requiresLocationCheckIn {
            return "Ort und Details werden an diesem Tag freigeschaltet."
        }

        if !isWithinChallengeWindow(activeChallenge) {
            return ""
        }

        if !isWithinChallengeRadius(activeChallenge) {
            return "Du musst dich für den Check-in im markierten Bereich befinden."
        }

        return "Du bist im Zeitfenster und am richtigen Ort. Jetzt kannst du einchecken."
    }

    private var statusGradientColors: [Color] {
        if hasEventEnded {
            return [
                Color(.systemGray5),
                Color(.systemGray4)
            ]
        }
        if !hasOfficialOpeningStarted {
            return [
                Color(.systemGray5),
                Color.accentColor.opacity(0.18)
            ]
        }
        if isCurrentBadgeUnlocked {
            return [Color(red: 0.12, green: 0.39, blue: 0.19), Color(red: 0.24, green: 0.60, blue: 0.31)]
        }
        if !locationController.isInAllowedRegion {
            return [Color(red: 0.72, green: 0.24, blue: 0.22), Color(red: 0.86, green: 0.42, blue: 0.32)]
        }
        return [
            Color(.systemGray5),
            Color.accentColor.opacity(0.18)
        ]
    }

    private var cardGradientBaseColor: Color {
        if isCurrentBadgeUnlocked {
            return statusGradientColors.first ?? .accentColor
        }
        if !locationController.isInAllowedRegion {
            return statusGradientColors.first ?? .red
        }
        return .accentColor
    }

    private var statusForegroundColor: Color {
        if hasEventEnded {
            return darkForest
        }
        if !hasOfficialOpeningStarted {
            return darkForest
        }
        if isCurrentBadgeUnlocked || !locationController.isInAllowedRegion {
            return .white
        }
        return darkForest
    }

    private var stampStatusSymbol: String {
        if hasEventEnded {
            return "moon.zzz.fill"
        }
        if !hasOfficialOpeningStarted {
            return "timer"
        }
        if isCurrentBadgeUnlocked {
            return "checkmark.seal.fill"
        }
        if canClaimToday {
            return "seal.fill"
        }
        return "mountain.2.fill"
    }

    private var stampStatusColor: Color {
        if isCurrentBadgeUnlocked {
            return .accentColor
        }
        if canClaimToday {
            return .accentColor
        }
        return .secondary
    }

    private var shouldShowDistanceHint: Bool {
        !locationController.isInAllowedRegion || locationController.distanceToRegionMeters.map { $0 > 50 } == true
    }

    private var locationPermissionWarningText: String? {
        guard locationController.authorizationStatus == .denied || locationController.authorizationStatus == .restricted else {
            return nil
        }
        return "Standortzugriff fehlt. Bitte aktiviere ihn in den Einstellungen, damit du am Berg einchecken kannst."
    }

    private var canClaimToday: Bool {
        !hasEventEnded &&
        hasOfficialOpeningStarted &&
        locationController.isInAllowedRegion &&
        isWithinClaimWindow &&
        currentBadge != nil &&
        !isCurrentBadgeUnlocked
    }

    private var isWithinClaimWindow: Bool {
        let hour = Calendar.current.component(.hour, from: currentDate)
        return hour >= claimStartHour && hour < claimEndHour
    }

    private var claimStatusText: String {
        if hasEventEnded {
            return "Der Berg ist für dieses Jahr vorbei. Danke fürs Mitstempeln und bis zum nächsten Berg!"
        }
        if unlockedBadges.count >= badgeDefinitions.count {
            return "Alle 12 Stempel sind bereits freigeschaltet."
        }
        if let officialOpeningDate, currentDate < officialOpeningDate {
            return "Bald ist es soweit. Am 21.05.2026 um 17:00 Uhr ist endlich Anstich!"
        }
        if currentBadge == nil {
            return "Heute gibt es keinen Stempel mehr."
        }
        if !isWithinClaimWindow {
            return "Der Berg hat zu. Stempel können täglich nur zwischen 10:00 und 23:00 Uhr freigeschaltet werden."
        }
        if isCurrentBadgeUnlocked {
            return "Du hast dir den Stempel für heute geholt!"
        }
        if !locationController.isInAllowedRegion {
            return "Komm jetzt hoch und hol dir den Stempel für heute!"
        }
        if currentBadge != nil {
            return "Du bist vor Ort. Jetzt kannst du dir den Stempel für heute abholen!"
        }
        return "Heute ist kein Stempel verfügbar."
    }

    private func claimBadge() {
        guard canClaimToday, let currentBadge else {
            return
        }

        var updatedBadges = unlockedBadges
        updatedBadges.insert(currentBadge.id)
        unlockedBadgeIdentifiers = updatedBadges.sorted().joined(separator: ",")
        withAnimation(overlayPresentationAnimation) {
            activeBadgeOverlay = BadgeOverlayPresentation(
                badge: currentBadge,
                title: "Stempel geholt!",
                buttonTitle: "Weiter",
                switchesToBadgeTab: true
            )
        }
    }

    private func claimActiveChallenge() {
        guard let activeChallenge, canCheckInForActiveChallenge else {
            return
        }

        var updatedChallenges = completedChallenges
        updatedChallenges.insert(activeChallenge.id)
        completedChallengeIdentifiers = updatedChallenges.sorted().joined(separator: ",")
        triggerSuccessHaptic()
        withAnimation(overlayPresentationAnimation) {
            activeChallengeOverlay = ChallengeOverlayPresentation(challenge: activeChallenge)
        }
    }

    private func isChallengeCompleted(_ challenge: DailyChallenge) -> Bool {
        completedChallenges.contains(challenge.id)
    }

    private func isWithinChallengeWindow(_ challenge: DailyChallenge) -> Bool {
        guard let startDate = challenge.startDate, let endDate = challenge.endDate else {
            return Calendar.current.isDate(challenge.date, inSameDayAs: currentDate)
        }

        return currentDate >= startDate && currentDate <= endDate
    }

    private func isWithinChallengeRadius(_ challenge: DailyChallenge) -> Bool {
        guard let center = challenge.centerCoordinate, let radius = challenge.radius else {
            return true
        }

        guard let distance = locationController.distance(to: center) else {
            return false
        }

        return distance <= radius
    }

    private func challengeDistanceText(for challenge: DailyChallenge) -> String? {
        guard let center = challenge.centerCoordinate else {
            return nil
        }

        if isWithinChallengeRadius(challenge) {
            return "Hier"
        }

        guard let distance = locationController.distance(to: center) else {
            return nil
        }

        if distance < 1000 {
            return "\(Int(distance.rounded())) m entfernt"
        }

        return String(format: "%.1f km entfernt", distance / 1000)
    }

    private func challengeDirectionAngle(for challenge: DailyChallenge) -> Double? {
        guard let center = challenge.centerCoordinate else {
            return nil
        }

        return locationController.directionAngle(to: center)
    }

    private func goToNextDay() {
        ensureTestEventStartDay()

        if !useSimulatedDate {
            useSimulatedDate = true
            currentDate = defaultEventStartDate.map { simulatedDate(for: $0, usingTimeFrom: Date()) } ?? currentDate
            evaluateMissedDayNotice()
            return
        }

        useSimulatedDate = true
        currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        evaluateMissedDayNotice()
    }

    private func resetProgress() {
        unlockedBadgeIdentifiers = ""
        completedChallengeIdentifiers = ""
        testEventStartDay = ""
        withAnimation(overlayDismissAnimation) {
            activeBadgeOverlay = nil
            activeChallengeOverlay = nil
            activeMissedDayAlert = nil
        }
        dismissedMissedBadgeIdentifier = ""
        adSlotOverride = .automatic
        useSimulatedDate = false
        syncCurrentDate()
        locationController.clearTestRegion()
        locationController.requestLocationAccess()
    }

    private func deactivateTestMode() {
        isDebugMenuUnlocked = false
        ffwdLogoTapCount = 0
        testEventStartDay = ""
        adSlotOverride = .automatic
        useSimulatedDate = false
        syncCurrentDate()
        locationController.clearTestRegion()
        locationController.requestLocationAccess()
        syncMapPosition()
        refreshMorningOutsideBannerVariant()
        evaluateMissedDayNotice()
    }

    private func syncCurrentDate() {
        currentDate = Date()
    }

    private func syncMapPosition() {
        mapPosition = .region(locationController.activeMapRegion)
    }

    private var formattedCurrentDate: String {
        let displayDate = useSimulatedDate ? currentDate : Date()
        return displayDate.formatted(date: .abbreviated, time: .shortened)
    }

    private func simulatedDate(for targetDate: Date, usingTimeFrom timeSource: Date) -> Date {
        BergscheinDateHelper.mergedDate(day: targetDate, timeSource: timeSource)
    }

    private var isTestModeActive: Bool {
        useSimulatedDate || locationController.isUsingTestRegion || adSlotOverride != .automatic
    }

    private var unlockedBadges: Set<String> {
        Set(
            unlockedBadgeIdentifiers
                .split(separator: ",")
                .map(String.init)
        )
    }

    private var currentStreak: Int {
        let currentBadgeIndex = currentBadge.flatMap { badge in
            badgeDefinitions.firstIndex(where: { $0.id == badge.id })
        }
        let anchorIndex = {
            if let currentBadgeIndex {
                let currentBadge = badgeDefinitions[currentBadgeIndex]
                if unlockedBadges.contains(currentBadge.id) {
                    return currentBadgeIndex
                }
                return max(currentBadgeIndex - 1, 0)
            }
            return badgeDefinitions.indices.last ?? 0
        }()

        guard badgeDefinitions.indices.contains(anchorIndex) else {
            return 0
        }

        var streak = 0
        for index in stride(from: anchorIndex, through: 0, by: -1) {
            let badge = badgeDefinitions[index]
            if unlockedBadges.contains(badge.id) {
                streak += 1
            } else {
                break
            }
        }
        return streak
    }

    private var blockingMissedBadge: BadgeDefinition? {
        guard let currentBadgeIndex = currentBadge.flatMap({ badge in
            badgeDefinitions.firstIndex(where: { $0.id == badge.id })
        }) else {
            return nil
        }

        guard currentBadgeIndex > 0 else {
            return nil
        }

        for index in 0..<currentBadgeIndex {
            let badge = badgeDefinitions[index]
            if !unlockedBadges.contains(badge.id) {
                return badge
            }
        }

        return nil
    }

    private var currentBadge: BadgeDefinition? {
        guard let eventStartDate else {
            return nil
        }

        if hasEventEnded {
            return nil
        }

        if let officialOpeningDate, currentDate < officialOpeningDate {
            return nil
        }

        let startDate = Calendar.current.startOfDay(for: eventStartDate)
        let activeDate = Calendar.current.startOfDay(for: currentDate)
        let dayOffset = Calendar.current.dateComponents([.day], from: startDate, to: activeDate).day ?? -1

        guard badgeDefinitions.indices.contains(dayOffset) else {
            return nil
        }

        return badgeDefinitions[dayOffset]
    }

    private var isCurrentBadgeUnlocked: Bool {
        guard let currentBadge else {
            return false
        }
        return unlockedBadges.contains(currentBadge.id)
    }

    private var currentBadgeLabel: String {
        currentBadge?.name ?? "Keiner"
    }

    private var defaultEventStartDate: Date? {
        var components = Calendar.current.dateComponents([.year], from: currentDate)
        components.month = 5
        components.day = 21
        guard let eventDate = Calendar.current.date(from: components) else {
            return nil
        }
        return Calendar.current.startOfDay(for: eventDate)
    }

    private var notificationEventYear: Int {
        challengeDefinitions.first?.year ?? Calendar.current.component(.year, from: Date())
    }

    private var notificationEventStartDate: Date? {
        notificationDate(month: 5, day: 21, hour: 0, minute: 0)
    }

    private var notificationOfficialOpeningDate: Date? {
        notificationDate(month: 5, day: 21, hour: 17, minute: 0)
    }

    private var eventStartDate: Date? {
        if !useSimulatedDate {
            return defaultEventStartDate
        }

        if testEventStartDay.isEmpty {
            return defaultEventStartDate
        }

        return dayFormatter.date(from: testEventStartDay) ?? defaultEventStartDate
    }

    private func notificationDate(month: Int, day: Int, hour: Int, minute: Int) -> Date? {
        BergscheinDateHelper.date(
            year: notificationEventYear,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    }

    private var officialOpeningDate: Date? {
        guard let eventStartDate else {
            return nil
        }

        return Calendar.current.date(
            bySettingHour: 17,
            minute: 0,
            second: 0,
            of: eventStartDate
        )
    }

    private var officialEventEndDate: Date? {
        guard let eventStartDate else {
            return nil
        }

        guard let juneFirst = Calendar.current.date(byAdding: .day, value: badgeDefinitions.count - 1, to: eventStartDate) else {
            return nil
        }

        return Calendar.current.date(
            bySettingHour: 23,
            minute: 0,
            second: 0,
            of: juneFirst
        )
    }

    private var hasOfficialOpeningStarted: Bool {
        guard let officialOpeningDate else {
            return false
        }

        return currentDate >= officialOpeningDate
    }

    private var hasEventEnded: Bool {
        guard let officialEventEndDate else {
            return false
        }

        return currentDate >= officialEventEndDate
    }

    private var hasChallengeSeasonEnded: Bool {
        guard let eventStartDate else {
            return false
        }

        var components = Calendar.current.dateComponents([.year], from: eventStartDate)
        components.month = 6
        components.day = 2

        guard let challengeEndDate = Calendar.current.date(from: components) else {
            return false
        }

        return currentDate >= Calendar.current.startOfDay(for: challengeEndDate)
    }

    private var officialOpeningCountdownText: String {
        guard let officialOpeningDate else {
            return ""
        }

        return BergscheinDateHelper.countdownText(from: currentDate, to: officialOpeningDate)
    }

    private var checkInHeadlineLabel: String {
        if hasEventEnded {
            return "Vorbei"
        }
        if let officialOpeningDate, currentDate < officialOpeningDate {
            return "Noch"
        }

        return "Heute"
    }

    private var checkInHeadlineValue: String {
        if hasEventEnded {
            return "Das war's\nfür dieses Jahr"
        }
        if let officialOpeningDate, currentDate < officialOpeningDate {
            return officialOpeningCountdownText
        }

        return currentBadge?.name ?? "Kein Stempeltag"
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private func ensureTestEventStartDay() {
        guard testEventStartDay.isEmpty else {
            return
        }
        testEventStartDay = dayFormatter.string(from: defaultEventStartDate ?? Calendar.current.startOfDay(for: Date()))
    }

    private func evaluateMissedDayNotice() {
        guard let blockingMissedBadge else {
            withAnimation(overlayDismissAnimation) {
                activeMissedDayAlert = nil
            }
            dismissedMissedBadgeIdentifier = ""
            return
        }

        guard dismissedMissedBadgeIdentifier != blockingMissedBadge.id else {
            return
        }

        withAnimation(overlayPresentationAnimation) {
            activeMissedDayAlert = MissedDayAlertPresentation(missedBadge: blockingMissedBadge)
        }
    }

    private func openMapsToRegion() {
        let coordinate = locationController.activePolygonCenter
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let address = MKAddress(fullAddress: "Berg", shortAddress: nil)
        let mapItem = MKMapItem(location: location, address: address)
        mapItem.name = "Berg"
        mapItem.openInMaps()
    }

    private func openMapsToChallengeLocation(_ challenge: DailyChallenge) {
        guard let coordinate = challenge.centerCoordinate else {
            return
        }

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let address = MKAddress(fullAddress: challenge.locationName, shortAddress: nil)
        let mapItem = MKMapItem(location: location, address: address)
        mapItem.name = challenge.locationName
        mapItem.openInMaps()
    }

    private func applyPendingNotificationDestinationIfNeeded() {
        guard let destination = NotificationNavigationStore.shared.consumePendingDestination() else {
            return
        }
        openNotificationDestination(destination)
    }

    private func openNotificationDestination(_ destination: NotificationDestination) {
        switch destination {
        case .challenge:
            selectedTab = .challenge
        }
    }

    private func refreshScheduledNotifications() {
        guard hasSeenOnboarding else {
            return
        }

        Task {
            await scheduleLocalNotifications()
        }
    }

    private func refreshNotificationAuthorizationState() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            let isSystemAvailable = settings.authorizationStatus != .denied

            await MainActor.run {
                notificationsAreSystemAuthorized = isSystemAvailable

                if !isSystemAvailable {
                    notificationsEnabled = false
                    stampNotificationsEnabled = false
                    challengeNotificationsEnabled = false
                }
            }
        }
    }

    private func scheduleLocalNotifications() async {
        let center = UNUserNotificationCenter.current()

        do {
            await removeManagedNotificationRequests(from: center)

            let settings = await center.notificationSettings()
            let isSystemAvailable = settings.authorizationStatus != .denied

            await MainActor.run {
                notificationsAreSystemAuthorized = isSystemAvailable
            }

            guard isSystemAvailable else {
                await MainActor.run {
                    notificationsEnabled = false
                    stampNotificationsEnabled = false
                    challengeNotificationsEnabled = false
                }
                return
            }

            guard notificationsEnabled else {
                return
            }
            let isAuthorized: Bool

            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                isAuthorized = true
            case .notDetermined:
                isAuthorized = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            case .denied:
                isAuthorized = false
            @unknown default:
                isAuthorized = false
            }

            await MainActor.run {
                notificationsAreSystemAuthorized = isAuthorized
            }

            guard isAuthorized else {
                await MainActor.run {
                    notificationsEnabled = false
                    stampNotificationsEnabled = false
                    challengeNotificationsEnabled = false
                }
                return
            }

            for request in makeNotificationRequests() {
                try await center.add(request)
            }
        } catch {
        }
    }

    private func removeManagedNotificationRequests(from center: UNUserNotificationCenter) async {
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix("bergschein.") }

        guard !identifiers.isEmpty else {
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func makeNotificationRequests(now: Date = Date()) -> [UNNotificationRequest] {
        var requests: [UNNotificationRequest] = []

        if let officialOpeningDate = notificationOfficialOpeningDate, officialOpeningDate > now {
            let content = UNMutableNotificationContent()
            content.title = "Jetzt Anstich!"
            content.body = "Der Berg startet jetzt für dieses Jahr. Hol dir deinen ersten Stempel."
            content.sound = .default

            if let trigger = calendarTrigger(for: officialOpeningDate) {
                requests.append(
                    UNNotificationRequest(
                        identifier: "bergschein.event-start",
                        content: content,
                        trigger: trigger
                    )
                )
            }
        }

        if stampNotificationsEnabled {
            for badge in badgeDefinitions where !unlockedBadges.contains(badge.id) {
                guard let reminderDate = notificationDate(month: badge.month, day: badge.day, hour: 19, minute: 0),
                      reminderDate > now else {
                    continue
                }

                let content = UNMutableNotificationContent()
                content.title = "Stempel für heute noch offen"
                content.body = "Hol dir den Stempel für den \(badge.name), solange der Bergtag noch läuft."
                content.sound = .default

                if let trigger = calendarTrigger(for: reminderDate) {
                    requests.append(
                        UNNotificationRequest(
                            identifier: "bergschein.stamp.\(badge.id)",
                            content: content,
                            trigger: trigger
                        )
                    )
                }
            }
        }

        if challengeNotificationsEnabled {
            for challenge in challengeDefinitions {
                guard let reminderDate = Calendar.current.date(
                    bySettingHour: 10,
                    minute: 0,
                    second: 0,
                    of: challenge.date
                ), reminderDate > now else {
                    continue
                }

                let content = UNMutableNotificationContent()
                content.title = "Heutige Challenge"
                content.body = challengeNotificationBody(for: challenge)
                content.sound = .default
                content.userInfo = ["destination": NotificationDestination.challenge.rawValue]

                if let trigger = calendarTrigger(for: reminderDate) {
                    requests.append(
                        UNNotificationRequest(
                            identifier: "bergschein.challenge.\(challenge.id)",
                            content: content,
                            trigger: trigger
                        )
                    )
                }
            }
        }

        return requests
    }

    private func challengeNotificationBody(for challenge: DailyChallenge) -> String {
        if challenge.title == "Challenge folgt" {
            return "Heute wartet wieder eine Challenge auf dich. Schau direkt im Challenge-Tab vorbei."
        }

        return "Heute: \(challenge.title). Schau direkt im Challenge-Tab vorbei."
    }

    private func calendarTrigger(for date: Date) -> UNCalendarNotificationTrigger? {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
    }

    @MainActor
    private func makeBadgeShareImage(for presentation: BadgeOverlayPresentation, imageName: String?) -> UIImage? {
        let renderer = ImageRenderer(
            content: BadgeShareGraphicView(
                presentation: presentation,
                imageName: imageName
            )
        )
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1080)
        return renderer.uiImage
    }

    @MainActor
    private func makeBergscheinShareImage() -> UIImage? {
        let latestUnlockedBadge = badgeDefinitions.last { unlockedBadges.contains($0.id) }
        let renderer = ImageRenderer(
            content: BergscheinShareGraphicView(
                visitedDays: unlockedBadges.count,
                totalDays: badgeDefinitions.count,
                imageName: latestUnlockedBadge.flatMap { resolvedImageName(for: $0) }
            )
        )
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: 1080, height: 1080)
        return renderer.uiImage
    }

    private func triggerLightHaptic() {
        guard hapticsEnabled else {
            return
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func triggerSelectionHaptic() {
        guard hapticsEnabled else {
            return
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    private func triggerSuccessHaptic() {
        guard hapticsEnabled else {
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func triggerWarningHaptic() {
        guard hapticsEnabled else {
            return
        }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func badges(in category: BadgeCategory) -> [BadgeDefinition] {
        badgeDefinitions.filter { $0.category == category }
    }

    private func standardBadges(in category: BadgeCategory) -> [BadgeDefinition] {
        let badges = badges(in: category)
        guard category == .profi, let lastBadge = badges.last, lastBadge.subtitle != nil else {
            return badges
        }
        return Array(badges.dropLast())
    }

    private func featuredBadge(in category: BadgeCategory) -> BadgeDefinition? {
        let badges = badges(in: category)
        guard category == .profi, let lastBadge = badges.last, lastBadge.subtitle != nil else {
            return nil
        }
        return lastBadge
    }

    private func resolvedImageName(for badge: BadgeDefinition) -> String? {
        if badge.id == "06-01", blockingMissedBadge != nil {
            return "badge12b"
        }
        return badge.imageName
    }
}

#Preview {
    ContentView()
}
