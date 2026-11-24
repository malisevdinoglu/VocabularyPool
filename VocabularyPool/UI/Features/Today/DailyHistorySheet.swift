//
//  DailyHistorySheet.swift
//  VocabularyPool
//
//  Daily practice count breakdown with date navigator, presented as a sheet from TodayView.
//

import SwiftUI

struct DailyStatItem: Identifiable {
    let id: String
    let title: String
    let count: Int
    let icon: String
    let color: Color
    let unit: String
}

struct DailyHistorySheet: View {
    let sessions: [PracticeSession]
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date = Date()
    @State private var showingDatePicker = false

    private let calendar = Calendar.current

    private var isToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    private var currentSession: PracticeSession? {
        let startOfDay = calendar.startOfDay(for: selectedDate)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return nil }
        return sessions.first { $0.date >= startOfDay && $0.date < endOfDay }
    }

    private var activeStatItems: [DailyStatItem] {
        guard let s = currentSession else { return [] }
        let items: [DailyStatItem] = [
            DailyStatItem(id: "smart_mix", title: "Daily Smart Mix", count: s.smartMixCount, icon: "sparkles", color: DS.Colors.primary, unit: "items"),
            DailyStatItem(id: "mc", title: "Multiple Choice", count: s.multipleChoiceCount, icon: "checklist", color: DS.Colors.accent, unit: "questions"),
            DailyStatItem(id: "en_tr", title: "Typing (EN → TR)", count: s.englishToTurkishCount, icon: "keyboard", color: DS.Colors.primary, unit: "questions"),
            DailyStatItem(id: "tr_en", title: "Typing (TR → EN)", count: s.turkishToEnglishCount, icon: "globe", color: DS.Colors.accent, unit: "questions"),
            DailyStatItem(id: "listening", title: "Listening (Type)", count: s.listeningCount, icon: "headphones", color: DS.Colors.warning, unit: "questions"),
            DailyStatItem(id: "audio", title: "Auto Audio Play", count: s.audioListeningCount, icon: "waveform", color: DS.Colors.warning, unit: "words"),
            DailyStatItem(id: "flashcards", title: "Flashcards", count: s.flashcardsCount, icon: "rectangle.stack.fill", color: DS.Colors.purple, unit: "cards"),
            DailyStatItem(id: "matching", title: "Matching", count: s.matchingCount, icon: "rectangle.2.swap", color: DS.Colors.purple, unit: "pairs"),
            DailyStatItem(id: "verbs", title: "Irregular Verbs", count: s.verbConjugationsCount, icon: "repeat", color: DS.Colors.purple, unit: "verbs"),
            DailyStatItem(id: "phrasal", title: "Phrasal Verbs", count: s.phrasalVerbsCount, icon: "books.vertical.fill", color: DS.Colors.purple, unit: "questions")
        ]
        return items.filter { $0.count > 0 }
    }

    private var totalCount: Int {
        activeStatItems.reduce(0) { $0 + $1.count }
    }

    private var formattedDateString: String {
        if calendar.isDateInToday(selectedDate) {
            return "Today, \(selectedDate.formatted(.dateTime.month(.abbreviated).day()))"
        } else if calendar.isDateInYesterday(selectedDate) {
            return "Yesterday, \(selectedDate.formatted(.dateTime.month(.abbreviated).day()))"
        } else {
            return selectedDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.md) {
                    dateNavigatorBar

                    if activeStatItems.isEmpty {
                        VStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 38))
                                .foregroundStyle(.secondary)
                            Text("No Practice Logged")
                                .font(.dsHeadline)
                            Text("No exercises were completed on this date.")
                                .font(.dsCallout)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.xl)
                        .dsCard()
                    } else {
                        // Total card
                        HStack(spacing: DS.Spacing.md) {
                            DSIconBadge(systemImage: "flame.fill", color: DS.Colors.primary, size: 46)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Total Completed")
                                    .font(.dsCaption)
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text("\(totalCount)")
                                        .font(.system(size: 30, weight: .bold, design: .rounded))
                                    Text("items")
                                        .font(.dsCallout)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .dsCard()

                        // Breakdown list
                        VStack(spacing: 0) {
                            ForEach(Array(activeStatItems.enumerated()), id: \.element.id) { index, item in
                                if index > 0 {
                                    Divider().padding(.leading, 54)
                                }
                                HStack(spacing: DS.Spacing.md) {
                                    DSIconBadge(systemImage: item.icon, color: item.color)
                                    Text(item.title)
                                        .font(.dsBody)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Text("\(item.count)")
                                            .font(.dsHeadline)
                                            .foregroundStyle(item.color)
                                        Text(item.unit)
                                            .font(.dsCaption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.vertical, 10)
                            }
                        }
                        .dsCard(padding: DS.Spacing.md)
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
            }
            .background(DS.Surfaces.canvas.ignoresSafeArea())
            .navigationTitle("Daily History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isToday {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Today") {
                            withAnimation { selectedDate = Date() }
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationStack {
                    DatePicker("Select Date", selection: $selectedDate, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(DS.Colors.primary)
                        .padding()
                        .navigationTitle("Pick Date")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { showingDatePicker = false }
                            }
                        }
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var dateNavigatorBar: some View {
        HStack {
            Button { changeDate(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Colors.primary)
                    .frame(width: 36, height: 36)
                    .background(DS.Surfaces.card)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(DS.Surfaces.border, lineWidth: 1))
            }

            Spacer()

            Button { showingDatePicker = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DS.Colors.primary)
                    Text(formattedDateString)
                        .font(.dsCallout)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(DS.Surfaces.card)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(DS.Surfaces.border, lineWidth: 1))
            }

            Spacer()

            Button { changeDate(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isToday ? .secondary.opacity(0.35) : DS.Colors.primary)
                    .frame(width: 36, height: 36)
                    .background(DS.Surfaces.card)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(DS.Surfaces.border, lineWidth: 1))
            }
            .disabled(isToday)
        }
    }

    private func changeDate(by days: Int) {
        guard let next = calendar.date(byAdding: .day, value: days, to: selectedDate) else { return }
        if days > 0 && calendar.startOfDay(for: next) > calendar.startOfDay(for: Date()) { return }
        Haptics.selection()
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedDate = next
        }
    }
}
