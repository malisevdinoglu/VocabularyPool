//
//  StatisticsView.swift
//  VocabularyPool
//
//  Created by Assistant on 05.01.2026.
//

import SwiftUI
import SwiftData

enum StatisticsPeriod: String, CaseIterable {
    case week = "Son 1 Hafta"
    case month = "Son 1 Ay"
    case threeMonths = "Son 3 Ay"
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        }
    }
}

struct DailyStatistic: Identifiable {
    let id = UUID()
    let date: Date
    let englishToTurkish: Int
    let turkishToEnglish: Int
    let listening: Int
    
    // Goal snapshot - o günün hedefleri
    let goalEngToTr: Int
    let goalTrToEng: Int
    let goalListening: Int
    
    var total: Int {
        englishToTurkish + turkishToEnglish + listening
    }
}

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]
    
    @State private var selectedPeriod: StatisticsPeriod = .week
    @State private var showingGoalsSheet = false
    @ObservedObject var goals = PracticeGoals.shared
    
    var filteredStatistics: [DailyStatistic] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Generate array of dates for the selected period
        var dailyStats: [DailyStatistic] = []
        
        for dayOffset in 0..<selectedPeriod.days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            
            // Find all sessions for this day
            let daySessions = sessions.filter { session in
                calendar.isDate(session.date, inSameDayAs: date)
            }
            
            // Sum up the counts
            let engToTr = daySessions.reduce(0) { $0 + $1.englishToTurkishCount }
            let trToEng = daySessions.reduce(0) { $0 + $1.turkishToEnglishCount }
            let listening = daySessions.reduce(0) { $0 + $1.listeningCount }
            
            // Get goal snapshot from first session (all sessions on same day have same goals)
            let goalEngToTr = daySessions.first?.dailyGoalEngToTr ?? 0
            let goalTrToEng = daySessions.first?.dailyGoalTrToEng ?? 0
            let goalListening = daySessions.first?.dailyGoalListening ?? 0
            
            // Only add if there is data
            if engToTr + trToEng + listening > 0 {
                dailyStats.append(DailyStatistic(
                    date: date,
                    englishToTurkish: engToTr,
                    turkishToEnglish: trToEng,
                    listening: listening,
                    goalEngToTr: goalEngToTr,
                    goalTrToEng: goalTrToEng,
                    goalListening: goalListening
                ))
            }
        }
        
        return dailyStats
    }
    
    var totalStatistics: (engToTr: Int, trToEng: Int, listening: Int, total: Int) {
        // Calculate totals based on filtered statistics
        // Note: Logic allows filteredStatistics to only include days with data, 
        // but for accurate totals over period we might want to iterate all sessions if not using the filtered array
        // For simplicity, let's sum from the filtered array (which acts as a daily log)
        
        // Actually, to be precise, let's recalculate based on sessions in date range
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let cutoffDate = calendar.date(byAdding: .day, value: -selectedPeriod.days, to: today)!
        
        let validSessions = sessions.filter { $0.date >= cutoffDate }
        
        let engToTr = validSessions.reduce(0) { $0 + $1.englishToTurkishCount }
        let trToEng = validSessions.reduce(0) { $0 + $1.turkishToEnglishCount }
        let listening = validSessions.reduce(0) { $0 + $1.listeningCount }
        
        return (engToTr, trToEng, listening, engToTr + trToEng + listening)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    // Period Selector
                    Picker("Period", selection: $selectedPeriod) {
                        ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, DS.Spacing.md)

                    // Summary Cards
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.md) {
                            SummaryCard(
                                title: "EN → TR",
                                count: totalStatistics.engToTr,
                                icon: "text.book.closed.fill",
                                gradient: LinearGradient(
                                    colors: [DS.Colors.primary, DS.Colors.primary.opacity(0.7)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            SummaryCard(
                                title: "TR → EN",
                                count: totalStatistics.trToEng,
                                icon: "globe",
                                gradient: LinearGradient(
                                    colors: [DS.Colors.accent, DS.Colors.accent.opacity(0.7)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            SummaryCard(
                                title: "Listening",
                                count: totalStatistics.listening,
                                icon: "headphones",
                                gradient: LinearGradient(
                                    colors: [DS.Colors.warning, DS.Colors.warning.opacity(0.7)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            SummaryCard(
                                title: "Total",
                                count: totalStatistics.total,
                                icon: "star.fill",
                                gradient: LinearGradient(
                                    colors: [DS.Colors.purple, DS.Colors.purple.opacity(0.7)],
                                    startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        }
                        .padding(.horizontal, DS.Spacing.md)
                    }

                    // History Section
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text("History")
                            .font(.dsTitle)
                            .padding(.horizontal, DS.Spacing.md)

                        if filteredStatistics.isEmpty {
                            ContentUnavailableView("No activity in this period", systemImage: "chart.bar")
                        } else {
                            ForEach(filteredStatistics) { stat in
                                DailyCard(
                                    statistic: stat,
                                    goalStatus: checkGoalCompletionWithSnapshot(stat: stat)
                                )
                            }
                        }
                    }
                    .padding(.bottom, DS.Spacing.lg)
                }
                .padding(.top, DS.Spacing.md)
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingGoalsSheet = true
                    } label: {
                        Image(systemName: "target")
                    }
                }
            }
            .sheet(isPresented: $showingGoalsSheet) {
                GoalsSettingsView()
            }
        }
    }
    
    // Helper function to check goal completion using snapshot data
    private func checkGoalCompletionWithSnapshot(stat: DailyStatistic) -> GoalStatus {
        // Eğer o gün için hedef snapshot'ı yoksa (eski veri), hedef kontrolü yapma
        guard stat.goalEngToTr > 0 || stat.goalTrToEng > 0 || stat.goalListening > 0 else {
            return .noGoals
        }
        
        var completedCount = 0
        var totalGoals = 0
        
        if stat.goalEngToTr > 0 {
            totalGoals += 1
            if stat.englishToTurkish >= stat.goalEngToTr { completedCount += 1 }
        }
        
        if stat.goalTrToEng > 0 {
            totalGoals += 1
            if stat.turkishToEnglish >= stat.goalTrToEng { completedCount += 1 }
        }
        
        if stat.goalListening > 0 {
            totalGoals += 1
            if stat.listening >= stat.goalListening { completedCount += 1 }
        }
        
        if completedCount == totalGoals {
            return .allCompleted
        } else if completedCount > 0 {
            return .partial(completed: completedCount, total: totalGoals)
        } else {
            return .none
        }
    }
}

struct SummaryCard: View {
    let title: String
    let count: Int
    let icon: String
    let gradient: LinearGradient
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
            }
            
            Spacer()
            
            Text("\(count)")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.white)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
        }
        .padding()
        .frame(width: 160, height: 140)
        .background(gradient)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
    }
}

