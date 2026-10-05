//
//  StatisticsView.swift
//  VocabularyPool
//
//  Minimalist Statistics View focused strictly on period filtering and 6-mode breakdown grid.
//

import SwiftUI
import SwiftData

enum StatisticsPeriod: String, CaseIterable, Identifiable {
    case week = "Son 1 Hafta"
    case month = "Son 1 Ay"
    case threeMonths = "Son 3 Ay"
    
    var id: String { rawValue }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        }
    }
}

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]

    @State private var selectedPeriod: StatisticsPeriod = .week

    private var filteredSessions: [PracticeSession] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let cutoffDate = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: today) else { return [] }
        return sessions.filter { $0.date >= cutoffDate }
    }

    private var stats: (engToTr: Int, trToEng: Int, listening: Int, audioListening: Int, flashcards: Int, matching: Int, total: Int) {
        let engToTr = filteredSessions.reduce(0) { $0 + $1.englishToTurkishCount }
        let trToEng = filteredSessions.reduce(0) { $0 + $1.turkishToEnglishCount }
        let listening = filteredSessions.reduce(0) { $0 + $1.listeningCount }
        let audioListening = filteredSessions.reduce(0) { $0 + $1.audioListeningCount }
        let flashcards = filteredSessions.reduce(0) { $0 + $1.flashcardsCount }
        let matching = filteredSessions.reduce(0) { $0 + $1.matchingCount }

        let total = engToTr + trToEng + listening + audioListening + flashcards + matching
        return (engToTr, trToEng, listening, audioListening, flashcards, matching, total)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {

                    // MARK: Period Segmented Selector
                    Picker("Zaman Filtresi", selection: $selectedPeriod) {
                        ForEach(StatisticsPeriod.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, DS.Spacing.sm)

                    // MARK: Section Header
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mod Bazlı Çalışma Dağılımı")
                                .font(.dsTitle)
                                .foregroundStyle(.primary)
                            Text("\(selectedPeriod.rawValue) içinde yapılan toplam alıştırmalar")
                                .font(.dsCaption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, DS.Spacing.md)

                    // MARK: 2x3 Mode Breakdown Grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.md), GridItem(.flexible(), spacing: DS.Spacing.md)], spacing: DS.Spacing.md) {
                        ModeStatCard(
                            title: "EN → TR",
                            subtitle: "İngilizce → Türkçe",
                            count: stats.engToTr,
                            icon: "text.book.closed.fill",
                            color: DS.Colors.primary
                        )

                        ModeStatCard(
                            title: "TR → EN",
                            subtitle: "Türkçe → İngilizce",
                            count: stats.trToEng,
                            icon: "globe",
                            color: DS.Colors.accent
                        )

                        ModeStatCard(
                            title: "Yazarak Dinle",
                            subtitle: "Yazmalı Test",
                            count: stats.listening,
                            icon: "headphones",
                            color: DS.Colors.warning
                        )

                        ModeStatCard(
                            title: "Oto Dinle",
                            subtitle: "Sesli Oynatma",
                            count: stats.audioListening,
                            icon: "headphones.circle.fill",
                            color: Color.orange
                        )

                        ModeStatCard(
                            title: "Akıllı Kartlar",
                            subtitle: "Kart Çevirme",
                            count: stats.flashcards,
                            icon: "rectangle.stack.fill",
                            color: DS.Colors.total
                        )

                        ModeStatCard(
                            title: "Eşleştirme",
                            subtitle: "Kelime Çiftleri",
                            count: stats.matching,
                            icon: "rectangle.2.swap",
                            color: DS.Colors.purple
                        )
                    }
                    .padding(.horizontal, DS.Spacing.md)

                    // MARK: Total Summary Card
                    HStack(spacing: DS.Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(DS.Colors.primary.opacity(0.15))
                                .frame(width: 48, height: 48)
                            Image(systemName: "star.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(DS.Colors.primary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Toplam Tamamlanan Alıştırma")
                                .font(.dsCaption)
                                .foregroundStyle(.secondary)
                            Text("\(stats.total) Kelime / Soru")
                                .font(.dsTitle)
                                .foregroundStyle(.primary)
                        }

                        Spacer()
                    }
                    .padding(DS.Spacing.md)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                    .padding(.horizontal, DS.Spacing.md)

                    Spacer(minLength: DS.Spacing.xl)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("İstatistikler")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Mode Stat Card Component

struct ModeStatCard: View {
    let title: String
    let subtitle: String
    let count: Int
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 42, height: 42)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(color)
                }
                Spacer()
            }

            Spacer(minLength: 6)

            Text("\(count)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.dsHeadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: [PracticeSession.self], inMemory: true)
}
