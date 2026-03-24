import SwiftUI
import UIKit

private let overlayCardTransition = AnyTransition.asymmetric(
    insertion: .opacity
        .combined(with: .scale(scale: 0.90, anchor: .center))
        .combined(with: .offset(y: 18)),
    removal: .opacity
        .combined(with: .scale(scale: 0.96, anchor: .center))
)

private extension Color {
    static let appCardBackground = Color(uiColor: .secondarySystemBackground)
    static let appElevatedBackground = Color(uiColor: .tertiarySystemBackground)
    static let appSoftStroke = Color.primary.opacity(0.10)
    static let appSoftShadow = Color.black.opacity(0.14)
    static let appWarningTint = Color(red: 0.72, green: 0.21, blue: 0.18)
    static let appWarningText = Color(red: 0.48, green: 0.10, blue: 0.10)
    static let appWarningBackground = Color.appWarningTint.opacity(0.14)
    static let adCardBackground = Color(
        uiColor: UIColor { traitCollection in
            if traitCollection.userInterfaceStyle == .dark {
                return UIColor(red: 0.10, green: 0.13, blue: 0.11, alpha: 1.0)
            }

            return UIColor(red: 0.97, green: 0.985, blue: 0.972, alpha: 1.0)
        }
    )
}

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
                Button(buttonTitle) {
                    action()
                }
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

    var body: some View {
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
    }
}

struct BadgeCardView: View {
    @Environment(\.openURL) private var openURL
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
        cardContent
            .contentShape(Rectangle())
            .onTapGesture {
                guard isUnlocked else { return }
                onTap()
            }
            .frame(maxWidth: .infinity)
            .frame(height: isFeatured ? 188 : 150)
    }

    private var cardContent: some View {
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isUnlocked ? Color.accentColor.opacity(isFeatured ? 0.26 : 0.18) : Color.appElevatedBackground)
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
                                    .fill(Color.appCardBackground.opacity(isUnlocked ? 0.88 : 0.96))
                            )

                        if let displayedSubtitle {
                            Text(displayedSubtitle)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }

                        if isFeatured,
                           let sponsorLabel = badge.sponsorLabel,
                           let sponsorLogoName = badge.sponsorLogoName,
                           let sponsorURL = badge.sponsorURL {
                            Button {
                                openURL(sponsorURL)
                            } label: {
                                HStack(spacing: 8) {
                                    Text(sponsorLabel)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.secondary)

                                    if UIImage(named: sponsorLogoName) != nil {
                                        Image(sponsorLogoName)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 18)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 2)
                    .padding(.bottom, 12)
                }
            }
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
    let onShare: () -> Void
    let onDismiss: () -> Void
    @State private var animateIn = false
    @State private var animateBadge = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(animateIn ? 1 : 0)
                .transition(.opacity)

            Color.black.opacity(animateIn ? 0.22 : 0)
                .ignoresSafeArea()
                .transition(.opacity)

            ZStack(alignment: .topTrailing) {
                VStack(spacing: 18) {
                    Text(presentation.title)
                        .font(.custom(BrandFont.primaryName, size: 30))
                        .foregroundStyle(darkForest)

                    Group {
                        if let imageName {
                            BadgeArtworkView(imageName: imageName, isUnlocked: true, isFeatured: true)
                                .scaleEffect(animateBadge ? 1.42 : 0.74)
                                .offset(y: -8)
                        } else {
                            Image(systemName: "rosette.fill")
                                .font(.system(size: 88))
                                .foregroundStyle(Color.accentColor)
                                .frame(height: 128)
                                .scaleEffect(animateBadge ? 1 : 0.72)
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

                Button(action: onShare) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(darkForest)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.appElevatedBackground)
                        )
                }
                .buttonStyle(.plain)
                .padding(18)
            }
            .frame(maxWidth: 340)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.appCardBackground)

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.appCardBackground, Color.accentColor.opacity(0.20)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.appSoftStroke, lineWidth: 1)
            )
            .shadow(color: Color.appSoftShadow.opacity(animateIn ? 1 : 0.35), radius: 24, y: 12)
            .padding(24)
            .scaleEffect(animateIn ? 1 : 0.92)
            .offset(y: animateIn ? 0 : 22)
            .opacity(animateIn ? 1 : 0)
            .transition(overlayCardTransition)
        }
        .onAppear {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.84)) {
                animateIn = true
            }

            withAnimation(.spring(response: 0.52, dampingFraction: 0.72).delay(0.05)) {
                animateBadge = true
            }
        }
    }
}