struct DailyCard: View {
    let statistic: DailyStatistic
    let goalStatus: GoalStatus
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM" // e.g. "5 October"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter
    }
    
    private var dayLabel: String {
        if Calendar.current.isDateInToday(statistic.date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(statistic.date) {
            return "Yesterday"
        } else {
            return dateFormatter.string(from: statistic.date)
        }
    }
    
    private var goalCompletionText: String {
        switch goalStatus {
        case .allCompleted:
            if case .partial(let completed, let total) = goalStatus {
                return "\(completed)/\(total)"
            }
            // Count completed goals
            var completed = 0
            var total = 0
            if statistic.goalEngToTr > 0 {
                total += 1
                if statistic.englishToTurkish >= statistic.goalEngToTr { completed += 1 }
            }
            if statistic.goalTrToEng > 0 {
                total += 1
                if statistic.turkishToEnglish >= statistic.goalTrToEng { completed += 1 }
            }
            if statistic.goalListening > 0 {
                total += 1
                if statistic.listening >= statistic.goalListening { completed += 1 }
            }
            return "\(completed)/\(total)"
        case .partial(let completed, let total):
            return "\(completed)/\(total)"
        case .none:
            var total = 0
            if statistic.goalEngToTr > 0 { total += 1 }
            if statistic.goalTrToEng > 0 { total += 1 }
            if statistic.goalListening > 0 { total += 1 }
            return "0/\(total)"
        case .noGoals:
            return ""
        }
    }
    
    private var goalCompletionColor: Color {
        switch goalStatus {
        case .allCompleted:
            return .green
        case .partial:
            return .orange
        case .none:
            return .red
        case .noGoals:
            return .gray
        }
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack {
                Text(dayLabel)
                    .font(.dsHeadline)

                Spacer()

                if case .noGoals = goalStatus {
                    Text("\(statistic.total) exercises")
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(goalCompletionText)
                        .font(.dsCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(goalCompletionColor)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(goalCompletionColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            Divider()

            HStack(spacing: DS.Spacing.lg) {
                if statistic.englishToTurkish > 0 {
                    StatBadge(count: statistic.englishToTurkish, color: DS.Colors.engToTr, icon: "text.book.closed.fill", label: "E→T")
                }
                if statistic.turkishToEnglish > 0 {
                    StatBadge(count: statistic.turkishToEnglish, color: DS.Colors.trToEng, icon: "globe", label: "T→E")
                }
                if statistic.listening > 0 {
                    StatBadge(count: statistic.listening, color: DS.Colors.listening, icon: "headphones", label: "Listen")
                }
                Spacer()
            }
        }
        .padding(DS.Spacing.md)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        .padding(.horizontal, DS.Spacing.md)
    }
}

struct StatBadge: View {
    let count: Int
    let color: Color
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 50, height: 50)

                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundStyle(color)
                    Text("\(count)")
                        .font(.dsCaption)
                        .fontWeight(.bold)
                        .foregroundStyle(color)
                }
            }

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}

