// History View - Visit Records

import SwiftUI

struct HistoryView: View {
    @StateObject private var historyService = HistoryService.shared
    @State private var selectedFilter: Filter = .all
    @State private var showClearAlert = false

    enum Filter: CaseIterable {
        case all
        case today
        case week
        case month

        var titleKey: LocalizedStringKey {
            switch self {
            case .all: return "history.filter.all"
            case .today: return "history.filter.today"
            case .week: return "history.filter.week"
            case .month: return "history.filter.month"
            }
        }
    }

    var filteredRecords: [HistoryService.VisitRecord] {
        let records = historyService.visitRecords

        switch selectedFilter {
        case .all:
            return records
        case .today:
            return records.filter { Calendar.current.isDateInToday($0.visitDate) }
        case .week:
            let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            return records.filter { $0.visitDate >= weekAgo }
        case .month:
            let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
            return records.filter { $0.visitDate >= monthAgo }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Stats header
                statsHeader

                // Filter
                filterBar

                // Records list
                if filteredRecords.isEmpty {
                    emptyState
                } else {
                    recordsList
                }
            }
            .navigationTitle("history.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { showClearAlert = true }) {
                            Label("history.clear", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("history.clear", isPresented: $showClearAlert) {
                Button("common.cancel", role: .cancel) {}
                Button("history.clear.confirm", role: .destructive) {
                    historyService.clearRecords()
                }
            } message: {
                Text("history.clear.message")
            }
        }
    }

    // MARK: - Stats Header
    private var statsHeader: some View {
        HStack(spacing: 20) {
            StatItem(
                value: "\(historyService.totalVisits)",
                labelKey: "history.stat.totalVisits",
                icon: "map.fill"
            )

            StatItem(
                value: "\(historyService.uniquePOIsVisited)",
                labelKey: "settings.stat.places",
                icon: "building.2.fill"
            )

            StatItem(
                value: formatDuration(historyService.totalTimeSpent),
                labelKey: "history.stat.totalTime",
                icon: "clock.fill"
            )

            if let mostVisited = historyService.mostVisitedPOI {
                StatItem(
                    value: mostVisited,
                    labelKey: "history.stat.mostVisited",
                    icon: "heart.fill"
                )
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Filter Bar
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Filter.allCases, id: \.self) { filter in
                    Button(action: { selectedFilter = filter }) {
                        Text(filter.titleKey)
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedFilter == filter ? .blue : .gray.opacity(0.15))
                            .foregroundStyle(selectedFilter == filter ? .white : .primary)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Records List
    private var recordsList: some View {
        List {
            ForEach(filteredRecords) { record in
                RecordRow(record: record)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "map")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("history.empty.title")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("history.empty.subtitle")
                .font(.subheadline)
                .foregroundStyle(.tertiary)

            Spacer()
        }
    }

    // MARK: - Helpers
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return L10n.format("common.hoursMinutes.short", hours, minutes)
        }
        return L10n.format("common.minutes.short", minutes)
    }
}

// MARK: - Record Row
struct RecordRow: View {
    let record: HistoryService.VisitRecord

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.blue.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: "building.2.fill")
                    .foregroundStyle(.blue)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(record.poiName)
                    .font(.headline)

                HStack(spacing: 8) {
                    Label(record.style, systemImage: "speaker.wave.2")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Label(record.formattedDuration, systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let sourceName = record.sourceName, !sourceName.isEmpty {
                    Label(sourceName, systemImage: "shield.checkered")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let summary = record.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Date
            VStack(alignment: .trailing, spacing: 4) {
                Text(record.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview
#Preview {
    HistoryView()
}
