//
//  BadgeViews.swift
//  Bergschein
//

import SwiftUI
import UIKit

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
        Button {
                guard isUnlocked else { return }
                onTap()
            } label: {
                cardContent
            }
            .buttonStyle(.plain)
            .disabled(!isUnlocked)
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
