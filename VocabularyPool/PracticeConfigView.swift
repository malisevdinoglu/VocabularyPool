//
//  PracticeConfigView.swift
//  VocabularyPool
//
//  Created by Assistant on 02.01.2026.
//

import SwiftUI
import SwiftData

struct PracticeConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var words: [Word]
    @Query(filter: #Predicate<Word> { $0.needsReview == true }) private var reviewWords: [Word]

    @State private var count = 10
    @State private var type: PracticeType = .englishToTurkish
    @State private var useWordRange = false
    @State private var fromText = ""
    @State private var toText = ""
    @State private var showingQuiz = false
    @State private var showingReviewQuiz = false
    @State private var showingSettings = false

    enum PracticeType: String, CaseIterable, Identifiable {
        case englishToTurkish = "English -> Turkish"
        case turkishToEnglish = "Turkish -> English"
        case listening = "Listening (Write what you hear)"

        var id: String { self.rawValue }
    }
    
    var totalWords: Int {
        words.count
    }
    
    var wordRangeStart: Int? {
        guard useWordRange, let from = Int(fromText), from > 0 else { return nil }
        return from
    }
    
    var wordRangeEnd: Int? {
        guard useWordRange, let to = Int(toText), to > 0 else { return nil }
        return to
    }
    
    var isRangeValid: Bool {
        if !useWordRange { return true }
        
        guard let from = wordRangeStart, let to = wordRangeEnd else {
            return false
        }
        
        return from <= to && from <= totalWords && to <= totalWords
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Review Mistakes Section — always visible
                Section {
                    ReviewMistakesCard(count: reviewWords.count) {
                        if !reviewWords.isEmpty {
                            showingReviewQuiz = true
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } header: {
                    Text("Pekiştirme")
                }

                // Word Pool Section
                Section {
                    HStack {
                        DSIconBadge(systemImage: "books.vertical.fill", color: DS.Colors.primary)
                        Text("Total Words")
                        Spacer()
                        Text("\(totalWords)")
                            .font(.dsHeadline)
                            .foregroundStyle(DS.Colors.primary)
                    }

                    Toggle(isOn: $useWordRange) {
                        HStack {
                            DSIconBadge(systemImage: "list.number", color: DS.Colors.accent)
                            Text("Select Word Range")
                        }
                    }

                    if useWordRange {
                        HStack {
                            Text("From")
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("1", text: $fromText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .onChange(of: fromText) { _, newValue in
                                    fromText = newValue.filter { $0.isNumber }
                                }
                        }

                        HStack {
                            Text("To")
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("\(totalWords)", text: $toText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                                .onChange(of: toText) { _, newValue in
                                    toText = newValue.filter { $0.isNumber }
                                }
                        }

                        if !isRangeValid {
                            Label(
                                "Invalid range. From must be ≤ To and both ≤ \(totalWords)",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.dsCaption)
                            .foregroundStyle(DS.Colors.danger)
                        }
                    }
                } header: {
                    Text("Word Pool")
                }

                // Practice Mode Section
                Section {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        HStack(spacing: DS.Spacing.sm) {
                            PracticeModeCard(
                                title: "EN → TR",
                                icon: "text.book.closed.fill",
                                color: DS.Colors.engToTr,
                                isSelected: type == .englishToTurkish
                            ) { type = .englishToTurkish }

                            PracticeModeCard(
                                title: "TR → EN",
                                icon: "globe",
                                color: DS.Colors.trToEng,
                                isSelected: type == .turkishToEnglish
                            ) { type = .turkishToEnglish }

                            PracticeModeCard(
                                title: "Listen",
                                icon: "headphones",
                                color: DS.Colors.listening,
                                isSelected: type == .listening
                            ) { type = .listening }
                        }
                        .padding(.vertical, DS.Spacing.xs)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Text("Practice Mode")
                }

                // Question Count Section
                Section {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Number of Questions")
                            .font(.dsCallout)
                            .foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DS.Spacing.sm) {
                                ForEach([5, 10, 15, 20, 25, 30], id: \.self) { n in
                                    DSChip(label: "\(n)", isSelected: count == n) {
                                        count = n
                                    }
                                }
                            }
                            .padding(.vertical, DS.Spacing.xs)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                } header: {
                    Text("Settings")
                }
            }
            .navigationTitle("Setup Practice")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .safeAreaInset(edge: .bottom) {
                DSPrimaryButton(
                    title: "Start Practice",
                    isDisabled: words.isEmpty || !isRangeValid
                ) {
                    showingQuiz = true
                }
                .padding(.vertical, DS.Spacing.xs)
                .background(Color(uiColor: .systemBackground))
            }
            .navigationDestination(isPresented: $showingQuiz) {
                QuizView(config: QuizConfig(
                    count: count,
                    type: type,
                    wordRangeStart: wordRangeStart,
                    wordRangeEnd: wordRangeEnd
                ))
            }
            .navigationDestination(isPresented: $showingReviewQuiz) {
                QuizView(config: QuizConfig(
                    count: reviewWords.count,
                    type: .englishToTurkish,
                    wordRangeStart: nil,
                    wordRangeEnd: nil,
                    reviewMode: true
                ))
            }
        }
    }
}

struct QuizConfig {
    var count: Int
    var type: PracticeConfigView.PracticeType
    var wordRangeStart: Int?
    var wordRangeEnd: Int?
    var reviewMode: Bool = false
}

// MARK: - Review Mistakes Card

struct ReviewMistakesCard: View {
    let count: Int
    let action: () -> Void

    private var isEmpty: Bool { count == 0 }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(isEmpty ? Color.secondary.opacity(0.10) : DS.Colors.danger.opacity(0.12))
                        .frame(width: 52, height: 52)
                    Image(systemName: isEmpty ? "checkmark" : "arrow.counterclockwise")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isEmpty ? Color.secondary : DS.Colors.danger)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Hataları Pekiştir")
                        .font(.dsHeadline)
                        .foregroundStyle(isEmpty ? .secondary : .primary)
                    Text(isEmpty ? "Henüz hatalı kelime yok" : "\(count) kelime tekrar bekliyor")
                        .font(.dsCallout)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !isEmpty {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(DS.Spacing.md)
            .background(isEmpty ? Color.secondary.opacity(0.06) : DS.Colors.danger.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(
                        isEmpty ? Color.secondary.opacity(0.15) : DS.Colors.danger.opacity(0.25),
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        }
        .buttonStyle(.plain)
        .disabled(isEmpty)
    }
}

// MARK: - Practice Mode Card

struct PracticeModeCard: View {
    let title: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isSelected ? DS.Colors.onColor : color)
                Text(title)
                    .font(.dsCaption)
                    .fontWeight(.semibold)
                    .foregroundStyle(isSelected ? DS.Colors.onColor : .primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(isSelected ? color : color.opacity(0.10))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    NavigationStack {
        PracticeConfigView()
            .modelContainer(for: Word.self, inMemory: true)
    }
}
