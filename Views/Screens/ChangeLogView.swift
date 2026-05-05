//
//  ChangeLogView.swift
//  Bergschein
//

import SwiftUI

struct ChangeLogView: View {
    let backgroundGradient: LinearGradient

    private let entries = [
        ChangeLogEntry(version: "2026.2", date: "05.05.2026", sections: [
            ChangeLogSection(title: "Neu", color: .green, items: [
                "Community Highscore hinzugefügt"
            ])
        ]),
        ChangeLogEntry(version: "2026.1.1", date: "04.05.2026", sections: [
            ChangeLogSection(title: "Verbessert", color: .blue, items: [
                "Finalisierung für die Bergkirchweih 2026"
            ])
        ]),
        ChangeLogEntry(version: "2026.1", date: "14.04.2026", sections: [
            ChangeLogSection(title: "Neu", color: .green, items: [
                "Challenges verbessert",
                "Verlosung hinzugefügt"
            ])
        ]),
        ChangeLogEntry(version: "2026.0", date: "20.03.2026", sections: [
            ChangeLogSection(title: "Neu", color: .green, items: [
                "Erstes Release!"
            ])
        ])
    ]

    var body: some View {
        ZStack {
            backgroundGradient
                .ignoresSafeArea()

            List {
                ForEach(entries) { entry in
                    Section {
                        ChangeLogEntryRow(entry: entry)
                            .padding(.vertical, 12)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Changelog")
    }
}

private struct ChangeLogEntry: Identifiable {
    let version: String
    let date: String
    let sections: [ChangeLogSection]

    var id: String { version }
}

private struct ChangeLogSection: Identifiable {
    let title: String
    let color: Color
    let items: [String]

    var id: String {
        "\(title)-\(items.joined(separator: "|"))"
    }
}

private struct ChangeLogEntryRow: View {
    let entry: ChangeLogEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(.accent)
                    .frame(width: 5, height: 40)

                Text(entry.version)
                    .font(.title.weight(.bold))

                Spacer()

                HStack(spacing: 4) {
                    Text(entry.date)
                    Image(systemName: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ForEach(entry.sections) { section in
                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(.headline)
                            .foregroundStyle(section.color)

                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(section.color)
                            .frame(width: 20, height: 3)
                    }

                    ForEach(section.items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .resizable()
                                .frame(width: 5, height: 5)
                                .foregroundStyle(.primary)
                                .padding(.top, 6)

                            Text(item)
                                .fixedSize(horizontal: false, vertical: true)

                            Spacer()
                        }
                    }
                }
            }
        }
    }
}
