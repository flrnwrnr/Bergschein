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
        NavigationStack {
            ZStack {
                appBackgroundGradient
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(checkInHeadlineLabel)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(statusForegroundColor.opacity(0.82))

                                Text(checkInHeadlineValue)
                                    .font(.system(size: 34, weight: .black, design: .serif))
                                    .foregroundStyle(statusForegroundColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer()

                            if hasEventEnded {
                                Text("😮‍💨")
                                    .font(.system(size: 52))
                            } else if let currentBadge {
                                BadgePreviewView(
                                    imageName: resolvedImageName(for: currentBadge),
                                    isUnlocked: isCurrentBadgeUnlocked
                                )
                            } else if !hasOfficialOpeningStarted {
                                Text("🍻")
                                    .font(.system(size: 52))
                            } else {
                                Image(systemName: stampStatusSymbol)
                                    .font(.system(size: 42, weight: .bold))
                                    .foregroundStyle(statusForegroundColor)
                            }
                        }

                        Text(claimStatusText)
                            .font(.headline)
                            .foregroundStyle(statusForegroundColor.opacity(0.94))
                            .multilineTextAlignment(.leading)

                        if canClaimToday {
                            Button("Jetzt abstempeln") {
                                triggerSuccessHaptic()
                                claimBadge()
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentColor)
                            .foregroundStyle(.white)
                            .controlSize(.large)
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 72)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: isCurrentBadgeUnlocked ? 210 : nil, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(statusGradient)
                    )

                    if currentStreak > 1 {
                        StreakStatusCard(
                            streak: currentStreak,
                            darkForest: darkForest,
                            backgroundStyle: AnyShapeStyle(
                                LinearGradient(
                                    colors: [
                                        Color(.systemGray5),
                                        Color.accentColor.opacity(0.18)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        )
                    }

                    if let locationPermissionWarningText {
                        PermissionWarningCard(text: locationPermissionWarningText)
                    }

                    if locationController.isInAllowedRegion {
                        DistanceStatusView(
                            isInAllowedRegion: true,
                            distanceText: nil,
                            directionAngle: locationController.directionAngle,
                            onTap: {}
                        )
                    } else if shouldShowDistanceHint, let distanceText = locationController.distanceToRegionText {
                        DistanceStatusView(
                            isInAllowedRegion: false,
                            distanceText: distanceText,
                            directionAngle: locationController.directionAngle,
                            onTap: { isShowingMapsPrompt = true }
                        )
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }
            .navigationTitle("Check-in")
            .safeAreaInset(edge: .bottom) {
                AdBannerCard(banner: currentAdBanner, darkForest: darkForest)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
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
        .alert("Karten öffnen?", isPresented: $isShowingMapsPrompt) {
            Button("Abbrechen", role: .cancel) { }
            Button("Öffnen") {
                openMapsToRegion()
            }
        } message: {
            Text("Möchtest du den Standort in Apple Karten öffnen?")
        }
    }

    private var badgesTab: some View {
        NavigationStack {
            ZStack {
                appBackgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        ProgressSectionView(
                            badgeDefinitions: badgeDefinitions,
                            unlockedBadges: unlockedBadges
                        )

                        if let blockedBadge = blockingMissedBadge, dismissedMissedBadgeIdentifier == blockedBadge.id {
                            MissedBergscheinNoticeCard(
                                badge: blockedBadge,
                                darkForest: darkForest,
                                onTap: {
                                    withAnimation(overlayPresentationAnimation) {
                                        activeMissedDayAlert = MissedDayAlertPresentation(missedBadge: blockedBadge)
                                    }
                                }
                            )
                        }

                        if blockingMissedBadge != nil {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                                ForEach(badgeDefinitions) { badge in
                                    BadgeCardView(
                                        badge: badge,
                                        isUnlocked: unlockedBadges.contains(badge.id),
                                        forceStandardLayout: true,
                                        imageName: resolvedImageName(for: badge),
                                        darkForest: darkForest,
                                        onTap: {
                                            withAnimation(overlayPresentationAnimation) {
                                                activeBadgeOverlay = BadgeOverlayPresentation(
                                                    badge: badge,
                                                    title: badge.overlayTitle,
                                                    buttonTitle: "Schließen",
                                                    switchesToBadgeTab: false
                                                )
                                            }
                                        }
                                    )
                                }
                            }
                        } else {
                            ForEach(BadgeCategory.allCases) { category in
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(category.rawValue)
                                        .font(.system(size: 24, weight: .bold, design: .serif))
                                        .foregroundStyle(darkForest)

                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                                        ForEach(standardBadges(in: category)) { badge in
                                            BadgeCardView(
                                                badge: badge,
                                                isUnlocked: unlockedBadges.contains(badge.id),
                                                forceStandardLayout: false,
                                                imageName: resolvedImageName(for: badge),
                                            darkForest: darkForest,
                                            onTap: {
                                                withAnimation(overlayPresentationAnimation) {
                                                    activeBadgeOverlay = BadgeOverlayPresentation(
                                                        badge: badge,
                                                        title: badge.overlayTitle,
                                                        buttonTitle: "Schließen",
                                                        switchesToBadgeTab: false
                                                    )
                                                }
                                            }
                                        )
                                    }
                                    }

                                    if let featuredBadge = featuredBadge(in: category) {
                                        BadgeCardView(
                                            badge: featuredBadge,
                                            isUnlocked: unlockedBadges.contains(featuredBadge.id),
                                            forceStandardLayout: false,
                                            imageName: resolvedImageName(for: featuredBadge),
                                        darkForest: darkForest,
                                        onTap: {
                                            withAnimation(overlayPresentationAnimation) {
                                                activeBadgeOverlay = BadgeOverlayPresentation(
                                                    badge: featuredBadge,
                                                    title: featuredBadge.overlayTitle,
                                                    buttonTitle: "Schließen",
                                                    switchesToBadgeTab: false
                                                )
                                            }
                                        }
                                    )
                                    .padding(.top, 4)
                                }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 28)
                }
            }
            .navigationTitle("Bergschein")
            .toolbar {
                if !unlockedBadges.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            if let shareImage = makeBergscheinShareImage() {
                                activeBadgeShareSheet = BadgeShareSheetItem(image: shareImage)
                            }
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Bergschein teilen")
                    }
                }
            }
        }
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
                }
            }
        }
    }

    private var changelogView: some View {
        ZStack {
            appBackgroundGradient
                .ignoresSafeArea()

            List {
                Section("2026.0") {
                    LabeledContent("Release-Datum", value: "20.03.2026")

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Neu")
                            .font(.headline)
                        Text("Initialer Release!")
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Change Log")
    }

    private var creditsView: some View {
        ZStack {
            appBackgroundGradient
                .ignoresSafeArea()

            List {
                Section {
                    VStack(spacing: 12) {
                        Image("ffwd_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 88, height: 88)
                            .padding(10)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                            .onTapGesture {
                                handleFFWDLogoTap()
                            }

                        Text("FFWD Ventures")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("Über") {
                    Text("Diese App wird von FFWD Ventures betrieben, einer innovativen Softwarefirma für die Entwicklung digitaler Produkte und Services. Neben eigenen Apps entstehen dort auch individuelle Auftragsarbeiten. Ziel sind einfache, effektive und benutzerfreundliche Lösungen.")
                }

                Section("Impressum") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FFWD Florian Werner Digital Ventures")
                        Text("Marquardsenstr. 4")
                        Text("91054 Erlangen")
                        Text("Deutschland")
                        Text("E-Mail: contact@ffwdventures.de")
                        Text("Telefon: +49 176 608832")
                        Text("Vertreten durch Florian Werner")
                    }
                }

                Section("Mehr") {
                    Link(destination: URL(string: "https://www.ffwdventures.de")!) {
                        Label("Webseite", systemImage: "safari")
                            .foregroundStyle(.primary)
                    }

                    Link(destination: URL(string: "mailto:contact@ffwdventures.de")!) {
                        Label("Kontakt", systemImage: "envelope")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Über")
    }

    private var challengeTab: some View {
        NavigationStack {
            ZStack {
                appBackgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        if !hasChallengeSeasonEnded {
                            Text("Hier findest du an jedem Bergtag eine Challenge rund um das Thema Kirchweih und Erlangen. Du kannst nur an genau diesem Tag mitmachen und an ausgewählten Tagen eine \(Text("Belohnung").fontWeight(.black).foregroundStyle(.primary)) erhalten.")
                                .font(.footnote.weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary.opacity(0.9))
                                .frame(maxWidth: .infinity)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if let activeChallenge {
                            ChallengeCardView(
                                challenge: activeChallenge,
                                isCompleted: isChallengeCompleted(activeChallenge),
                                showsButton: shouldShowChallengeButton,
                                buttonTitle: activeChallengeButtonTitle,
                                canCheckIn: canCheckInForActiveChallenge,
                                isWithinZone: isWithinChallengeRadius(activeChallenge),
                                darkForest: darkForest,
                                distanceText: challengeDistanceText(for: activeChallenge),
                                directionAngle: challengeDirectionAngle(for: activeChallenge),
                                statusText: challengeStatusText,
                                onLocationTap: activeChallenge.centerCoordinate == nil ? nil : {
                                    challengeMapsDestination = activeChallenge
                                },
                                action: claimActiveChallenge
                            )
                        } else if hasChallengeSeasonEnded {
                            VStack(spacing: 18) {
                                Text("👋")
                                    .font(.system(size: 68))

                                Text("Bis demnächst!")
                                    .font(.system(size: 28, weight: .black, design: .serif))
                                    .foregroundStyle(darkForest)
                                    .multilineTextAlignment(.center)

                                Text("Der Berg ist für dieses Jahr vorbei. Im nächsten warten wieder neue Challenges auf dich. Danke, dass du mitgemacht hast!")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: 320)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(24)
                        } else {
                            VStack(spacing: 18) {
                                Text("🏁")
                                    .font(.system(size: 52))

                                Text("Keine Challenge aktiv")
                                    .font(.system(size: 28, weight: .black, design: .serif))
                                    .foregroundStyle(darkForest)

                                Text("Für den aktuellen Tag ist keine Challenge mehr verfügbar.")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: 320)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(24)
                        }
                    }
                    .padding(16)
                    .padding(.top, 4)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Challenge")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("\(completedChallengesCount)/\(totalChallengesCount)")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(darkForest)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color.white.opacity(0.82))
                        )
                        .accessibilityLabel("Absolvierte Challenges")
                }
            }
            .alert("In Apple Karten öffnen?", isPresented: challengeMapsAlertBinding) {
                Button("Abbrechen", role: .cancel) {
                    challengeMapsDestination = nil
                }
                Button("Öffnen") {
                    if let challengeMapsDestination {
                        openMapsToChallengeLocation(challengeMapsDestination)
                    }
                    challengeMapsDestination = nil
                }
            } message: {
                Text("Möchtest du den Ort dieser Challenge in Apple Karten öffnen?")
            }
        }
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
            return .ffwd
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
        guard currentAdSlot == .morning, !locationController.isInAllowedRegion else {
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
        let targetDay = Calendar.current.dateComponents([.year, .month, .day], from: targetDate)
        let time = Calendar.current.dateComponents([.hour, .minute, .second], from: timeSource)
        var merged = DateComponents()
        merged.year = targetDay.year
        merged.month = targetDay.month
        merged.day = targetDay.day
        merged.hour = time.hour
        merged.minute = time.minute
        merged.second = time.second
        return Calendar.current.date(from: merged) ?? targetDate
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
        var components = DateComponents()
        components.year = notificationEventYear
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return Calendar.current.date(from: components)
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

        let components = Calendar.current.dateComponents([.day, .hour, .minute, .second], from: currentDate, to: officialOpeningDate)
        let days = max(components.day ?? 0, 0)
        let hours = max(components.hour ?? 0, 0)
        let minutes = max(components.minute ?? 0, 0)
        let seconds = max(components.second ?? 0, 0)

        var parts: [String] = []
        if days > 0 {
            let dayLabel = days == 1 ? "Tag" : "Tage"
            parts.append("\(days) \(dayLabel)")
        }
        if hours > 0 || !parts.isEmpty {
            parts.append("\(hours) Std.")
        }
        if minutes > 0 || !parts.isEmpty {
            parts.append("\(minutes) Min.")
        }
        parts.append("\(seconds)s")

        if parts.count > 2 {
            let firstLine = parts.prefix(2).joined(separator: " ")
            let secondLine = parts.dropFirst(2).joined(separator: " ")
            return "\(firstLine)\n\(secondLine)"
        }

        return parts.joined(separator: " ")
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

enum BadgeCategory: String, CaseIterable, Identifiable {
    case netterAnfang = "Netter Anfang"
    case solideLeistung = "Solide Leistung"
    case profi = "Profi"

    var id: String { rawValue }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let text: String
    var requiresLocationAuthorization = false

    var usesEmojiIcon: Bool {
        !icon.allSatisfy(\.isASCII)
    }
}

struct BadgeDefinition: Identifiable {
    let id: String
    let name: String
    let shortLabel: String
    let month: Int
    let day: Int
    let category: BadgeCategory
    let subtitle: String?
    let imageName: String?
    let overlayMessage: String
    let sponsorLabel: String?
    let sponsorLogoName: String?
    let sponsorURL: URL?

    var overlayTitle: String {
        "Tag \(displayDayIndex)"
    }

    var displayDayIndex: Int {
        Self.all.firstIndex(where: { $0.id == id }).map { $0 + 1 } ?? 0
    }

    static let all: [BadgeDefinition] = [
        BadgeDefinition(id: "05-21", name: "21.05.", shortLabel: "21.05.", month: 5, day: 21, category: .netterAnfang, subtitle: nil, imageName: "badge1", overlayMessage: "Der Auftakt ist geschafft. Dein Bergschein hat seinen ersten Stempel.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-22", name: "22.05.", shortLabel: "22.05.", month: 5, day: 22, category: .netterAnfang, subtitle: nil, imageName: "badge2", overlayMessage: "Tag zwei sitzt. So sammelt sich der Bergschein Schritt für Schritt.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-23", name: "23.05.", shortLabel: "23.05.", month: 5, day: 23, category: .netterAnfang, subtitle: nil, imageName: "badge3", overlayMessage: "Drei Tage in Folge sehen schon nach echter Routine aus.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-24", name: "24.05.", shortLabel: "24.05.", month: 5, day: 24, category: .solideLeistung, subtitle: nil, imageName: "badge4", overlayMessage: "Starker Lauf. Du bist jetzt sichtbar in der soliden Phase angekommen.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-25", name: "25.05.", shortLabel: "25.05.", month: 5, day: 25, category: .solideLeistung, subtitle: nil, imageName: "badge5", overlayMessage: "Halbherzig ist das nicht mehr. Dein Bergschein wächst konstant weiter.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-26", name: "26.05.", shortLabel: "26.05.", month: 5, day: 26, category: .solideLeistung, subtitle: nil, imageName: "badge6", overlayMessage: "Wieder abgestempelt. Genau so wird aus einer Idee ein echter Lauf.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-27", name: "27.05.", shortLabel: "27.05.", month: 5, day: 27, category: .solideLeistung, subtitle: nil, imageName: "badge7", overlayMessage: "Sieben Tage machen Eindruck. Das ist längst mehr als nur ein Versuch.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-28", name: "28.05.", shortLabel: "28.05.", month: 5, day: 28, category: .profi, subtitle: nil, imageName: "badge8", overlayMessage: "Ab jetzt wird es ernst. Du bist klar auf Profi-Kurs unterwegs.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-29", name: "29.05.", shortLabel: "29.05.", month: 5, day: 29, category: .profi, subtitle: nil, imageName: "badge9", overlayMessage: "Noch ein Profi-Tag. Der große Bergschein rückt spürbar näher.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-30", name: "30.05.", shortLabel: "30.05.", month: 5, day: 30, category: .profi, subtitle: nil, imageName: "badge10", overlayMessage: "Die letzten Meter laufen. Dein Bergschein ist fast komplett.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "05-31", name: "31.05.", shortLabel: "31.05.", month: 5, day: 31, category: .profi, subtitle: nil, imageName: "badge11", overlayMessage: "Vorletzter Stempel. Viel näher kannst du dem Finale kaum noch kommen.", sponsorLabel: nil, sponsorLogoName: nil, sponsorURL: nil),
        BadgeDefinition(id: "06-01", name: "01.06.", shortLabel: "01.06.", month: 6, day: 1, category: .profi, subtitle: "Großer Bergschein", imageName: "badge12", overlayMessage: "Geschafft. Der große Bergschein gehört jetzt dir.", sponsorLabel: "Gesponsert vom", sponsorLogoName: "logo_erich", sponsorURL: URL(string: "https://www.erich-keller.net")),
    ]
}

struct BadgeOverlayPresentation {
    let badge: BadgeDefinition
    let title: String
    let buttonTitle: String
    let switchesToBadgeTab: Bool
}

struct BadgeShareSheetItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct MissedDayAlertPresentation {
    let missedBadge: BadgeDefinition
}

struct ChallengeOverlayPresentation {
    let challenge: DailyChallenge
}

struct DailyChallenge: Identifiable {
    let id: String
    let icon: String
    let title: String
    let text: String
    let locationName: String
    let month: Int
    let day: Int
    let year: Int
    let startHour: Int?
    let startMinute: Int?
    let endHour: Int?
    let endMinute: Int?
    let centerCoordinate: CLLocationCoordinate2D?
    let radius: CLLocationDistance?
    let requiresLocationCheckIn: Bool

    var date: Date {
        let components = DateComponents(year: year, month: month, day: day)
        return Calendar.current.date(from: components) ?? .now
    }

    var startDate: Date? {
        guard let startHour, let startMinute else {
            return nil
        }

        return Calendar.current.date(
            bySettingHour: startHour,
            minute: startMinute,
            second: 0,
            of: date
        )
    }

    var endDate: Date? {
        guard let endHour, let endMinute else {
            return nil
        }

        let sameDayEndDate = Calendar.current.date(
            bySettingHour: endHour,
            minute: endMinute,
            second: 0,
            of: date
        )

        guard let sameDayEndDate else {
            return nil
        }

        if spansMidnight {
            return Calendar.current.date(byAdding: .day, value: 1, to: sameDayEndDate)
        }

        return sameDayEndDate
    }

    var spansMidnight: Bool {
        guard let startHour, let startMinute, let endHour, let endMinute else {
            return false
        }

        return (endHour, endMinute) < (startHour, startMinute)
    }

    var dateLabel: String {
        String(format: "%02d.%02d.%04d", day, month, year)
    }

    var timeWindowLabel: String {
        guard let startHour, let startMinute, let endHour, let endMinute else {
            return "ganztägig"
        }

        return String(format: "%02d:%02d–%02d:%02d Uhr", startHour, startMinute, endHour, endMinute)
    }

    var completionTitle: String {
        "Challenge abgehakt!"
    }

    var completionMessage: String {
        switch id {
        case "2026-05-21":
            return "Du warst pünktlich beim Anstich an der T-Kreuzung dabei. Starker Auftakt."
        case "2026-05-22":
            return "Zirkel bei Nacht sitzt. Die zweite Challenge ist dir sicher."
        case "2026-05-23":
            return "Der Abstecher zum BMS ist geschafft. Challenge erfolgreich abgehakt."
        default:
            return "Diese Tageschallenge hast du erfolgreich abgehakt."
        }
    }

    static let all: [DailyChallenge] = [
        DailyChallenge(
            id: "2026-05-21",
            icon: "🍻",
            title: "Anstich an der T-Kreuzung",
            text: "Checke zwischen 16:00 und 18:00 Uhr am sogenannten T zum Anstich ein.",
            locationName: "T-Kreuzung",
            month: 5,
            day: 21,
            year: 2026,
            startHour: 16,
            startMinute: 0,
            endHour: 18,
            endMinute: 0,
            centerCoordinate: CLLocationCoordinate2D(latitude: 49.60756, longitude: 11.00512),
            radius: 50,
            requiresLocationCheckIn: true
        ),
        DailyChallenge(
            id: "2026-05-22",
            icon: "🪩",
            title: "Afterberg im Zirkel",
            text: "Checke am 22.05. zwischen 21:00 und 23:59 Uhr im Zirkel ein und feier im Klassiker.",
            locationName: "Zirkel",
            month: 5,
            day: 22,
            year: 2026,
            startHour: 20,
            startMinute: 0,
            endHour: 23,
            endMinute: 59,
            centerCoordinate: CLLocationCoordinate2D(latitude: 49.60240, longitude: 11.00360),
            radius: 100,
            requiresLocationCheckIn: true
        ),
        DailyChallenge(
            id: "2026-05-23",
            icon: "🌳",
            title: "Abstecher zum BMS",
            text: "Mach am 23.05. einen Abstecher zum BMS und hake die Challenge direkt vor Ort ab.",
            locationName: "BMS",
            month: 5,
            day: 23,
            year: 2026,
            startHour: 10,
            startMinute: 0,
            endHour: 14,
            endMinute: 0,
            centerCoordinate: CLLocationCoordinate2D(latitude: 49.60266, longitude: 11.02082),
            radius: 200,
            requiresLocationCheckIn: true
        ),
        DailyChallenge(
            id: "2026-05-24",
            icon: "🍻",
            title: "Frühschoppen am Erich Keller",
            text: "Mach am 24.05. einen Abstecher zum Frühschoppen am Erich Keller und hake die Challenge direkt vor Ort ab.",
            locationName: "Erich Keller",
            month: 5,
            day: 24,
            year: 2026,
            startHour: 10,
            startMinute: 0,
            endHour: 20,
            endMinute: 0,
            centerCoordinate: CLLocationCoordinate2D(latitude: 49.60771, longitude: 11.00417),
            radius: 70,
            requiresLocationCheckIn: true
        ),
        DailyChallenge(
            id: "2026-05-25",
            icon: "🎡",
            title: "Pflichtfahrt im Riesenrad",
            text: "Dreh am 25.05. zwischen 10:00 und 23:00 Uhr die Pflichtfahrt im Riesenrad, die zu jedem Berg einfach dazugehört, und hake die Challenge direkt vor Ort ab.",
            locationName: "Riesenrad",
            month: 5,
            day: 25,
            year: 2026,
            startHour: 10,
            startMinute: 0,
            endHour: 23,
            endMinute: 0,
            centerCoordinate: CLLocationCoordinate2D(latitude: 49.60714, longitude: 11.00681),
            radius: 100,
            requiresLocationCheckIn: true
        ),
        DailyChallenge(
            id: "2026-05-26",
            icon: "📚",
            title: "Besuch in der Bib",
            text: "Geh am 26.05. mal wieder in die Unibib, damit du das Lernen nicht ganz vergisst 😉",
            locationName: "Unibib",
            month: 5,
            day: 26,
            year: 2026,
            startHour: 10,
            startMinute: 0,
            endHour: 20,
            endMinute: 0,
            centerCoordinate: CLLocationCoordinate2D(latitude: 49.59661, longitude: 11.00713),
            radius: 120,
            requiresLocationCheckIn: true
        ),
        DailyChallenge(
            id: "2026-05-27",
            icon: "🌿",
            title: "Erholsamer Besuch im Aromagarten",
            text: "Mach am 27.05. einen erholsamen Abstecher in den Aromagarten und hake die Challenge direkt vor Ort ab.",
            locationName: "Aromagarten",
            month: 5,
            day: 27,
            year: 2026,
            startHour: 10,
            startMinute: 0,
            endHour: 20,
            endMinute: 0,
            centerCoordinate: CLLocationCoordinate2D(latitude: 49.60268, longitude: 11.01638),
            radius: 120,
            requiresLocationCheckIn: true
        ),
        DailyChallenge(
            id: "2026-05-28",
            icon: "🏁",
            title: "Auto-Scooter mit den Kids",
            text: "Fahr am 28.05. zwischen 10:00 und 23:00 Uhr eine Runde Auto-Scooter mit den Kids und hake die Challenge direkt vor Ort ab.",
            locationName: "Auto-Scooter",
            month: 5,
            day: 28,
            year: 2026,
            startHour: 10,
            startMinute: 0,
            endHour: 23,
            endMinute: 0,
            centerCoordinate: CLLocationCoordinate2D(latitude: 49.60709, longitude: 11.00758),
            radius: 100,
            requiresLocationCheckIn: true
        ),
        DailyChallenge(
            id: "2026-05-29",
            icon: "🌳",
            title: "Besuch im Schlossgarten",
            text: "Mach am 29.05. einen Besuch in Erlangens Highlight, dem Schlossgarten, und hake die Challenge direkt vor Ort ab.",
            locationName: "Schlossgarten",
            month: 5,
            day: 29,
            year: 2026,
            startHour: 10,
            startMinute: 0,
            endHour: 20,
            endMinute: 0,
            centerCoordinate: CLLocationCoordinate2D(latitude: 49.59801, longitude: 11.00525),
            radius: 120,
            requiresLocationCheckIn: true
        ),
        DailyChallenge(
            id: "2026-05-30",
            icon: "⛪️",
            title: "Check-in am Kirchenplatz",
            text: "Hol dir am 30.05. am Kirchenplatz kurz den dringend notwendigen Segen ab und hake die Challenge direkt vor Ort ab.",
            locationName: "Kirchenplatz",
            month: 5,
            day: 30,
            year: 2026,
            startHour: 10,
            startMinute: 0,
            endHour: 20,
            endMinute: 0,
            centerCoordinate: CLLocationCoordinate2D(latitude: 49.60128, longitude: 11.00814),
            radius: 100,
            requiresLocationCheckIn: true
        ),
        DailyChallenge(
            id: "2026-05-31",
            icon: "🥂",
            title: "Vorglühen am Bohlenplatz",
            text: "Mach am 31.05. einen Abstecher zum Vorglühen am Bohlenplatz im Herzen Erlangens und hake die Challenge direkt vor Ort ab.",
            locationName: "Bohlenplatz",
            month: 5,
            day: 31,
            year: 2026,
            startHour: 12,
            startMinute: 0,
            endHour: 20,
            endMinute: 0,
            centerCoordinate: CLLocationCoordinate2D(latitude: 49.59662, longitude: 11.01111),
            radius: 100,
            requiresLocationCheckIn: true
        ),
        DailyChallenge(
            id: "2026-06-01",
            icon: "🍺",
            title: "Eine letzte Maß",
            text: "Trink am 01.06. noch eine letzte Maß und hake die finale Challenge direkt vor Ort ab.",
            locationName: "T-Kreuzung",
            month: 6,
            day: 1,
            year: 2026,
            startHour: 10,
            startMinute: 0,
            endHour: 20,
            endMinute: 0,
            centerCoordinate: CLLocationCoordinate2D(latitude: 49.60756, longitude: 11.00512),
            radius: 50,
            requiresLocationCheckIn: true
        ),
    ]
}

struct AfterBergLocation: Identifiable {
    enum Kind {
        case bar
        case club
        case other
    }

    let id: String
    let name: String
    let category: String
    let address: String
    let description: String
    let website: URL
    let icon: String
    let kind: Kind

    var marker: String {
        switch kind {
        case .bar:
            return "🍻"
        case .club:
            return "🪩"
        case .other:
            return "🍻"
        }
    }

    static let all: [AfterBergLocation] = [
        AfterBergLocation(
            id: "paisley",
            name: "Paisley",
            category: "Bar",
            address: "Nürnberger Straße 22, 91052 Erlangen",
            description: "Zentrale Cocktail- und Szenebar für einen entspannten Start in den Abend.",
            website: URL(string: "https://paisley-erlangen.de")!,
            icon: "wineglass",
            kind: .bar
        ),
        AfterBergLocation(
            id: "delphi",
            name: "Delphi Bar",
            category: "Bar",
            address: "Luitpoldstraße 31, 91052 Erlangen",
            description: "Bekannte Erlanger Bar mit Drinks, DJs und späterem Abendpublikum.",
            website: URL(string: "https://www.delphi-erlangen.de")!,
            icon: "martini",
            kind: .bar
        ),
        AfterBergLocation(
            id: "eleonbar",
            name: "Eleon Bar",
            category: "Bar",
            address: "Friedrichstraße 20, 91054 Erlangen",
            description: "Kleine Bar in der Innenstadt mit Cocktails und loungiger Atmosphäre.",
            website: URL(string: "https://www.eleonbar.de")!,
            icon: "cocktail",
            kind: .bar
        ),
        AfterBergLocation(
            id: "zirkel",
            name: "Zirkel",
            category: "Club",
            address: "Hauptstraße 105, 91054 Erlangen",
            description: "Erlanger Club-Institution mit Partynächten, studentischem Publikum und später Stimmung.",
            website: URL(string: "https://zirkel-club.de")!,
            icon: "figure.dance",
            kind: .club
        ),
        AfterBergLocation(
            id: "kanapee",
            name: "Kanapee",
            category: "Kneipe",
            address: "Neue Straße 50, 91054 Erlangen",
            description: "Kultige Kneipe in der Altstadt, beliebt für einen unkomplizierten Abend mit Bier und Fußball.",
            website: URL(string: "https://spd-erlangen.de/orte/kanapee/")!,
            icon: "wineglass",
            kind: .other
        ),
        AfterBergLocation(
            id: "gluexrausch",
            name: "Glüxrausch",
            category: "Bar & Burger",
            address: "Hauptstraße 103, 91054 Erlangen",
            description: "Beliebter Spot für Burger, Cocktails und einen lebhaften Start in die Nacht.",
            website: URL(string: "https://www.gluexrausch.com/")!,
            icon: "fork.knife",
            kind: .bar
        ),
        AfterBergLocation(
            id: "steinbach",
            name: "Steinbach Bräu",
            category: "Brauhaus",
            address: "Vierzigmannstraße 4, 91054 Erlangen",
            description: "Hausbrauerei mit eigenem Bier und klassischem Wirtshauscharakter direkt in Erlangen.",
            website: URL(string: "https://www.steinbach-braeu.de")!,
            icon: "mug.fill",
            kind: .other
        ),
        AfterBergLocation(
            id: "mixmax",
            name: "Mix Max",
            category: "Club & Bar",
            address: "Fahrstraße 9, 91054 Erlangen",
            description: "Klassischer Ausgehspot in Erlangen mit Barbetrieb und Clubnächten.",
            website: URL(string: "https://mixmax-erlangen.de")!,
            icon: "music.note.house",
            kind: .club
        ),
    ]
}

struct AdBanner {
    let imageName: String?
    let title: String
    let text: String
    let url: URL

    static let ffwd = AdBanner(
        imageName: "werbung_ffwd",
        title: "FFWD Ventures",
        text: "App oder Webseite gefällig? Wir bauen alles schnell und unkompliziert!",
        url: URL(string: "https://ffwdventures.de/index-de.html")!
    )

    static let ching = AdBanner(
        imageName: "werbung_ching",
        title: "CHING Coatings",
        text: "Wir schreiben Tradition seit 1927. Schreibst Du mit? Bewirb Dich jetzt!",
        url: URL(string: "https://www.ching-coatings.com/arbeiten-bei-ching/")!
    )

    static let tb = AdBanner(
        imageName: "werbung_tb",
        title: "TB Basketball",
        text: "Bock auf Regionalligabasketball? Dann komm zum besten Basketballverein der Stadt!",
        url: URL(string: "https://www.instagram.com/tberlangenbasketball/")!
    )

    static let erich = AdBanner(
        imageName: "werbung_erich",
        title: "Erich Keller",
        text: "Auf der Suche nach dem Keller mit der besten Stimmung und dem besten Bier? Hier entlang!",
        url: URL(string: "https://www.erich-keller.net")!
    )

    static let zirkel = AdBanner(
        imageName: "werbung_zirkel",
        title: "Zirkel",
        text: "Vom Bergkeller ab in deinen Lieblingskeller! Worauf wartest du?",
        url: URL(string: "https://zirkel-club.de")!
    )
}

@MainActor
final class LocationController: NSObject, ObservableObject, CLLocationManagerDelegate {
    enum TestPolygon {
        case original
        case alternate
    }

    static let originalRegionPolygon: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 49.59639, longitude: 11.01202),
        CLLocationCoordinate2D(latitude: 49.59682, longitude: 11.01634),
        CLLocationCoordinate2D(latitude: 49.59882, longitude: 11.01578),
        CLLocationCoordinate2D(latitude: 49.59834, longitude: 11.01032),
        CLLocationCoordinate2D(latitude: 49.59579, longitude: 11.01167),
    ]

    static let alternateRegionPolygon: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 49.60788, longitude: 11.00231),
        CLLocationCoordinate2D(latitude: 49.60821, longitude: 11.00240),
        CLLocationCoordinate2D(latitude: 49.60832, longitude: 11.00411),
        CLLocationCoordinate2D(latitude: 49.60814, longitude: 11.00639),
        CLLocationCoordinate2D(latitude: 49.60785, longitude: 11.00689),
        CLLocationCoordinate2D(latitude: 49.60780, longitude: 11.00844),
        CLLocationCoordinate2D(latitude: 49.60733, longitude: 11.00923),
        CLLocationCoordinate2D(latitude: 49.60736, longitude: 11.01156),
        CLLocationCoordinate2D(latitude: 49.60685, longitude: 11.01303),
        CLLocationCoordinate2D(latitude: 49.60672, longitude: 11.01118),
        CLLocationCoordinate2D(latitude: 49.60653, longitude: 11.00942),
        CLLocationCoordinate2D(latitude: 49.60683, longitude: 11.00862),
        CLLocationCoordinate2D(latitude: 49.60695, longitude: 11.00665),
        CLLocationCoordinate2D(latitude: 49.60656, longitude: 11.00652),
        CLLocationCoordinate2D(latitude: 49.60657, longitude: 11.00608),
        CLLocationCoordinate2D(latitude: 49.60644, longitude: 11.00604),
        CLLocationCoordinate2D(latitude: 49.60642, longitude: 11.00532),
        CLLocationCoordinate2D(latitude: 49.60573, longitude: 11.00539),
        CLLocationCoordinate2D(latitude: 49.60573, longitude: 11.00508),
        CLLocationCoordinate2D(latitude: 49.60648, longitude: 11.00510),
        CLLocationCoordinate2D(latitude: 49.60712, longitude: 11.00467),
        CLLocationCoordinate2D(latitude: 49.60754, longitude: 11.00346),
        CLLocationCoordinate2D(latitude: 49.60779, longitude: 11.00289),
        CLLocationCoordinate2D(latitude: 49.60782, longitude: 11.00217),
    ]

    static func mapRegion(for polygonCoordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        let polygon = MKPolygon(coordinates: polygonCoordinates, count: polygonCoordinates.count)
        let boundingRect = polygon.boundingMapRect
        let region = MKCoordinateRegion(boundingRect)

        return MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: region.span.latitudeDelta * 1.4,
                longitudeDelta: region.span.longitudeDelta * 1.4
            )
        )
    }

    @Published private(set) var isInAllowedRegion = false
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var statusText = "Standort wird geprüft."
    @Published private(set) var isUsingTestRegion = false
    @Published private(set) var activeTestPolygon: TestPolygon = .alternate
    @Published private(set) var distanceToRegionText: String?
    @Published private(set) var distanceToRegionMeters: CLLocationDistance?
    @Published private(set) var directionAngle: Double = 0

    private let manager = CLLocationManager()
    private var lastKnownCoordinate: CLLocationCoordinate2D?
    private var currentHeading: CLLocationDirection = 0
    private var canPromptForAuthorization = false

    var activePolygon: [CLLocationCoordinate2D] {
        switch activeTestPolygon {
        case .original:
            return Self.originalRegionPolygon
        case .alternate:
            return Self.alternateRegionPolygon
        }
    }

    var activeMapRegion: MKCoordinateRegion {
        Self.mapRegion(for: activePolygon)
    }

    var activePolygonCenter: CLLocationCoordinate2D {
        let latitude = activePolygon.map(\.latitude).reduce(0, +) / Double(activePolygon.count)
        let longitude = activePolygon.map(\.longitude).reduce(0, +) / Double(activePolygon.count)
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var activePolygonName: String {
        switch activeTestPolygon {
        case .original:
            return "Alternative"
        case .alternate:
            return "Original"
        }
    }

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.headingFilter = 5
    }

    func requestLocationAccess() {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .notDetermined:
            statusText = "Standortzugriff noch nicht freigegeben."
        case .authorizedAlways, .authorizedWhenInUse:
            statusText = "Standort wird aktualisiert."
            manager.requestLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        case .denied, .restricted:
            isInAllowedRegion = false
            statusText = "Standortzugriff ist deaktiviert."
        @unknown default:
            isInAllowedRegion = false
            statusText = "Standortstatus ist unbekannt."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if hasLocationAccess {
            requestLocationAccess()
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            statusText = "Standortzugriff ist deaktiviert."
        }
    }

    var hasLocationAccess: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    func requestAccessForOnboarding() {
        authorizationStatus = manager.authorizationStatus
        canPromptForAuthorization = true
        if authorizationStatus == .notDetermined, canPromptForAuthorization {
            manager.requestWhenInUseAuthorization()
        } else if hasLocationAccess {
            requestLocationAccess()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            isInAllowedRegion = false
            statusText = "Kein Standort verfügbar."
            distanceToRegionText = nil
            distanceToRegionMeters = nil
            return
        }

        lastKnownCoordinate = location.coordinate
        updateRegionState(for: location.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        currentHeading = heading

        if let lastKnownCoordinate {
            updateDistanceAndDirection(for: lastKnownCoordinate)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isInAllowedRegion = false
        statusText = "Standort konnte nicht geladen werden."
        distanceToRegionText = nil
        distanceToRegionMeters = nil
    }

    func toggleTestPolygon() {
        activeTestPolygon = activeTestPolygon == .original ? .alternate : .original
        isUsingTestRegion = true
        if let lastKnownCoordinate {
            updateRegionState(for: lastKnownCoordinate)
        } else {
            requestLocationAccess()
        }
    }

    func clearTestRegion() {
        isUsingTestRegion = false
        activeTestPolygon = .alternate
        if let lastKnownCoordinate {
            updateRegionState(for: lastKnownCoordinate)
        } else {
            statusText = "Standort wird geprüft."
        }
    }

    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let lastKnownCoordinate else {
            return nil
        }

        let currentLocation = CLLocation(latitude: lastKnownCoordinate.latitude, longitude: lastKnownCoordinate.longitude)
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return currentLocation.distance(from: targetLocation)
    }

    func directionAngle(to coordinate: CLLocationCoordinate2D) -> Double? {
        guard let lastKnownCoordinate else {
            return nil
        }

        let bearing = bearingDegrees(from: lastKnownCoordinate, to: coordinate)
        return bearing - currentHeading
    }

    private func isInsideAllowedPolygon(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let polygonCoordinates = activePolygon
        guard polygonCoordinates.count >= 3 else {
            return false
        }

        var isInside = false
        var previousVertex = polygonCoordinates[polygonCoordinates.count - 1]

        for currentVertex in polygonCoordinates {
            let currentLatitude = currentVertex.latitude
            let currentLongitude = currentVertex.longitude
            let previousLatitude = previousVertex.latitude
            let previousLongitude = previousVertex.longitude

            let crossesLatitude = (currentLatitude > coordinate.latitude) != (previousLatitude > coordinate.latitude)
            if crossesLatitude {
                let longitudeOnEdge = (previousLongitude - currentLongitude) *
                    (coordinate.latitude - currentLatitude) /
                    (previousLatitude - currentLatitude) +
                    currentLongitude

                if coordinate.longitude < longitudeOnEdge {
                    isInside.toggle()
                }
            }

            previousVertex = currentVertex
        }

        return isInside
    }

    private func updateRegionState(for coordinate: CLLocationCoordinate2D) {
        isInAllowedRegion = isInsideAllowedPolygon(coordinate)

        if isUsingTestRegion {
            statusText = isInAllowedRegion
                ? "Testmodus: Dein Standort liegt in der aktiven Region."
                : "Testmodus: Dein Standort liegt außerhalb der aktiven Region."
        } else {
            statusText = isInAllowedRegion
                ? "Du bist in der freigegebenen Region."
                : "Du bist außerhalb der freigegebenen Region."
        }

        updateDistanceAndDirection(for: coordinate)
    }

    private func updateDistanceAndDirection(for coordinate: CLLocationCoordinate2D) {
        let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let targetLocation = CLLocation(
            latitude: activePolygonCenter.latitude,
            longitude: activePolygonCenter.longitude
        )
        let distance = currentLocation.distance(from: targetLocation)
        distanceToRegionMeters = distance

        if distance < 1000 {
            distanceToRegionText = "\(Int(distance.rounded())) m"
        } else {
            distanceToRegionText = String(format: "%.1f km", distance / 1000)
        }

        let bearing = bearingDegrees(from: coordinate, to: activePolygonCenter)
        directionAngle = bearing - currentHeading
    }

    private func bearingDegrees(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let startLatitude = start.latitude * .pi / 180
        let startLongitude = start.longitude * .pi / 180
        let endLatitude = end.latitude * .pi / 180
        let endLongitude = end.longitude * .pi / 180

        let deltaLongitude = endLongitude - startLongitude
        let y = sin(deltaLongitude) * cos(endLatitude)
        let x = cos(startLatitude) * sin(endLatitude) - sin(startLatitude) * cos(endLatitude) * cos(deltaLongitude)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

}

#Preview {
    ContentView()
}