struct BadgeShareGraphicView: View {
    let presentation: BadgeOverlayPresentation
    let imageName: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.75, green: 0.91, blue: 0.67),
                    Color(red: 0.31, green: 0.65, blue: 0.28),
                    Color(red: 0.11, green: 0.39, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                Text("Der Bergschein")
                    .font(.custom(BrandFont.primaryName, size: 56))
                    .foregroundStyle(Color(red: 0.14, green: 0.22, blue: 0.16))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 78)
                    .padding(.horizontal, 148)

                Spacer(minLength: 28)

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 540, height: 540)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.96), Color.white.opacity(0.62)],
                                center: .center,
                                startRadius: 40,
                                endRadius: 240
                            )
                        )
                        .frame(width: 430, height: 430)

                    Group {
                        if let imageName, let uiImage = loadBadgeUIImage(named: imageName) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 470, height: 470)
                                .shadow(color: .black.opacity(0.1), radius: 16, y: 10)
                        } else {
                            Image(systemName: "rosette.fill")
                                .font(.system(size: 340))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 470, height: 470)
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 18)

                VStack(spacing: 8) {
                    Text("Bergtag \(presentation.badge.displayDayIndex)")
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.14, green: 0.22, blue: 0.16))

                    Text(presentation.badge.name)
                        .font(.system(size: 26, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.14, green: 0.22, blue: 0.16).opacity(0.82))
                }
                .frame(maxWidth: 332)
                .padding(.horizontal, 42)
                .padding(.vertical, 20)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.88))
                )

                Spacer(minLength: 34)

                VStack(spacing: 16) {
                    Text("Hol dir die App und mach mit")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 140)

                    if UIImage(named: "AppStoreBadge") != nil {
                        Image("AppStoreBadge")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 640)
                            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
                    }
                }
                .padding(.bottom, 34)
            }
        }
        .frame(width: 1080, height: 1080)
    }
}

struct BergscheinShareGraphicView: View {
    let visitedDays: Int
    let totalDays: Int
    let imageName: String?

    private var progressText: String {
        "\(visitedDays)/\(totalDays)"
    }

    private var summaryText: String {
        if visitedDays >= totalDays {
            return "Alle \(totalDays) Bergtage besucht"
        }

        return "\(visitedDays) von \(totalDays) Bergtagen besucht"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.75, green: 0.91, blue: 0.67),
                    Color(red: 0.31, green: 0.65, blue: 0.28),
                    Color(red: 0.11, green: 0.39, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                Text("Der Bergschein")
                    .font(.custom(BrandFont.primaryName, size: 56))
                    .foregroundStyle(Color(red: 0.14, green: 0.22, blue: 0.16))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .padding(.top, 78)
                    .padding(.horizontal, 148)

                Spacer(minLength: 34)

                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.14))
                            .frame(width: 560, height: 560)

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.white.opacity(0.97), Color.white.opacity(0.64)],
                                    center: .center,
                                    startRadius: 50,
                                    endRadius: 250
                                )
                            )
                            .frame(width: 450, height: 450)

                        Group {
                            if let imageName, let uiImage = loadBadgeUIImage(named: imageName) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 470, height: 470)
                                    .shadow(color: .black.opacity(0.1), radius: 16, y: 10)
                            } else {
                                Image(systemName: "rosette.fill")
                                    .font(.system(size: 340))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 470, height: 470)
                            }
                        }
                    }

                    Text(progressText)
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 14)
                        .background(
                            Capsule(style: .continuous)
                                .fill(Color(red: 0.14, green: 0.22, blue: 0.16).opacity(0.92))
                        )
                        .offset(x: 10, y: 24)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 20)

                VStack(spacing: 8) {
                    Text(summaryText)
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(red: 0.14, green: 0.22, blue: 0.16))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Zeig deinen aktuellen Bergschein-Stand")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.14, green: 0.22, blue: 0.16).opacity(0.82))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 620)
                .padding(.horizontal, 42)
                .padding(.vertical, 24)
                .background(
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(Color.white.opacity(0.88))
                )

                Spacer(minLength: 34)

                VStack(spacing: 16) {
                    Text("Hol dir die App und mach mit")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 140)

                    if UIImage(named: "AppStoreBadge") != nil {
                        Image("AppStoreBadge")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 640)
                            .shadow(color: .black.opacity(0.18), radius: 14, y: 8)
                    }
                }
                .padding(.bottom, 34)
            }
        }
        .frame(width: 1080, height: 1080)
    }
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

