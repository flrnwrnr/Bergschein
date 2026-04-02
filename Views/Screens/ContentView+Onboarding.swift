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
                        VStack(spacing: 24) {
                            VStack {
                                Image("AppIconPreview")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                    .shadow(color: .black.opacity(0.10), radius: 10, y: 4)
                            }
                            .frame(height: 96, alignment: .top)

                            Spacer()

                            if page.usesEmojiIcon {
                                Text(page.icon)
                                    .font(.system(size: 88))
                            } else {
                                Image(systemName: page.icon)
                                    .font(.system(size: 68, weight: .bold))
                                    .foregroundStyle(Color.accentColor)
                            }

                            Text(page.title)
                                .font(.custom(BrandFont.primaryName, size: 34))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(darkForest)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(page.text)
                                .font(.title3)
                                .fontDesign(.rounded)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 24)

                            if page.requiresLocationAuthorization {
                                Button {
                                    locationController.requestAccessForOnboarding()
                                } label: {
                                    Label(
                                        locationController.hasLocationAccess ? "Standort verwendet" : "Weiter",
                                        systemImage: locationController.hasLocationAccess ? "checkmark" : "location.fill"
                                    )
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                                .font(.headline.weight(.bold))
                                .disabled(locationController.hasLocationAccess)
                            }

                            Spacer()
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
                icon: "location.fill",
                title: "Standort-\nzugriff",
                text: "Die App prüft deinen Standort, da der Check-in nur direkt am Berg möglich ist.",
                requiresLocationAuthorization: true
            ),
            OnboardingPage(
                icon: "checkmark.shield.fill",
                title: "Einfach und kostenlos",
                text: "Die App ist kostenlos, benötigt keinen Account und speichert keine persönlichen Daten. Was will man mehr?"
            ),
            OnboardingPage(
                icon: "gift.fill",
                title: "Verlosung",
                text: "Mit jedem gesammelten Stempel sicherst du dir die Chance auf Preise bei unserer Verlosung. Viel Erfolg!"
            )
        ]
    }
}
