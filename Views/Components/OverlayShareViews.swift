//
//  OverlayShareViews.swift
//  Bergschein
//

import SwiftUI
import UIKit

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
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

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
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)

                        if let subtitle = presentation.subtitleOverride ?? presentation.badge.subtitle {
                            Text(subtitle)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Text(presentation.messageOverride ?? presentation.badge.overlayMessage)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
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
                .accessibilityLabel("Badge teilen")
                .accessibilityHint("Öffnet das Teilen-Menü")
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

struct TipThankYouOverlayView: View {
    let message: String
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
                Text("Danke!")
                    .font(.custom(BrandFont.primaryName, size: 34, relativeTo: .title2))
                    .fontWeight(.regular)
                    .tracking(0.3)
                    .foregroundStyle(darkForest)

                Text("🍻")
                    .font(.system(size: 56))

                Text(message)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Schließen", action: onDismiss)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(uiColor: .systemBackground))
            )
            .shadow(color: .black.opacity(0.18), radius: 22, y: 10)
            .padding(.horizontal, 24)
            .scaleEffect(animateIn ? 1 : 0.94)
            .offset(y: animateIn ? 0 : 24)
            .opacity(animateIn ? 1 : 0)
            .transition(overlayCardTransition)
        }
        .onAppear {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.82)) {
                animateIn = true
            }
        }
    }
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
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

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
                        .fixedSize(horizontal: false, vertical: true)

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

struct ChallengeRewardOverlayView: View {
    let presentation: ChallengeRewardOverlayPresentation
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
                Text("Belohnung frei-\ngeschaltet")
                    .font(.custom(BrandFont.primaryName, size: 30))
                    .foregroundStyle(darkForest)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 104, height: 104)

                    if let imageName = presentation.reward.imageName,
                       let uiImage = loadBundleUIImage(named: imageName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 104, height: 104)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    } else {
                        Text(presentation.reward.icon)
                            .font(.system(size: 52))
                    }
                }

                VStack(spacing: 10) {
                    Text(presentation.reward.subtitle)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(presentation.reward.details)
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
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    Text("Tag \(badge.displayDayIndex) am \(badge.name)")
                        .font(.title3.weight(.black))
                        .foregroundStyle(darkForest)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Du hast den Stempel für diesen Tag nicht geholt. Den großen Bergschein kannst du dadurch nicht mehr erreichen, aber du kannst weiterhin alle kommenden Tage sammeln.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
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
