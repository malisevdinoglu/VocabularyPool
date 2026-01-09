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
    
    var total: Int {
        englishToTurkish + turkishToEnglish + listening
    }
}

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]
    
    @State private var selectedPeriod: StatisticsPeriod = .week
    
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
            
            // Only add if there is data
            if engToTr + trToEng + listening > 0 {
                dailyStats.append(DailyStatistic(
                    date: date,
                    englishToTurkish: engToTr,
                    turkishToEnglish: trToEng,
                    listening: listening
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
            ZStack {
                Color.black.ignoresSafeArea() // Dark background
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Period Selector
                        Picker("Period", selection: $selectedPeriod) {
                            ForEach(StatisticsPeriod.allCases, id: \.self) { period in
                                Text(period.rawValue).tag(period)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .colorScheme(.dark) // Force dark appearance for picker
                        
                        // Summary Cards ScrollView
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                SummaryCard(
                                    title: "English → Turkish",
                                    count: totalStatistics.engToTr,
                                    icon: "text.book.closed.fill",
                                    gradient: LinearGradient(colors: [.blue, .blue.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                
                                SummaryCard(
                                    title: "Turkish → English",
                                    count: totalStatistics.trToEng,
                                    icon: "globe",
                                    gradient: LinearGradient(colors: [.green, .green.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                
                                SummaryCard(
                                    title: "Listening",
                                    count: totalStatistics.listening,
                                    icon: "headphones",
                                    gradient: LinearGradient(colors: [.orange, .orange.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                
                                SummaryCard(
                                    title: "Total Words",
                                    count: totalStatistics.total,
                                    icon: "star.fill",
                                    gradient: LinearGradient(colors: [.purple, .purple.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                            }
                            .padding(.horizontal)
                        }
                        
                        // History Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("History")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal)
                            
                            if filteredStatistics.isEmpty {
                                ContentUnavailableView("No activity in this period", systemImage: "chart.bar")
                                    .foregroundStyle(.gray)
                            } else {
                                ForEach(filteredStatistics) { stat in
                                    DailyCard(statistic: stat)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
    
    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Text(dayLabel)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("\(statistic.total) exercises")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            
            Divider().background(Color.gray.opacity(0.3))
            
            // Stats Row
            HStack(spacing: 20) {
                if statistic.englishToTurkish > 0 {
                    StatBadge(count: statistic.englishToTurkish, color: .blue, icon: "text.book.closed.fill", label: "E→T")
                }
                
                if statistic.turkishToEnglish > 0 {
                   StatBadge(count: statistic.turkishToEnglish, color: .green, icon: "globe", label: "T→E")
                }
                
                if statistic.listening > 0 {
                    StatBadge(count: statistic.listening, color: .orange, icon: "headphones", label: "Listen")
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(uiColor: .systemGray6).opacity(0.15)) // Subtle dark gray
        .cornerRadius(16)
        .padding(.horizontal)
    }
}

struct StatBadge: View {
    let count: Int
    let color: Color
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color, lineWidth: 3)
                    .frame(width: 50, height: 50)
                
                VStack(spacing: 2) {
                    Image(systemName: icon)
                        .font(.caption2)
                        .foregroundStyle(color)
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                }
            }
            
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.gray)
        }
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: [PracticeSession.self], inMemory: true)
}
