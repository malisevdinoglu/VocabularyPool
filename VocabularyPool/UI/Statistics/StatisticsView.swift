//
//  StatisticsView.swift
//  VocabularyPool
//
//  Created by Assistant on 14.11.2026.
//

import SwiftUI
import SwiftData

struct PracticeStatItem: Identifiable {
    let id: String
    let title: String
    let count: Int
    let icon: String
    let color: Color
    let unit: String
}

struct StatisticsView: View {
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]
    @State private var selectedDate: Date = Date()
    @State private var showingDatePicker = false

    private let calendar = Calendar.current

    // MARK: - Computed Properties

    private var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    private var currentSession: PracticeSession? {
        let startOfDay = calendar.startOfDay(for: selectedDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }
        return sessions.first { session in
            session.date >= startOfDay && session.date < endOfDay
        }
    }

    private var allStatItems: [PracticeStatItem] {
        guard let session = currentSession else { return [] }
        return [
            PracticeStatItem(
                id: "en_tr",
                title: "İngilizce → Türkçe",
                count: session.englishToTurkishCount,
                icon: "text.book.closed.fill",
                color: DS.Colors.primary,
                unit: "soru"
            ),
            PracticeStatItem(
                id: "tr_en",
                title: "Türkçe → İngilizce",
                count: session.turkishToEnglishCount,
                icon: "globe",
                color: DS.Colors.accent,
                unit: "soru"
            ),
            PracticeStatItem(
                id: "listening",
                title: "Yazarak Dinle",
                count: session.listeningCount,
                icon: "headphones",
                color: DS.Colors.warning,
                unit: "soru"
            ),
            PracticeStatItem(
                id: "audio_listening",
                title: "Otomatik Sesli Dinleme",
                count: session.audioListeningCount,
                icon: "headphones.circle.fill",
                color: Color.orange,
                unit: "kelime"
            ),
            PracticeStatItem(
                id: "flashcards",
                title: "Kartlar",
                count: session.flashcardsCount,
                icon: "rectangle.stack.fill",
                color: DS.Colors.total,
                unit: "kart"
            ),
            PracticeStatItem(
                id: "matching",
                title: "Eşleştirme",
                count: session.matchingCount,
                icon: "rectangle.2.swap",
                color: DS.Colors.purple,
                unit: "kelime"
            ),
            PracticeStatItem(
                id: "verbs",
                title: "Fiil Çekimleri",
                count: session.verbConjugationsCount,
                icon: "repeat.circle.fill",
                color: DS.Colors.purple,
                unit: "alıştırma"
            ),
            PracticeStatItem(
                id: "phrasal",
                title: "Phrasal Verbs",
                count: session.phrasalVerbsCount,
                icon: "books.vertical.fill",
                color: Color(red: 0.545, green: 0.361, blue: 0.965),
                unit: "soru"
            )
        ]
    }

    /// Sadece yapılan alıştırmalar (> 0)
    private var activeStatItems: [PracticeStatItem] {
        allStatItems.filter { $0.count > 0 }
    }

    private var totalPracticeCount: Int {
        activeStatItems.reduce(0) { $0 + $1.count }
    }

    private var formattedDateString: String {
        if calendar.isDateInToday(selectedDate) {
            let dayMonth = selectedDate.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "tr_TR")))
            return "Bugün, \(dayMonth)"
        } else if calendar.isDateInYesterday(selectedDate) {
            let dayMonth = selectedDate.formatted(.dateTime.day().month(.wide).locale(Locale(identifier: "tr_TR")))
            return "Dün, \(dayMonth)"
        } else {
            return selectedDate.formatted(
                .dateTime
                    .day()
                    .month(.wide)
                    .year()
                    .weekday(.wide)
                    .locale(Locale(identifier: "tr_TR"))
            )
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.md) {
                    // Tarih Gezgini
                    dateNavigatorBar

                    if activeStatItems.isEmpty {
                        emptyStateView
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    } else {
                        // Toplam Kartı
                        totalSummaryCard

                        // Yapılan Alıştırmalar Listesi
                        activeExercisesCard
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .animation(.easeInOut(duration: 0.25), value: selectedDate)
                .animation(.easeInOut(duration: 0.25), value: activeStatItems.isEmpty)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("İstatistikler")
            .toolbar {
                if !isToday {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation {
                                selectedDate = Date()
                            }
                        } label: {
                            Text("Bugün")
                                .font(.dsCallout)
                                .fontWeight(.semibold)
                                .foregroundStyle(DS.Colors.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                datePickerSheet
            }
        }
    }

    // MARK: - Date Navigator Bar

    private var dateNavigatorBar: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button {
                changeDate(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Colors.primary)
                    .frame(width: 38, height: 38)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }

            Spacer()

            Button {
                showingDatePicker = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(DS.Colors.primary)

                    Text(formattedDateString)
                        .font(.dsHeadline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .clipShape(Capsule())
            }

            Spacer()

            Button {
                changeDate(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isToday ? .secondary.opacity(0.3) : DS.Colors.primary)
                    .frame(width: 38, height: 38)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(Circle())
            }
            .disabled(isToday)
        }
        .padding(.vertical, DS.Spacing.xs)
    }

    // MARK: - Total Summary Card

    private var totalSummaryCard: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DS.Colors.primary.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: "flame.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(DS.Colors.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Toplam Alıştırma")
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(totalPracticeCount)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    Text("soru / alıştırma")
                        .font(.dsCallout)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(DS.Spacing.md)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    // MARK: - Active Exercises Card

    private var activeExercisesCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Yapılan Alıştırmalar")
                .font(.dsCallout)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.sm)

            VStack(spacing: 0) {
                ForEach(Array(activeStatItems.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider()
                            .padding(.leading, 58)
                    }

                    HStack(spacing: DS.Spacing.md) {
                        DSIconBadge(systemImage: item.icon, color: item.color)

                        Text(item.title)
                            .font(.dsHeadline)
                            .foregroundStyle(.primary)

                        Spacer()

                        HStack(spacing: 4) {
                            Text("\(item.count)")
                                .font(.dsHeadline)
                                .fontWeight(.bold)
                                .foregroundStyle(item.color)

                            Text(item.unit)
                                .font(.dsCaption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, 12)
                }
            }
            .padding(.bottom, DS.Spacing.xs)
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: DS.Spacing.md) {
            Spacer(minLength: 40)

            ZStack {
                Circle()
                    .fill(Color(uiColor: .tertiarySystemGroupedBackground))
                    .frame(width: 88, height: 88)

                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }

            Text("Bu Tarihte Pratik Yapılmadı")
                .font(.dsTitle)
                .foregroundStyle(.primary)

            Text("Seçilen güne ait herhangi bir alıştırma veya çalışma kaydı bulunmuyor.")
                .font(.dsBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.xl)

            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xl)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }

    // MARK: - Date Picker Sheet

    private var datePickerSheet: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.md) {
                DatePicker(
                    "Tarih Seçin",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(DS.Colors.primary)
                .padding()

                Spacer()
            }
            .navigationTitle("Tarih Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Tamam") {
                        showingDatePicker = false
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.primary)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helpers

    private func changeDate(by days: Int) {
        if let newDate = calendar.date(byAdding: .day, value: days, to: selectedDate) {
            // Geleceğe gitmeyi engelle
            if days > 0 && calendar.startOfDay(for: newDate) > calendar.startOfDay(for: Date()) {
                return
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedDate = newDate
            }
        }
    }
}

#Preview {
    StatisticsView()
}
