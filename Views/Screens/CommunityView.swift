import Combine
import SwiftUI

@MainActor
final class CommunityViewModel: ObservableObject {
    typealias CommunityStatsFetcher = @Sendable (String) async throws -> CommunityStats?
    private static let retryMessage = String(localized: "Bitte versuche es in ein paar Sekunden erneut.")

    @Published private(set) var stats: CommunityStats?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?

    private let fetchCommunityStats: CommunityStatsFetcher
    private var requestGeneration = 0

    init(fetchCommunityStats: @escaping CommunityStatsFetcher) {
        self.fetchCommunityStats = fetchCommunityStats
    }

    func load(seasonID: String) async {
        requestGeneration += 1
        let generation = requestGeneration
        isLoading = true
        stats = nil
        errorMessage = nil
        defer {
            if generation == requestGeneration {
                isLoading = false
            }
        }

        do {
            let fetchedStats = try await fetchCommunityStats(seasonID)
            guard generation == requestGeneration, !Task.isCancelled else {
                return
            }
            stats = fetchedStats
            if fetchedStats == nil {
                errorMessage = Self.retryMessage
            }
        } catch is CancellationError {
            return
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else {
                return
            }
            errorMessage = Self.retryMessage
        }
    }
}

struct CommunityView: View {
    private static let previewSeasonID = "bergschein-2026"

    @Environment(\.dismiss) private var dismiss
    let appBackgroundGradient: LinearGradient
    let analyticsService: AnalyticsService
    let ownCheckins: Int
    let seasonID: String

    @StateObject private var model: CommunityViewModel
    @State private var use2026ComparisonPreview = false

    init(
        appBackgroundGradient: LinearGradient,
        analyticsService: AnalyticsService,
        ownCheckins: Int,
        seasonID: String
    ) {
        self.appBackgroundGradient = appBackgroundGradient
        self.analyticsService = analyticsService
        self.ownCheckins = ownCheckins
        self.seasonID = seasonID
        _model = StateObject(wrappedValue: CommunityViewModel { seasonID in
            try await analyticsService.fetchCommunityStats(seasonID: seasonID)
        })
    }

    private var isTestSeason: Bool {
        seasonID.hasPrefix("test-")
    }

    private var comparisonSeasonID: String {
        isTestSeason && use2026ComparisonPreview ? Self.previewSeasonID : seasonID
    }

    private var isShowing2026Preview: Bool {
        isTestSeason && use2026ComparisonPreview
    }

    var body: some View {
        NavigationStack {
            ZStack {
                appBackgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if isTestSeason {
                            comparisonPreviewControl
                        }

                        if isShowing2026Preview {
                            previewExplanation
                        }

                        communityContent
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
        .task(id: comparisonSeasonID) {
            await model.load(seasonID: comparisonSeasonID)
        }
    }

    private var comparisonPreviewControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Vergleich mit 2026-Daten", isOn: $use2026ComparisonPreview)
                .font(.subheadline.weight(.semibold))
                .accessibilityHint("Zeigt deine Teststempel neben der Community-Verteilung von 2026.")

            Text("Nur Vorschau: Deine Teststempel werden dabei nicht als Platzierung in der Saison 2026 gewertet.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
    }

    private var previewExplanation: some View {
        Text("Vorschau mit der echten Community-Verteilung von 2026. Die Markierung „Du“ zeigt nur, wo dein aktueller Teststand in dieser Verteilung läge.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .accessibilityLabel("Vorschau mit den Community-Daten von 2026. Dein aktueller Teststand wird nur zur Einordnung angezeigt.")
    }

    @ViewBuilder
    private var communityContent: some View {
        if model.isLoading {
            HStack(spacing: 10) {
                ProgressView()
                Text("Community-Daten werden geladen ...")
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        } else if let errorMessage = model.errorMessage {
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
                        await model.load(seasonID: comparisonSeasonID)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        } else if let stats = model.stats {
            statsContent(stats)
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
            .background(cardBackground)
        }
    }

    @ViewBuilder
    private func statsContent(_ stats: CommunityStats) -> some View {
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
            .background(cardBackground)
        } else {
            VStack(alignment: .leading, spacing: 14) {
                Text("So schlägst du dich im Vergleich")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.55))
                    )

                ForEach(Array(rankedDistribution.enumerated()), id: \.element.id) { index, bucket in
                    distributionRow(
                        bucket: bucket,
                        rank: index + 1,
                        maxPercentage: maxPercentage,
                        isOwnBucket: bucket.checkins == ownCheckins
                    )
                }

                Text("Die Prozentwerte zeigen, wie viel Prozent der App-Nutzer wie oft auf dem Berg waren.")
                    .font(.footnote)
                    .foregroundStyle(.secondary.opacity(0.75))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
    }

    private func distributionRow(
        bucket: CommunityDistributionEntry,
        rank: Int,
        maxPercentage: Double,
        isOwnBucket: Bool
    ) -> some View {
        let rankColor: Color = switch rank {
        case 1: Color(red: 0.78, green: 0.63, blue: 0.20)
        case 2: Color(red: 0.58, green: 0.62, blue: 0.66)
        case 3: Color(red: 0.66, green: 0.44, blue: 0.30)
        default: .accentColor
        }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("#\(rank)")
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
                        .background(Capsule(style: .continuous).fill(Color.accentColor))
                }

                Spacer()

                Text(String(format: "%.1f%%", bucket.percentage))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule(style: .continuous).fill(Color(.systemBackground).opacity(0.9)))
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Platz \(rank), \(bucket.checkins) mal eingecheckt, \(String(format: "%.1f", bucket.percentage)) Prozent\(isOwnBucket ? ", dein Stand" : "")")
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.systemBackground).opacity(0.72))
    }

}
