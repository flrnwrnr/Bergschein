//
//  CreditsView.swift
//  Bergschein
//

import SwiftUI

struct CreditsView: View {
    let backgroundGradient: LinearGradient
    let onLogoTap: () -> Void

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            List {
                Section {
                    VStack(spacing: 12) {
                        Image("ffwd_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 88, height: 88)
                            .padding(10)
                            .background(Color.primary.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
                            .onTapGesture(perform: onLogoTap)

                        Text("FFWD Ventures")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                Section("Über") {
                    Text("Diese App wird von FFWD Ventures betrieben, einer innovativen Softwarefirma für die Entwicklung digitaler Produkte und Services. Neben eigenen Apps entstehen dort auch individuelle Auftragsarbeiten. Ziel sind einfache, effektive und benutzerfreundliche Lösungen.")
                }

                Section("Impressum") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FFWD Florian Werner Digital Ventures")
                        Text("Marquardsenstr. 4")
                        Text("91054 Erlangen")
                        Text("Deutschland")
                        Text("E-Mail: contact@ffwdventures.de")
                        Text("Telefon: +49 176 608832")
                        Text("Vertreten durch Florian Werner")
                    }
                }

                Section("Mehr") {
                    Link(destination: URL(string: "https://www.ffwdventures.de")!) {
                        Label("Webseite", systemImage: "safari")
                            .foregroundStyle(.primary)
                    }

                    Link(destination: URL(string: "mailto:contact@ffwdventures.de")!) {
                        Label("Kontakt", systemImage: "envelope")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Über")
    }
}
