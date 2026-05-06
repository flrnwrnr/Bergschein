//
//  StatusViews.swift
//  Bergschein
//

import SwiftUI
import UIKit

struct AdBannerCard: View {
    let banner: AdBanner
    let darkForest: Color

    var body: some View {
        Link(destination: banner.url) {
            HStack(alignment: .top, spacing: 14) {
                Group {
                    if let imageName = banner.imageName, UIImage(named: imageName) != nil {
                        Image(imageName)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.accentColor.opacity(0.14))
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundStyle(Color.accentColor.opacity(0.8))
                            }
                    }
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("WERBUNG")
                            .font(.caption2.weight(.black))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12))
                            .clipShape(Capsule())

                        Text(banner.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(darkForest)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    Text(banner.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.adCardBackground)
                    .shadow(color: Color.appSoftShadow.opacity(0.22), radius: 18, y: 6)
            )
            .padding(.top, 8)
        }
        .buttonStyle(.plain)
    }
}

struct ProgressSectionView: View {
    let badgeDefinitions: [BadgeDefinition]
    let unlockedBadges: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Fortschritt")
                    .font(.subheadline.weight(.bold))
                Spacer()
                Text("\(unlockedBadges.count) / \(badgeDefinitions.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(badgeDefinitions) { badge in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(unlockedBadges.contains(badge.id) ? Color.accentColor : Color.accentColor.opacity(0.18))
                        .frame(maxWidth: .infinity)
                        .frame(height: 18)
                }
            }
        }
    }
}

struct StreakStatusCard: View {
    let streak: Int
    let darkForest: Color
    let backgroundStyle: AnyShapeStyle

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.16))
                    .frame(width: 52, height: 52)

                Image(systemName: "flame.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Aktueller Streak")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text("\(streak) Tage am Stück")
                    .font(.title3.weight(.black))
                    .foregroundStyle(darkForest)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(backgroundStyle)
        )
    }
}

struct PermissionWarningCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(Color.appWarningTint)

            Text(text)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.appWarningBackground)
        )
    }
}

struct DistanceStatusView: View {
    let isInAllowedRegion: Bool
    let distanceText: String?
    let directionAngle: Double
    let onTap: () -> Void

    var body: some View {
        Group {
            if isInAllowedRegion {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .foregroundStyle(.secondary)

                    Text("Du bist am Berg")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            } else if let distanceText {
                Button(action: onTap) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.north.fill")
                            .rotationEffect(.degrees(directionAngle))
                            .foregroundStyle(.secondary)

                        Text("\(distanceText) bis zum Berg")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .buttonStyle(.plain)
            }
        }
    }
}

struct MissedBergscheinNoticeCard: View {
    let badge: BadgeDefinition
    let darkForest: Color
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: onTap) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.appWarningBackground)
                            .frame(width: 52, height: 52)

                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.appWarningTint)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Großer Bergschein nicht mehr erreichbar")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(darkForest)
                            .multilineTextAlignment(.leading)

                        Text("Du hast einen Tag verpasst. Du kannst aber weiter sammeln.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.appWarningBackground.opacity(0.34))
                )
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary.opacity(0.75))
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .padding(.trailing, 6)
        }
    }
}

struct AfterBergLocationCard: View {
    let location: AfterBergLocation
    let darkForest: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 52, height: 52)

                    Text(location.marker)
                        .font(.system(size: 36))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(darkForest)

                    Text(location.category)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)

                    Text(location.address)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text(location.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Link(destination: location.website) {
                Label("Webseite öffnen", systemImage: "safari")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.appCardBackground.opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.appSoftStroke, lineWidth: 1)
        )
        .shadow(color: Color.appSoftShadow.opacity(0.4), radius: 16, y: 6)
    }
}