struct ChallengeOverlayView: View {
    let presentation: ChallengeOverlayPresentation
    let darkForest: Color
    let onDismiss: () -> Void
    @State private var animateIn = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(animateIn ? 1 : 0)
                .transition(.opacity)

            Color.black.opacity(animateIn ? 0.22 : 0)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 18) {
                Text(presentation.challenge.completionTitle)
                    .font(.custom(BrandFont.primaryName, size: 30))
                    .foregroundStyle(darkForest)

                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 104, height: 104)

                    Text(presentation.challenge.icon)
                        .font(.system(size: 54))
                }

                VStack(spacing: 10) {
                    Text(presentation.challenge.title)
                        .font(.title2.weight(.black))
                        .foregroundStyle(darkForest)
                        .multilineTextAlignment(.center)

                    Text(presentation.challenge.dateLabel)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)

                    Text(presentation.challenge.completionMessage)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button("Schließen", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.appCardBackground)

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.appCardBackground, Color.accentColor.opacity(0.16)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.appSoftStroke, lineWidth: 1)
            )
            .shadow(color: Color.appSoftShadow.opacity(animateIn ? 1 : 0.35), radius: 24, y: 12)
            .padding(24)
            .scaleEffect(animateIn ? 1 : 0.92)
            .offset(y: animateIn ? 0 : 22)
            .opacity(animateIn ? 1 : 0)
            .transition(overlayCardTransition)
        }
        .onAppear {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.84)) {
                animateIn = true
            }
        }
    }
}


struct MissedDayOverlayView: View {
    let presentation: MissedDayAlertPresentation
    let darkForest: Color
    let onDismiss: () -> Void
    @State private var animateIn = false

    var body: some View {
        let badge = presentation.missedBadge

        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(animateIn ? 1 : 0)
                .transition(.opacity)

            Color.black.opacity(animateIn ? 0.22 : 0)
                .ignoresSafeArea()
                .transition(.opacity)

            VStack(spacing: 18) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(Color.appWarningTint)

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
                    .tint(Color.appWarningTint)
                    .foregroundStyle(.white)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(Color.appCardBackground)

                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.appCardBackground, Color.appWarningBackground],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(Color.appSoftStroke, lineWidth: 1)
            )
            .shadow(color: Color.appSoftShadow.opacity(animateIn ? 1 : 0.35), radius: 24, y: 12)
            .padding(24)
            .scaleEffect(animateIn ? 1 : 0.94)
            .offset(y: animateIn ? 0 : 18)
            .opacity(animateIn ? 1 : 0)
            .transition(overlayCardTransition)
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                animateIn = true
            }
        }
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
    loadBundleUIImage(named: imageName)
}

private func loadBundleUIImage(named imageName: String) -> UIImage? {
    if let assetImage = UIImage(named: imageName) {
        return assetImage
    }

    guard let url = Bundle.main.url(forResource: imageName, withExtension: "png") else {
        return nil
    }

    return UIImage(contentsOfFile: url.path)
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
