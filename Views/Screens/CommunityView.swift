import SwiftUI

struct CommunityView: View {
    let appBackgroundGradient: LinearGradient
    let analyticsService: AnalyticsService
    @State private var stats: CommunityStats?
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var averageCheckinsText: String {
        guard let stats else { return "-" }
        return String(format: "%.1f", stats.averageCheckins)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                appBackgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Hier siehst du bald, wie oft die Community insgesamt auf dem Berg eingecheckt hat.")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)

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
                        } else if let stats, stats.totalCollectors > 0 {
                            HStack(spacing: 12) {
                                communityMetricCard(
                                    title: "Sammler",
                                    value: "\(stats.totalCollectors)"
                                )
                                communityMetricCard(
                                    title: "Ø Check-ins",
                                    value: averageCheckinsText
                                )
                                communityMetricCard(
                                    title: "Bestwert",
                                    value: "\(stats.maxCheckins)"
                                )
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Verteilung")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                ForEach(stats.distribution) { bucket in
                                    HStack {
                                        Text("\(bucket.checkins)x")
                                            .font(.subheadline.weight(.semibold))
                                            .frame(width: 42, alignment: .leading)

                                        Text("\(bucket.users) Nutzer")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)

                                        Spacer()

                                        Text(String(format: "%.1f%%", bucket.percentage))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.systemBackground).opacity(0.72))
                            )
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
        }
        .task {
            await loadCommunityStats()
        }
    }

    @ViewBuilder
    private func communityMetricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.black))
                .foregroundStyle(.accentColor)
                .lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.72))
        )
    }

    private func loadCommunityStats() async {
        isLoading = true
        errorMessage = nil
        do {
            stats = try await analyticsService.fetchCommunityStats()
        } catch {
            errorMessage = "Bitte versuche es in ein paar Sekunden erneut."
        }
        isLoading = false
    }
}
