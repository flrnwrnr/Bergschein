import SwiftUI

struct CommunityView: View {
    @Environment(\.dismiss) private var dismiss
    let appBackgroundGradient: LinearGradient
    let analyticsService: AnalyticsService
    let ownCheckins: Int
    @State private var stats: CommunityStats?
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                appBackgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if isLoading {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Community-Daten werden geladen ...")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.systemBackground).opacity(0.72))
                            )
                        } else if let errorMessage {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Community-Daten aktuell nicht verfügbar")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text(errorMessage)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)

                                Button("Erneut laden") {
                                    Task {
                                        await loadCommunityStats()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.systemBackground).opacity(0.72))
                            )
                        } else if let stats {
                            let rankedDistribution = stats.distribution
                                .filter { $0.users > 0 }
                                .sorted { lhs, rhs in
                                    if lhs.checkins == rhs.checkins {
                                        return lhs.percentage > rhs.percentage
                                    }
                                    return lhs.checkins > rhs.checkins
                                }
                            let maxPercentage = rankedDistribution.map(\.percentage).max() ?? 1

                            if rankedDistribution.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Sei ganz vorne dabei!")
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Text("Sobald die ersten Stempel gesammelt sind, siehst du hier, wie oft die Community auf dem Berg war und wie du dich im Vergleich schlägst.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(.systemBackground).opacity(0.72))
                                )
                            } else {
                                VStack(alignment: .leading, spacing: 14) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("So schlägst du dich im Vergleich")
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color(.systemBackground).opacity(0.55))
                                    )

                                    ForEach(Array(rankedDistribution.enumerated()), id: \.element.id) { index, bucket in
                                        let isOwnBucket = bucket.checkins == ownCheckins
                                        let rankColor: Color = {
                                            switch index {
                                            case 0: return Color(red: 0.78, green: 0.63, blue: 0.20)
                                            case 1: return Color(red: 0.58, green: 0.62, blue: 0.66)
                                            case 2: return Color(red: 0.66, green: 0.44, blue: 0.30)
                                            default: return .accentColor
                                            }
                                        }()

                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack(spacing: 8) {
                                                Text("#\(index + 1)")
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(rankColor)
                                                    .frame(width: 28, alignment: .leading)

                                                Text("\(bucket.checkins)x eingecheckt")
                                                    .font(.subheadline.weight(.semibold))

                                                if isOwnBucket {
                                                    Text("Du")
                                                        .font(.caption2.weight(.bold))
                                                        .foregroundStyle(.white)
                                                        .padding(.horizontal, 7)
                                                        .padding(.vertical, 3)
                                                        .background(
                                                            Capsule(style: .continuous)
                                                                .fill(Color.accentColor)
                                                        )
                                                }

                                                Spacer()

                                                Text(String(format: "%.1f%%", bucket.percentage))
                                                    .font(.caption.weight(.bold))
                                                    .foregroundStyle(.primary)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(
                                                        Capsule(style: .continuous)
                                                            .fill(Color(.systemBackground).opacity(0.9))
                                                    )
                                            }

                                            GeometryReader { geometry in
                                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                    .fill(Color.accentColor.opacity(0.2))
                                                    .overlay(alignment: .leading) {
                                                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                                                            .fill(Color.accentColor)
                                                            .frame(width: geometry.size.width * CGFloat(max(0, bucket.percentage) / maxPercentage))
                                                    }
                                            }
                                            .frame(height: 10)
                                        }
                                        .padding(12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(isOwnBucket ? Color.accentColor.opacity(0.12) : Color(.systemBackground).opacity(0.55))
                                        )
                                    }

                                    Text("Die Prozentwerte zeigen, wie viel Prozent der App-Nutzer wie oft auf dem Berg waren.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary.opacity(0.75))
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(Color(.systemBackground).opacity(0.72))
                                )
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Noch keine Community-Daten")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                Text("Sobald die ersten Nutzer eingecheckt haben, werden die relativen Community-Werte hier angezeigt.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.systemBackground).opacity(0.72))
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Community")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Schließen") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadCommunityStats()
        }
    }

    private func loadCommunityStats() async {
        let hadStatsBeforeReload = (stats != nil)
        isLoading = true
        errorMessage = nil

        do {
            if let fetchedStats = try await analyticsService.fetchCommunityStats() {
                stats = fetchedStats
            } else if !hadStatsBeforeReload {
                stats = nil
                errorMessage = "Bitte versuche es in ein paar Sekunden erneut."
            }
        } catch is CancellationError {
            // Pull-to-refresh can cancel in-flight work; do not surface this as an error state.
            isLoading = false
            return
        } catch {
            if !hadStatsBeforeReload {
                stats = nil
                errorMessage = "Bitte versuche es in ein paar Sekunden erneut."
            }
        }

        isLoading = false
    }
}
