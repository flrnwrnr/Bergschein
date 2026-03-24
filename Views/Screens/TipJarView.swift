//
//  TipJarView.swift
//  Bergschein
//

import StoreKit
import SwiftUI

struct TipJarView: View {
    let backgroundGradient: LinearGradient
    let darkForest: Color
    @ObservedObject var tipJarStore: TipJarStore
    let overlayDismissAnimation: Animation
    let onTipSuccess: () -> Void

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Wenn dir die App gefällt, kannst du hier freiwillig Trinkgeld dalassen.")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("Die Unterstützung hilft bei Weiterentwicklung, Betrieb und neuen Ideen rund um die App für die kommenden Jahre.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }

                if tipJarStore.isLoading {
                    Section {
                        HStack(spacing: 12) {
                            ProgressView()
                            Text("Trinkgeldoptionen werden geladen …")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                } else {
                    Section("Optionen") {
                        ForEach(tipJarStore.products, id: \.id) { product in
                            Button {
                                Task {
                                    await tipJarStore.purchase(product)
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Text(tipJarStore.emoji(for: product.id))
                                        .font(.system(size: 34))
                                        .frame(width: 44)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(tipJarStore.title(for: product))
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(.primary)

                                        Text(tipJarStore.subtitle(for: product))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    Spacer()

                                    if tipJarStore.purchaseInProgressProductID == product.id {
                                        ProgressView()
                                    } else {
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(product.displayPrice)
                                                .font(.headline.weight(.black))
                                                .foregroundStyle(Color.accentColor)

                                            Image(systemName: "chevron.right")
                                                .font(.footnote.weight(.bold))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 2)
                            }
                            .disabled(tipJarStore.purchaseInProgressProductID != nil)
                        }
                    }
                }

                if let errorMessage = tipJarStore.errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .scrollContentBackground(.hidden)

            if let successMessage = tipJarStore.successMessage {
                TipThankYouOverlayView(
                    message: successMessage,
                    darkForest: darkForest,
                    onDismiss: {
                        withAnimation(overlayDismissAnimation) {
                            tipJarStore.successMessage = nil
                        }
                    }
                )
            }
        }
        .navigationTitle("Trinkgeld")
        .task {
            await tipJarStore.loadProducts()
        }
        .onChange(of: tipJarStore.successMessage) { _, newValue in
            if newValue != nil {
                onTipSuccess()
            }
        }
    }
}
