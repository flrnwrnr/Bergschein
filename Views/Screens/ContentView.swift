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
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.openURL) var openURL

    enum AppTab: Hashable {
        case checkIn
        case bergschein
        case challenge
        case mehr
    }

    enum SettingsRoute: Hashable, Identifiable {
        case changeLog
        case credits
        case raffle
        case tips

        var id: Self { self }
    }

    enum MorningOutsideBannerVariant {
        case ffwd
        case ching
        case tb
    }

    enum AdSlotOverride: String, CaseIterable, Identifiable {
        case automatic = "Automatisch"
        case morning = "06:00–15:00"
        case afternoon = "15:00–23:00"
        case overnight = "23:00–06:00"

        var id: String { rawValue }
    }

    let claimStartHour = 10
    let claimEndHour = 23
    let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    let locationRefreshClock = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    let badgeDefinitions = BadgeDefinition.all
    let challengeDefinitions = DailyChallenge.all
    let overlayPresentationAnimation = Animation.spring(response: 0.42, dampingFraction: 0.82)
    let overlayDismissAnimation = Animation.easeInOut(duration: 0.22)

    @StateObject var locationController = LocationController()
    @StateObject var tipJarStore = TipJarStore()
    @AppStorage("unlockedBadgeIdentifiers") var unlockedBadgeIdentifiers = ""
    @AppStorage("completedChallengeIdentifiers") var completedChallengeIdentifiers = ""
    @AppStorage("tbDrinkRewardUnlocked") var tbDrinkRewardUnlocked = false
    @AppStorage("tbDrinkRewardRedeemed") var tbDrinkRewardRedeemed = false
    @AppStorage("testEventStartDay") var testEventStartDay = ""
    @AppStorage("dismissedMissedBadgeIdentifier") var dismissedMissedBadgeIdentifier = ""
    @AppStorage("hapticsEnabled") var hapticsEnabled = true
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @AppStorage("isDebugMenuUnlocked") var isDebugMenuUnlocked = false
    @AppStorage("notificationsEnabled") var notificationsEnabled = true
    @AppStorage("stampNotificationsEnabled") var stampNotificationsEnabled = true
    @AppStorage("challengeNotificationsEnabled") var challengeNotificationsEnabled = true
    @State var activeBadgeOverlay: BadgeOverlayPresentation?
    @State var activeChallengeRewardOverlay: ChallengeRewardOverlayPresentation?
    @State var activeMissedDayAlert: MissedDayAlertPresentation?
    @State var activeBadgeShareSheet: BadgeShareSheetItem?
    @State var currentDate = Date()
    @State var useSimulatedDate = false
    @State var mapPosition = MapCameraPosition.automatic
    @State var selectedTab: AppTab = .checkIn
    @State var settingsRoute: SettingsRoute?
    @State var isShowingMapsPrompt = false
    @State var challengeMapsDestination: DailyChallenge?
    @State var notificationsAreSystemAuthorized = true
    @State var onboardingSelection = 0
    @State var morningOutsideBannerVariant: MorningOutsideBannerVariant = .ffwd
    @State var adSlotOverride: AdSlotOverride = .automatic
    @State var ffwdLogoTapCount = 0

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
            } else if let activeChallengeRewardOverlay {
                ChallengeRewardOverlayView(
                    presentation: activeChallengeRewardOverlay,
                    darkForest: darkForest,
                    onDismiss: {
                        withAnimation(overlayDismissAnimation) {
                            self.activeChallengeRewardOverlay = nil
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
}

#Preview {
    ContentView()
}
