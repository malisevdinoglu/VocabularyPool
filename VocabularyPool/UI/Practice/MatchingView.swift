//
//  MatchingView.swift
//  VocabularyPool
//
//  Created by Assistant on 05.01.2026.
//

import SwiftUI
import SwiftData
import AVFoundation

struct TurkishMatchItem: Identifiable, Equatable {
    let id: UUID
    let word: Word
    var text: String { word.turkish }
}

struct MatchingView: View {
    let config: QuizConfig
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allWords: [Word]

    @State private var englishWords: [Word] = []
    @State private var turkishItems: [TurkishMatchItem] = []

    @State private var selectedEnglish: Word? = nil
    @State private var selectedTurkish: TurkishMatchItem? = nil

    @State private var matchedWords: Set<Word> = []
    @State private var wrongAttempts: Int = 0
    @State private var isFinished = false

    @State private var shakingEnglishWord: Word? = nil
    @State private var shakingTurkishItem: TurkishMatchItem? = nil

    @AppStorage("isPracticeSoundEnabled") private var isSoundEnabled: Bool = true
    private let speechSynthesizer = AVSpeechSynthesizer()

    var body: some View {
        VStack {
            if englishWords.isEmpty {
                ContentUnavailableView("Kelime Bulunamadı", systemImage: "text.book.closed")
            } else if !isFinished {
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        
                        // MARK: - Progress & Header Info
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Kelime Eşleştirme")
                                    .font(.dsHeadline)
                                    .foregroundStyle(.primary)
                                Text("Sol sütundan İngilizce, sağ sütundan Türkçe karşılığı seçin")
                                    .font(.dsCaption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(DS.Colors.success)
                                Text("\(matchedWords.count) / 5")
                                    .font(.dsHeadline)
                                    .foregroundStyle(DS.Colors.success)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(DS.Colors.success.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .padding(.horizontal, DS.Spacing.md)

                        // MARK: - Matching Grid (Dual Columns)
                        HStack(alignment: .top, spacing: DS.Spacing.md) {
                            
                            // Left Column: English Words
                            VStack(spacing: DS.Spacing.sm) {
                                Text("İngilizce")
                                    .font(.dsCaption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(DS.Colors.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 4)

                                ForEach(englishWords) { word in
                                    MatchingCardButton(
                                        title: word.english,
                                        isMatched: matchedWords.contains(word),
                                        isSelected: selectedEnglish == word,
                                        isShaking: shakingEnglishWord == word,
                                        showSpeaker: true
                                    ) {
                                        handleEnglishSelect(word)
                                    }
                                }
                            }

                            // Right Column: Turkish Words
                            VStack(spacing: DS.Spacing.sm) {
                                Text("Türkçe")
                                    .font(.dsCaption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(DS.Colors.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 4)

                                ForEach(turkishItems) { item in
                                    MatchingCardButton(
                                        title: item.text,
                                        isMatched: matchedWords.contains(item.word),
                                        isSelected: selectedTurkish == item,
                                        isShaking: shakingTurkishItem == item,
                                        showSpeaker: false
                                    ) {
                                        handleTurkishSelect(item)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.md)
                    }
                    .padding(.top, DS.Spacing.md)
                }
            } else {
                // MARK: - Results View
                VStack(spacing: DS.Spacing.lg) {
                    Spacer()

                    VStack(spacing: DS.Spacing.lg) {
                        Image(systemName: wrongAttempts == 0 ? "star.fill" : "sparkles")
                            .font(.system(size: 64))
                            .foregroundStyle(wrongAttempts == 0 ? .yellow : DS.Colors.purple)

                        Text("Eşleştirme Tamamlandı!")
                            .font(.dsTitle)

                        Text("5 / 5 Çift Eşleşti")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.purple)

                        VStack(spacing: DS.Spacing.xs) {
                            HStack {
                                Text("Yanlış Deneme Sayısı")
                                    .font(.dsCallout)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(wrongAttempts)")
                                    .font(.dsHeadline)
                                    .foregroundStyle(wrongAttempts == 0 ? DS.Colors.success : DS.Colors.warning)
                            }
                            .padding(.horizontal, DS.Spacing.md)
                        }
                    }
                    .padding(DS.Spacing.xl)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
                    .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, DS.Spacing.md)

                    Spacer()

                    VStack(spacing: DS.Spacing.md) {
                        Button {
                            recordPracticeSession()
                            restartMatching()
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Alıştırmayı Tekrarla")
                                    .font(.dsHeadline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(DS.Colors.purple)
                            .foregroundStyle(DS.Colors.onColor)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        }

                        Button {
                            recordPracticeSession()
                            dismiss()
                        } label: {
                            Text("Tamamla")
                                .font(.dsHeadline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Color.secondary.opacity(0.12))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.lg)
                }
            }
        }
        .navigationTitle("Eşleştirme Modu")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            prepareMatching()
        }
    }

    // MARK: - Matching Logic

    private func handleEnglishSelect(_ word: Word) {
        speakWord(word.english)
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedEnglish = word
        }
        checkPairIfPossible()
    }

    private func handleTurkishSelect(_ item: TurkishMatchItem) {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedTurkish = item
        }
        checkPairIfPossible()
    }

    private func checkPairIfPossible() {
        guard let eng = selectedEnglish, let tur = selectedTurkish else { return }

        if eng == tur.word {
            // Correct Pair Match!
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()

            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                matchedWords.insert(eng)
                eng.correctCount += 1
                eng.needsReview = false
                selectedEnglish = nil
                selectedTurkish = nil
            }

            if matchedWords.count == englishWords.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation {
                        isFinished = true
                    }
                }
            }
        } else {
            // Wrong Pair Match!
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)

