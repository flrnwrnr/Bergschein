import SwiftUI
import UIKit

struct AdPlaceholderCard: View {
    let darkForest: Color

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.22),
                            Color(.systemGray5)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Color.accentColor.opacity(0.8))
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("WERBUNG")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())

                    Text("Dein Platz am Berg")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(darkForest)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                Text("Hier ist Platz für eine Sponsorenkarte mit kurzem Titel, Bild und einer prägnanten Botschaft.")
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
                .fill(Color.white)
                .shadow(color: .black.opacity(0.05), radius: 18, y: 6)
        )
        .padding(.top, 8)
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
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color.accentColor.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.accentColor.opacity(0.18), lineWidth: 1)
        )
    }
}

struct PermissionWarningCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(Color(red: 0.72, green: 0.21, blue: 0.18))

            Text(text)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(red: 0.48, green: 0.10, blue: 0.10))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 0.99, green: 0.90, blue: 0.88))
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
                    Image(systemName: "location.fill")
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

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.95, green: 0.88, blue: 0.86))
                        .frame(width: 52, height: 52)

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color(red: 0.72, green: 0.21, blue: 0.18))
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
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color(red: 0.98, green: 0.94, blue: 0.93)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color(red: 0.85, green: 0.52, blue: 0.46).opacity(0.28), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct BadgeCardView: View {
    let badge: BadgeDefinition
    let isUnlocked: Bool
    let forceStandardLayout: Bool
    let imageName: String?
    let darkForest: Color
    let onTap: () -> Void

    private var isFeatured: Bool {
        badge.subtitle != nil && !forceStandardLayout
    }

    private var displayedSubtitle: String? {
        forceStandardLayout ? nil : badge.subtitle
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isUnlocked ? Color.accentColor.opacity(isFeatured ? 0.24 : 0.16) : Color(.systemGray5))
                    .padding(.top, isFeatured ? 36 : 30)

                VStack(spacing: 0) {
                    BadgeArtworkView(
                        imageName: imageName,
                        isUnlocked: isUnlocked,
                        isFeatured: isFeatured
                    )

                    VStack(spacing: 8) {
                        Text(badge.name)
                            .font(isFeatured ? .title3.weight(.black) : .headline.weight(.bold))
                            .foregroundStyle(darkForest)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.white.opacity(isUnlocked ? 0.78 : 0.92))
                            )

                        if let displayedSubtitle {
                            Text(displayedSubtitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 2)
                    .padding(.bottom, 12)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isUnlocked)
        .frame(maxWidth: .infinity)
        .frame(height: isFeatured ? 172 : 150)
    }
}

struct BadgePreviewView: View {
    let imageName: String?
    let isUnlocked: Bool

    var body: some View {
        if let imageName {
            BadgeArtworkView(imageName: imageName, isUnlocked: isUnlocked, isFeatured: false)
                .frame(width: 82, height: 82)
        } else {
            Image(systemName: isUnlocked ? "rosette.fill" : "lock.circle")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(isUnlocked ? Color.accentColor : .secondary)
                .frame(width: 82, height: 82)
        }
    }
}

struct BadgeOverlayView: View {
    let presentation: BadgeOverlayPresentation
    let imageName: String?
    let darkForest: Color
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text(presentation.title)
                    .font(.custom(BrandFont.primaryName, size: 30))
                    .foregroundStyle(darkForest)

                Group {
                    if let imageName {
                        BadgeArtworkView(imageName: imageName, isUnlocked: true, isFeatured: true)
                            .scaleEffect(1.42)
                            .offset(y: -8)
                    } else {
                        Image(systemName: "rosette.fill")
                            .font(.system(size: 88))
                            .foregroundStyle(Color.accentColor)
                            .frame(height: 128)
                    }
                }
                .frame(height: 128)

                VStack(spacing: 10) {
                    Text(presentation.badge.name)
                        .font(.title2.weight(.black))
                        .foregroundStyle(darkForest)

                    if let subtitle = presentation.badge.subtitle {
                        Text(subtitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                    Text(presentation.badge.overlayMessage)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(presentation.buttonTitle, action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.white)

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color.accentColor.opacity(0.16)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
            .padding(24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }
}

struct MissedDayOverlayView: View {
    let presentation: MissedDayAlertPresentation
    let darkForest: Color
    let onDismiss: () -> Void

    var body: some View {
        let badge = presentation.missedBadge

        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(Color(red: 0.72, green: 0.21, blue: 0.18))

                Text("Stempel verpasst")
                    .font(.custom(BrandFont.primaryName, size: 30))
                    .foregroundStyle(darkForest)

                VStack(spacing: 10) {
                    Text("Tag \(badge.displayDayIndex) am \(badge.name)")
                        .font(.title3.weight(.black))
                        .foregroundStyle(darkForest)

                    Text("Du hast den Stempel für diesen Tag nicht geholt. Den großen Bergschein kannst du dadurch nicht mehr erreichen, aber du kannst weiterhin alle kommenden Tage sammeln.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button("Verstanden", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(Color(red: 0.72, green: 0.21, blue: 0.18))
                    .foregroundStyle(.white)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.white)

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color(red: 0.98, green: 0.94, blue: 0.93)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
            .padding(24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.94)))
    }
}

struct BadgeArtworkView: View {
    let imageName: String?
    let isUnlocked: Bool
    let isFeatured: Bool

    var body: some View {
        if let imageName, let uiImage = loadBadgeUIImage(named: imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(height: isFeatured ? 128 : 108)
                .opacity(isUnlocked ? 1 : 0.55)
                .saturation(isUnlocked ? 1 : 0)
                .overlay {
                    if !isUnlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: isFeatured ? 18 : 16, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.45))
                            .clipShape(Circle())
                    }
                }
        } else {
            Image(systemName: isUnlocked ? "photo" : "lock.circle")
                .font(.system(size: isFeatured ? 36 : 30))
                .foregroundStyle(isUnlocked ? Color.accentColor : .secondary)
                .frame(height: isFeatured ? 128 : 108)
        }
    }
}

private func loadBadgeUIImage(named imageName: String) -> UIImage? {
    if let assetImage = UIImage(named: imageName) {
        return assetImage
    }

    guard let url = Bundle.main.url(forResource: imageName, withExtension: "png") else {
        return nil
    }

    return UIImage(contentsOfFile: url.path)
}
