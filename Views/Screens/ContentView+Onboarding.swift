import CoreLocation
import SwiftUI

extension ContentView {
    var onboardingView: some View {
        let pages = onboardingPages

        return ZStack {
            LinearGradient(
                colors: onboardingBackgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                TabView(selection: $onboardingSelection) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        VStack(spacing: page.showsRafflePrizes ? 16 : 24) {
                            VStack {
                                Image("AppIconPreview")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                    .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
                            }
                            .frame(height: 96, alignment: .top)

                            if !page.showsRafflePrizes {
                                Spacer()
                            }

                            if page.usesEmojiIcon {
                                Text(page.icon)
                                    .font(.system(size: page.showsRafflePrizes ? 68 : 88))
                            } else {
                                Image(systemName: page.icon)
                                    .font(.system(size: page.showsRafflePrizes ? 52 : 68, weight: .bold))
                                    .foregroundStyle(Color.accentColor)
                            }

                            Text(page.title)
                                .font(.custom(BrandFont.primaryName, size: page.showsRafflePrizes ? 30 : 34))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(darkForest)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(
                                page.requiresLocationAuthorization &&
                                (locationController.authorizationStatus == .denied || locationController.authorizationStatus == .restricted)
                                ? "Ohne Standortzugriff kann der Check-in am Berg nicht verifiziert werden. Bitte aktiviere den Standortzugriff in den Systemeinstellungen, um fortzufahren."
                                : page.text
                            )
                                .font(page.showsRafflePrizes ? .body : .title3)
                                .fontDesign(.rounded)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 24)
                                .fixedSize(horizontal: false, vertical: true)

                            if page.showsRafflePrizes {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(rafflePrizeItems) { prize in
                                        HStack(spacing: 10) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(Color.accentColor.opacity(0.12))
                                                if let prizeImageName = prize.prizeImageName {
                                                    Image(prizeImageName)
                                                        .resizable()
                                                        .scaledToFit()
                                                        .padding(1)
                                                } else {
                                                    Text(prize.prizeSymbol)
                                                        .font(.title3)
                                                }
                                            }
                                            .frame(width: 34, height: 34)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(prize.title)
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(darkForest)
                                                Text(prize.text)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(2)
                                            }

                                            Spacer(minLength: 0)

                                            Image(prize.sponsorImageName)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 28, height: 28)
                                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(Color(.systemBackground).opacity(0.65))
                                        )
                                    }
                                }
                                .padding(.horizontal, 18)
                            }

                            if page.requiresLocationAuthorization {
                                Button {
                                    locationController.requestAccessForOnboarding()
                                } label: {
                                    Label(
                                        locationController.hasLocationAccess
                                            ? "Standort verwendet"
                                            : ((locationController.authorizationStatus == .denied || locationController.authorizationStatus == .restricted) ? "Verweigert" : "Weiter"),
                                        systemImage: locationController.hasLocationAccess
                                            ? "checkmark"
                                            : ((locationController.authorizationStatus == .denied || locationController.authorizationStatus == .restricted) ? "xmark.circle.fill" : "location.fill")
                                    )
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .font(.headline.weight(.bold))
                                .tint((locationController.authorizationStatus == .denied || locationController.authorizationStatus == .restricted) ? .red : .accentColor)
                                .disabled(locationController.hasLocationAccess)
                            }

                            if !page.showsRafflePrizes {
                                Spacer()
                            }
                        }
                        .padding(24)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .gesture(
                    DragGesture().onEnded { value in
                        let isLocationPage = onboardingSelection == 1
                        let wantsToAdvance = value.translation.width < -40

                        if isLocationPage && wantsToAdvance && !locationController.hasLocationAccess {
                            onboardingSelection = 1
                        }
                    }
                )
                .onChange(of: onboardingSelection) { _, newValue in
                    if newValue > 1 && !locationController.hasLocationAccess {
                        onboardingSelection = 1
                    }
                }
                .onChange(of: locationController.authorizationStatus) { _, _ in
                    if onboardingSelection == 1 && locationController.hasLocationAccess {
                        triggerSelectionHaptic()
                    }
                }

                Button(onboardingSelection == pages.count - 1 ? "Los geht’s" : "Weiter") {
                    if onboardingSelection == pages.count - 1 {
                        hasSeenOnboarding = true
                        locationController.requestLocationAccess()
                    } else {
                        if onboardingSelection == 1 && !locationController.hasLocationAccess {
                            locationController.requestAccessForOnboarding()
                            return
                        }
                        onboardingSelection += 1
                        triggerSelectionHaptic()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .font(.headline.weight(.bold))
                .disabled(onboardingSelection == 1 && !locationController.hasLocationAccess)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
    }

    var onboardingPages: [OnboardingPage] {
        [
            OnboardingPage(
                icon: "🎡",
                title: "Der Bergschein ist zurück!",
                text: "Hol dir für jeden Tag deinen Stempel am Berg ab und mach den großen Bergschein."
            ),
            OnboardingPage(
                icon: "🧭",
                title: "Standort-\nzugriff",
                text: "Die App prüft deinen Standort, da der Check-in nur direkt am Berg möglich ist.",
                requiresLocationAuthorization: true
            ),
            OnboardingPage(
                icon: "🎁",
                title: "Verlosung",
                text: "Nimm unter 'Mehr' an der Verlosung teil. Verlost werden drei Preise per Los gemäß Teilnahmebedingungen. Viel Erfolg!",
                showsRafflePrizes: true
            )
        ]
    }
}
