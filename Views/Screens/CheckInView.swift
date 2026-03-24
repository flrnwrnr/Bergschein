//
//  CheckInView.swift
//  Bergschein
//

import SwiftUI

struct CheckInView: View {
    let appBackgroundGradient: LinearGradient
    let statusGradient: LinearGradient
    let checkInHeadlineLabel: String
    let checkInHeadlineValue: String
    let statusForegroundColor: Color
    let claimStatusText: String
    let canClaimToday: Bool
    let hasEventEnded: Bool
    let hasOfficialOpeningStarted: Bool
    let currentBadgeImageName: String?
    let isCurrentBadgeUnlocked: Bool
    let stampStatusSymbol: String
    let currentStreak: Int
    let darkForest: Color
    let locationPermissionWarningText: String?
    let isInAllowedRegion: Bool
    let shouldShowDistanceHint: Bool
    let distanceText: String?
    let directionAngle: Double
    let currentAdBanner: AdBanner
    @Binding var isShowingMapsPrompt: Bool
    let onClaimTap: () -> Void
    let onOpenMaps: () -> Void

    var body: some View {
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
                            } else if let currentBadgeImageName {
                                BadgePreviewView(
                                    imageName: currentBadgeImageName,
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
                            Button("Jetzt abstempeln", action: onClaimTap)
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

                    if isInAllowedRegion {
                        DistanceStatusView(
                            isInAllowedRegion: true,
                            distanceText: nil,
                            directionAngle: directionAngle,
                            onTap: {}
                        )
                    } else if shouldShowDistanceHint, let distanceText {
                        DistanceStatusView(
                            isInAllowedRegion: false,
                            distanceText: distanceText,
                            directionAngle: directionAngle,
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
            .alert("Karten öffnen?", isPresented: $isShowingMapsPrompt) {
                Button("Abbrechen", role: .cancel) { }
                Button("Öffnen", action: onOpenMaps)
            } message: {
                Text("Möchtest du den Standort in Apple Karten öffnen?")
            }
        }
    }
}