            eng.wrongCount += 1
            eng.needsReview = true
            wrongAttempts += 1

            shakingEnglishWord = eng
            shakingTurkishItem = tur

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    shakingEnglishWord = nil
                    shakingTurkishItem = nil
                    selectedEnglish = nil
                    selectedTurkish = nil
                }
            }
        }
    }

    private func speakWord(_ text: String) {
        guard isSoundEnabled else { return }
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        speechSynthesizer.speak(utterance)
    }

    private func prepareMatching() {
        var wordsToUse: [Word]

        if config.reviewMode {
            wordsToUse = allWords.filter { $0.needsReview }
        } else if config.weakWordsMode {
            wordsToUse = allWords.filter { word in
                let total = word.correctCount + word.wrongCount
                return word.wrongCount > 0 || (total > 0 && (Double(word.correctCount) / Double(total)) <= 0.70)
            }
        } else {
            let sorted = allWords.sorted { $0.timestamp < $1.timestamp }
            if let start = config.wordRangeStart, let end = config.wordRangeEnd {
                let startIndex = max(0, start - 1)
                let endIndex = min(sorted.count - 1, end - 1)
                if startIndex <= endIndex && startIndex < sorted.count {
                    wordsToUse = Array(sorted[startIndex...endIndex])
                } else {
                    wordsToUse = sorted
                }
            } else {
                wordsToUse = sorted
            }
        }

        let selected = Array(wordsToUse.shuffled().prefix(5))
        englishWords = selected

        turkishItems = selected.map { word in
            TurkishMatchItem(id: UUID(), word: word)
        }.shuffled()

        matchedWords.removeAll()
        selectedEnglish = nil
        selectedTurkish = nil
        wrongAttempts = 0
        isFinished = false
    }

    private func restartMatching() {
        withAnimation {
            prepareMatching()
        }
    }

    private func recordPracticeSession() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return }

        let descriptor = FetchDescriptor<PracticeSession>(
            predicate: #Predicate { session in
                session.date >= today && session.date < tomorrow
            }
        )

        do {
            let sessions = try modelContext.fetch(descriptor)
            let session: PracticeSession

            if let existing = sessions.first {
                session = existing
            } else {
                let currentGoals = PracticeGoals.shared
                session = PracticeSession(
                    date: today,
                    dailyGoalEngToTr: currentGoals.englishToTurkishGoal,
                    dailyGoalTrToEng: currentGoals.turkishToEnglishGoal,
                    dailyGoalListening: currentGoals.listeningGoal
                )
                modelContext.insert(session)
            }

            session.matchingCount += englishWords.count
            try modelContext.save()
        } catch {
            print("Failed to record matching session: \(error)")
        }
    }
}

// MARK: - Subview Component for Cards

struct MatchingCardButton: View {
    let title: String
    let isMatched: Bool
    let isSelected: Bool
    let isShaking: Bool
    let showSpeaker: Bool
    let action: () -> Void

    private var cardBackground: Color {
        if isMatched { return DS.Colors.success.opacity(0.10) }
        if isShaking { return DS.Colors.danger.opacity(0.20) }
        if isSelected { return DS.Colors.purple }
        return Color(uiColor: .secondarySystemGroupedBackground)
    }

    private var strokeColor: Color {
        if isMatched { return DS.Colors.success.opacity(0.3) }
        if isShaking { return DS.Colors.danger }
        if isSelected { return DS.Colors.purple }
        return Color.secondary.opacity(0.15)
    }

    private var textColor: Color {
        if isMatched { return .secondary }
        if isSelected { return .white }
        return .primary
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.dsHeadline)
                    .foregroundStyle(textColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Spacer()

                if isMatched {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Colors.success)
                } else if showSpeaker {
                    Image(systemName: "speaker.wave.1.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(isSelected ? Color.white.opacity(0.8) : Color.secondary.opacity(0.5))
                }
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .stroke(strokeColor, lineWidth: isSelected || isShaking ? 2 : 1)
            )
            .shadow(color: isSelected ? DS.Colors.purple.opacity(0.2) : Color.black.opacity(0.03), radius: isSelected ? 6 : 2, x: 0, y: 2)
            .offset(x: isShaking ? -6 : 0)
        }
        .buttonStyle(.plain)
        .disabled(isMatched)
    }
}

#Preview {
    NavigationStack {
        MatchingView(config: QuizConfig(count: 5, type: .matching))
            .modelContainer(for: Word.self, inMemory: true)
    }
}
