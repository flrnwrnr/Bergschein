//
//  ChallengeViews.swift
//  Bergschein
//

import SwiftUI

struct ChallengeCardView: View {
    let challenge: DailyChallenge
    let isCompleted: Bool
    let showsButton: Bool
    let buttonTitle: String
    let canCheckIn: Bool
    let isWithinZone: Bool
    let darkForest: Color
    let distanceText: String?
    let directionAngle: Double?
    let statusText: String
    let onLocationTap: (() -> Void)?
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(challenge.dateLabel)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(challenge.title)
                        .font(.system(size: 28, weight: .black, design: .serif))
                        .foregroundStyle(darkForest)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 64, height: 64)

                    Text(challenge.icon)
                        .font(.system(size: 38))
                }
            }

            Text(challenge.text)
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                if challenge.startHour != nil {
                    Label(challenge.timeWindowLabel, systemImage: "clock")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if let onLocationTap {
                    Button(action: onLocationTap) {
                        Label(challenge.locationName, systemImage: "mappin.and.ellipse")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                } else {
                    Label(challenge.locationName, systemImage: "mappin.and.ellipse")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if let distanceText {
                    HStack(spacing: 8) {
                        Image(systemName: isWithinZone ? "checkmark.circle.fill" : "location.north.fill")
                            .rotationEffect(.degrees(isWithinZone ? 0 : (directionAngle ?? 0)))
                            .foregroundStyle(.secondary)

                        Text(distanceText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.accentColor.opacity(0.08))
            )

            if isCompleted {
                Label("Challenge abgehakt", systemImage: "checkmark.circle.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else if showsButton {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .disabled(!canCheckIn)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
        )
    }
}

struct ChallengeRewardCardView: View {
    let reward: ChallengeReward
    let isRedeemed: Bool
    let canRedeem: Bool
    let onRedeemTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 52, height: 52)

                    if let imageName = reward.imageName,
                       let uiImage = loadBundleUIImage(named: imageName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    } else {
                        Text(reward.icon)
                            .font(.system(size: 28))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Belohnung")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(reward.title)
                        .font(.title3.weight(.black))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(reward.subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }

                Spacer()
            }

            if let infoURL = reward.infoURL {
                Text(.init("\(reward.details) [Mehr Infos](\(infoURL.absoluteString))"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(reward.details)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(reward.redemptionHint)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if isRedeemed {
                Label("Bereits eingelöst", systemImage: "checkmark.circle.fill")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Button("Einlösen", action: onRedeemTap)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .font(.headline.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .disabled(!canRedeem)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
        )
    }
}