struct WeeklySummaryCard: View {
    let weekStart: Date
    let sessions: [PracticeSession]
    let goals: PracticeGoals
    
    var weekTotal: (engToTr: Int, trToEng: Int, listening: Int, daysWithActivity: Int) {
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)!
        
        let weekSessions = sessions.filter {
            $0.date >= weekStart && $0.date < weekEnd
        }
        
        // Count unique days with activity
        let uniqueDays = Set(weekSessions.map { calendar.startOfDay(for: $0.date) })
        
        return (
            weekSessions.reduce(0) { $0 + $1.englishToTurkishCount },
            weekSessions.reduce(0) { $0 + $1.turkishToEnglishCount },
            weekSessions.reduce(0) { $0 + $1.listeningCount },
            uniqueDays.count
        )
    }
    
    var weekRangeText: String {
        let calendar = Calendar.current
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart)!
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "tr_TR")
        
        return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Bu Hafta")
                        .font(.dsTitle)
                    Text(weekRangeText)
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 2) {
                    Text("\(weekTotal.daysWithActivity)")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("gün")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.Spacing.sm + DS.Spacing.xs)
                .padding(.vertical, DS.Spacing.sm)
                .background(DS.Colors.primary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }

            Divider()

            VStack(spacing: DS.Spacing.sm) {
                if goals.englishToTurkishGoal > 0 {
                    WeeklyGoalProgress(title: "English → Turkish", current: weekTotal.engToTr, dailyGoal: goals.englishToTurkishGoal, color: DS.Colors.engToTr)
                }
                if goals.turkishToEnglishGoal > 0 {
                    WeeklyGoalProgress(title: "Turkish → English", current: weekTotal.trToEng, dailyGoal: goals.turkishToEnglishGoal, color: DS.Colors.trToEng)
                }
                if goals.listeningGoal > 0 {
                    WeeklyGoalProgress(title: "Listening", current: weekTotal.listening, dailyGoal: goals.listeningGoal, color: DS.Colors.listening)
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }
}

struct WeeklyGoalProgress: View {
    let title: String
    let current: Int
    let dailyGoal: Int
    let color: Color
    
    var weeklyTarget: Int {
        dailyGoal * 7
    }
    
    var progress: Double {
        guard weeklyTarget > 0 else { return 0 }
        return min(Double(current) / Double(weeklyTarget), 1.0)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
            HStack {
                Text(title)
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(current) / \(weeklyTarget)")
                    .font(.dsCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(current >= weeklyTarget ? DS.Colors.success : .primary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 10)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(color)
                        .frame(width: geometry.size.width * progress, height: 10)
                        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
                }
            }
            .frame(height: 10)
        }
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: [PracticeSession.self], inMemory: true)
}
