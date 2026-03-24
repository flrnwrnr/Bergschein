//
//  BergscheinView.swift
//  Bergschein
//

import SwiftUI

struct BergscheinView: View {
    let appBackgroundGradient: LinearGradient
    let badgeDefinitions: [BadgeDefinition]
    let unlockedBadges: Set<String>
    let blockingMissedBadge: BadgeDefinition?
    let dismissedMissedBadgeIdentifier: String
    let darkForest: Color
    let overlayPresentationAnimation: Animation
    let standardBadges: (BadgeCategory) -> [BadgeDefinition]
    let featuredBadge: (BadgeCategory) -> BadgeDefinition?
    let resolvedImageName: (BadgeDefinition) -> String?
    let onMissedBadgeTap: (BadgeDefinition) -> Void
    let onBadgeTap: (BadgeDefinition) -> Void
    let onShareTap: () -> Void

    var body: some View {
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
                                        onMissedBadgeTap(blockedBadge)
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
                                        imageName: resolvedImageName(badge),
                                        darkForest: darkForest,
                                        onTap: {
                                            withAnimation(overlayPresentationAnimation) {
                                                onBadgeTap(badge)
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
                                        ForEach(standardBadges(category)) { badge in
                                            BadgeCardView(
                                                badge: badge,
                                                isUnlocked: unlockedBadges.contains(badge.id),
                                                forceStandardLayout: false,
                                                imageName: resolvedImageName(badge),
                                                darkForest: darkForest,
                                                onTap: {
                                                    withAnimation(overlayPresentationAnimation) {
                                                        onBadgeTap(badge)
                                                    }
                                                }
                                            )
                                        }
                                    }

                                    if let featuredBadge = featuredBadge(category) {
                                        BadgeCardView(
                                            badge: featuredBadge,
                                            isUnlocked: unlockedBadges.contains(featuredBadge.id),
                                            forceStandardLayout: false,
                                            imageName: resolvedImageName(featuredBadge),
                                            darkForest: darkForest,
                                            onTap: {
                                                withAnimation(overlayPresentationAnimation) {
                                                    onBadgeTap(featuredBadge)
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
                        Button(action: onShareTap) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Bergschein teilen")
                    }
                }
            }
        }
    }
}
