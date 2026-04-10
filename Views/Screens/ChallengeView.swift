//
//  ChallengeView.swift
//  Bergschein
//

import SwiftUI

struct ChallengeView: View {
    let appBackgroundGradient: LinearGradient
    let darkForest: Color
    let hasChallengeSeasonEnded: Bool
    let activeChallenge: DailyChallenge?
    let completedChallengesCount: Int
    let totalChallengesCount: Int
    let shouldShowChallengeButton: Bool
    let activeChallengeButtonTitle: String
    let canCheckInForActiveChallenge: Bool
    let challengeStatusText: String?
    let isChallengeCompleted: (DailyChallenge) -> Bool
    let isWithinChallengeRadius: (DailyChallenge) -> Bool
    let challengeDistanceText: (DailyChallenge) -> String?
    let challengeDirectionAngle: (DailyChallenge) -> Double?
    let unlockedChallengeRewards: [ChallengeReward]
    let isChallengeRewardRedeemed: (ChallengeReward) -> Bool
    let canRedeemChallengeReward: (ChallengeReward) -> Bool
    let onLocationTap: (DailyChallenge) -> Void
    let onClaimChallenge: () -> Void
    let onRedeemChallengeReward: (ChallengeReward) -> Void
    @Binding var challengeMapsAlertIsPresented: Bool
    let onConfirmOpenMaps: () -> Void
    let onDismissOpenMaps: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                appBackgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        if !hasChallengeSeasonEnded {
                            Text(.init("Hier findest du an jedem Bergtag eine Challenge rund um das Thema Kirchweih und Erlangen. Du kannst nur an genau diesem Tag mitmachen und an ausgewählten Tagen eine **Belohnung** erhalten."))
                                .font(.footnote.weight(.medium))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary.opacity(0.9))
                                .frame(maxWidth: .infinity)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        if !unlockedChallengeRewards.isEmpty {
                            NavigationLink {
                                ChallengeRewardsView(
                                    appBackgroundGradient: appBackgroundGradient,
                                    rewards: unlockedChallengeRewards,
                                    isChallengeRewardRedeemed: isChallengeRewardRedeemed,
                                    canRedeemChallengeReward: canRedeemChallengeReward,
                                    onRedeemChallengeReward: onRedeemChallengeReward
                                )
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "gift.fill")
                                    Text("Belohnungen")
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
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
                                distanceText: challengeDistanceText(activeChallenge),
                                directionAngle: challengeDirectionAngle(activeChallenge),
                                statusText: challengeStatusText ?? "",
                                onLocationTap: activeChallenge.centerCoordinate == nil ? nil : {
                                    onLocationTap(activeChallenge)
                                },
                                action: onClaimChallenge
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
            .alert("In Apple Karten öffnen?", isPresented: $challengeMapsAlertIsPresented) {
                Button("Abbrechen", role: .cancel, action: onDismissOpenMaps)
                Button("Öffnen", action: onConfirmOpenMaps)
            } message: {
                Text("Möchtest du den Ort dieser Challenge in Apple Karten öffnen?")
            }
        }
    }
}

private struct ChallengeRewardsView: View {
    @State private var rewardRedeemAlertIsPresented = false
    @State private var rewardPendingRedeem: ChallengeReward?

    let appBackgroundGradient: LinearGradient
    let rewards: [ChallengeReward]
    let isChallengeRewardRedeemed: (ChallengeReward) -> Bool
    let canRedeemChallengeReward: (ChallengeReward) -> Bool
    let onRedeemChallengeReward: (ChallengeReward) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(rewards) { reward in
                    ChallengeRewardCardView(
                        reward: reward,
                        isRedeemed: isChallengeRewardRedeemed(reward),
                        canRedeem: canRedeemChallengeReward(reward),
                        onRedeemTap: {
                            rewardPendingRedeem = reward
                            rewardRedeemAlertIsPresented = true
                        }
                    )
                }
            }
            .padding(16)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .background(appBackgroundGradient.ignoresSafeArea())
        .navigationTitle("Belohnungen")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Belohnung einlösen?", isPresented: $rewardRedeemAlertIsPresented) {
            Button("Abbrechen", role: .cancel) { }
            Button("Einlösen", role: .destructive) {
                guard let rewardPendingRedeem else {
                    return
                }
                onRedeemChallengeReward(rewardPendingRedeem)
            }
        } message: {
            if let rewardPendingRedeem {
                Text(rewardPendingRedeem.redemptionHint)
            } else {
                Text("Diese Aktion kann nur einmal durchgeführt werden.")
            }
        }
    }
}
