// Journey Narrative View

import SwiftUI

struct JourneyNarrativeView: View {
    @StateObject private var service = JourneyNarrativeService()
    @State private var showNewJourney = false
    @State private var journeyName = ""
    @State private var journeyDescription = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if service.isRecording {
                    activeJourneyView
                } else {
                    journeyListView
                }
            }
            .navigationTitle(L10n.string("trip.nav.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.string("common.close")) { dismiss() }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    if !service.isRecording {
                        Button(L10n.string("开始旅程")) {
                            showNewJourney = true
                        }
                    }
                }
            }
            .sheet(isPresented: $showNewJourney) {
                newJourneySheet
            }
        }
    }
    
    // MARK: - Active Journey View
    private var activeJourneyView: some View {
        VStack(spacing: 0) {
            if let journey = service.currentJourney {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(journey.name)
                                .font(.headline)
                            Text(journey.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(journey.formattedDuration)
                            .font(.subheadline)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
                    HStack(spacing: 20) {
                        StatBadge(value: "\(service.chapters.count)", label: L10n.string("journey.stat.places"), icon: "mappin.circle")
                        StatBadge(value: "\(journey.photos.count)", label: L10n.string("journey.stat.photos"), icon: "photo")
                        StatBadge(value: "\(journey.notes.count)", label: L10n.string("journey.stat.notes"), icon: "note.text")
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(service.chapters) { chapter in
                        ChapterCard(chapter: chapter)
                    }
                }
                .padding()
            }
            
            HStack(spacing: 12) {
                Button(action: {
                    service.addNote(content: L10n.string("journey.note.default"))
                }) {
                    Label(L10n.string("添加笔记"), systemImage: "note.text.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Button(action: {
                    service.endJourney()
                }) {
                    Label(L10n.string("结束旅程"), systemImage: "stop.circle")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.red)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
    }
    
    // MARK: - Journey List View
    private var journeyListView: some View {
        VStack {
            if let stats = service.journeyStats {
                statsSection(stats)
            }
            
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "book.closed")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                
                VStack(spacing: 8) {
                    Text(L10n.string("开始您的旅程"))
                        .font(.headline)
                    
                    Text(L10n.string("记录游览的每个精彩瞬间\n形成完整的游览故事"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Button(action: { showNewJourney = true }) {
                    Label(L10n.string("开始新旅程"), systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Stats Section
    private func statsSection(_ stats: JourneyNarrativeService.JourneyStats) -> some View {
        VStack(spacing: 16) {
            Text(L10n.string("游览统计"))
                .font(.headline)
            
            HStack(spacing: 20) {
                StatCard(value: "\(stats.totalJourneys)", label: L10n.string("journey.stat.journeys"), icon: "map")
                StatCard(value: "\(stats.totalChapters)", label: L10n.string("journey.stat.chapters"), icon: "book")
                StatCard(value: "\(stats.totalPhotos)", label: L10n.string("journey.stat.photos"), icon: "photo")
                StatCard(value: stats.formattedDuration, label: L10n.string("journey.stat.totalDuration"), icon: "clock")
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }
    
    // MARK: - New Journey Sheet
    private var newJourneySheet: some View {
        NavigationStack {
            Form {
                Section(L10n.string("旅程信息")) {
                    TextField(L10n.string("旅程名称"), text: $journeyName)
                    TextField(L10n.string("旅程描述"), text: $journeyDescription)
                }
                
                Section {
                    Button(L10n.string("开始旅程")) {
                        service.startJourney(
                            name: journeyName.isEmpty ? L10n.string("journey.default.name") : journeyName,
                            description: journeyDescription.isEmpty ? L10n.string("journey.default.description") : journeyDescription
                        )
                        showNewJourney = false
                    }
                    .disabled(journeyName.isEmpty)
                }
            }
            .navigationTitle(L10n.string("新建旅程"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.string("common.cancel")) { showNewJourney = false }
                }
            }
        }
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            
            Text(value)
                .font(.headline)
            
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.gray.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Chapter Card
struct ChapterCard: View {
    let chapter: JourneyNarrativeService.Chapter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(chapter.title)
                        .font(.headline)
                    
                    Text(chapter.formattedTime)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "building.2.fill")
                    .foregroundStyle(.blue)
            }
            
            Text(chapter.content)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(3)
            
            if !chapter.highlights.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(chapter.highlights, id: \.self) { highlight in
                            Text(highlight)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

#Preview {
    JourneyNarrativeView()
}
