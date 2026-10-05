//
//  FlashcardView.swift
//  VocabularyPool
//
//  Created by Assistant on 05.01.2026.
//

import SwiftUI
import SwiftData
import AVFoundation

struct FlashcardView: View {
    let config: QuizConfig
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allWords: [Word]

    @State private var cards: [Word] = []
    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var cardOffset: CGSize = .zero

    @State private var knownCount: Int = 0
    @State private var unknownCount: Int = 0
    @State private var isFinished: Bool = false

    @AppStorage("isPracticeSoundEnabled") private var isSoundEnabled: Bool = true
    private let speechSynthesizer = AVSpeechSynthesizer()

    var currentWord: Word? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var body: some View {
        VStack {
            if cards.isEmpty {
                ContentUnavailableView("Kelime Bulunamadı", systemImage: "text.book.closed")
            } else if !isFinished, let word = currentWord {
                VStack(spacing: DS.Spacing.lg) {
                    
                    // MARK: - Progress & Header Info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Akıllı Kartlar")
                                .font(.dsHeadline)
                                .foregroundStyle(.primary)
                            Text("Karta dokunarak anlamını görün, sağa/sola kaydırın")
                                .font(.dsCaption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        Text("\(currentIndex + 1) / \(cards.count)")
                            .font(.dsHeadline)
                            .foregroundStyle(DS.Colors.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(DS.Colors.primary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, DS.Spacing.md)

                    Spacer()

                    // MARK: - 3D Flippable & Swipable Flashcard
                    ZStack {
                        // Card Background & Shadow
                        RoundedRectangle(cornerRadius: DS.Radius.xl)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.10), radius: 16, x: 0, y: 8)

                        // Swipe Visual Overlay Badges
                        VStack {
                            HStack {
                                if cardOffset.width > 30 {
                                    Text("BİLİYORUM")
                                        .font(.dsHeadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(DS.Colors.success)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(DS.Colors.success, lineWidth: 2)
                                        )
                                        .rotationEffect(.degrees(-15))
                                        .padding(DS.Spacing.md)
                                }
                                Spacer()
                                if cardOffset.width < -30 {
                                    Text("ÖĞRENMEM LAZIM")
                                        .font(.dsHeadline)
                                        .fontWeight(.bold)
                                        .foregroundStyle(DS.Colors.danger)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(DS.Colors.danger, lineWidth: 2)
                                        )
                                        .rotationEffect(.degrees(15))
                                        .padding(DS.Spacing.md)
                                }
                            }
                            Spacer()
                        }

                        // Card Content (Front vs Back)
                        Group {
                            if !isFlipped {
                                // FRONT SIDE (English Word)
                                VStack(spacing: DS.Spacing.md) {
                                    Spacer()

                                    Text(word.english)
                                        .font(.dsDisplay)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, DS.Spacing.md)

                                    if let alt = word.englishAlt, !alt.isEmpty {
                                        Text("(\(alt))")
                                            .font(.dsCallout)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text("Karta dokunarak anlamını gör")
                                    }
                                    .font(.dsCaption)
                                    .foregroundStyle(.tertiary)
                                    .padding(.bottom, DS.Spacing.md)
                                }
                            } else {
                                // BACK SIDE (Turkish Meaning) - Rotated 180 degrees back so it reads properly!
                                VStack(spacing: DS.Spacing.md) {
                                    Spacer()

                                    Text(word.turkish)
                                        .font(.dsDisplay)
                                        .foregroundStyle(DS.Colors.primary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, DS.Spacing.md)

                                    if let alt = word.turkishAlt, !alt.isEmpty {
                                        Text("Yan Anlam: \(alt)")
                                            .font(.dsHeadline)
                                            .foregroundStyle(DS.Colors.accent)
                                    }

                                    Spacer()

                                    HStack(spacing: 6) {
                                        Image(systemName: "speaker.wave.2.fill")
                                        Text("Sesli Dinle")
                                    }
                                    .font(.dsCaption)
                                    .foregroundStyle(DS.Colors.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(DS.Colors.primary.opacity(0.12))
                                    .clipShape(Capsule())
                                    .onTapGesture {
                                        speakWord(word.english)
                                    }
                                    .padding(.bottom, DS.Spacing.md)
                                }
                                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                            }
                        }
                    }
                    .frame(height: 340)
                    .padding(.horizontal, DS.Spacing.md)
                    .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                    .offset(x: cardOffset.width, y: cardOffset.height * 0.3)
                    .rotationEffect(.degrees(Double(cardOffset.width / 15)))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                cardOffset = gesture.translation
                            }
                            .onEnded { gesture in
                                if gesture.translation.width > 120 {
                                    swipeRight(for: word)
                                } else if gesture.translation.width < -120 {
                                    swipeLeft(for: word)
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        cardOffset = .zero
                                    }
                                }
                            }
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            isFlipped.toggle()
                        }
                    }

                    Spacer()

                    // MARK: - Bottom Ergonomic Action Buttons
                    HStack(spacing: DS.Spacing.md) {
                        // Swipe Left / Unknown Button
                        Button {
                            swipeLeft(for: word)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                Text("Öğrenmem Lazım")
                                    .font(.dsHeadline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(DS.Colors.danger.opacity(0.12))
                            .foregroundStyle(DS.Colors.danger)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .stroke(DS.Colors.danger.opacity(0.3), lineWidth: 1)
                            )
                        }

                        // Swipe Right / Known Button
                        Button {
                            swipeRight(for: word)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                Text("Biliyorum")
                                    .font(.dsHeadline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(DS.Colors.success)
                            .foregroundStyle(DS.Colors.onColor)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.lg)
                }
                .padding(.top, DS.Spacing.md)
            } else {
                // MARK: - Results View
                VStack(spacing: DS.Spacing.lg) {
                    Spacer()

                    VStack(spacing: DS.Spacing.lg) {
                        Image(systemName: unknownCount == 0 ? "star.fill" : "rectangle.stack.badge.person.crop.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(unknownCount == 0 ? .yellow : DS.Colors.primary)

                        Text("Kart Alıştırması Tamamlandı!")
                            .font(.dsTitle)

                        Text("\(knownCount) / \(cards.count)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.primary)

                        // Accuracy Stats Bar
                        let total = Double(cards.count)
                        let pct = total > 0 ? Double(knownCount) / total : 0.0
                        VStack(spacing: DS.Spacing.sm) {
                            HStack {
                                Text("Bilinen Kelimeler: \(knownCount)")
                                    .font(.dsCaption)
                                    .foregroundStyle(DS.Colors.success)
                                Spacer()
                                Text("Öğrenilecek: \(unknownCount)")
                                    .font(.dsCaption)
                                    .foregroundStyle(DS.Colors.danger)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(DS.Colors.danger.opacity(0.3))
                                        .frame(height: 10)
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(DS.Colors.success)
                                        .frame(width: geo.size.width * pct, height: 10)
                                }
                            }
                            .frame(height: 10)
                        }
                        .padding(.horizontal, DS.Spacing.md)
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
                            restartFlashcards()
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Alıştırmayı Tekrarla")
                                    .font(.dsHeadline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(DS.Colors.primary)
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
        .navigationTitle("Akıllı Kartlar")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            prepareFlashcards()
            if let firstWord = currentWord {
                speakWord(firstWord.english)
            }
        }
    }

    // MARK: - Actions & Logic

    private func swipeRight(for word: Word) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        word.correctCount += 1
        word.needsReview = false
        knownCount += 1

        animateCardExit(toRight: true)
    }

    private func swipeLeft(for word: Word) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)

        word.wrongCount += 1
        word.needsReview = true
        unknownCount += 1

        animateCardExit(toRight: false)
    }

    private func animateCardExit(toRight: Bool) {
        withAnimation(.easeOut(duration: 0.25)) {
            cardOffset = CGSize(width: toRight ? 500 : -500, height: 0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            cardOffset = .zero
            isFlipped = false
            currentIndex += 1

            if currentIndex < cards.count {
                speakWord(cards[currentIndex].english)
            } else {
                withAnimation {
                    isFinished = true
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

    private func prepareFlashcards() {
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

        let shuffled = wordsToUse.shuffled()
        let count = min(config.count, shuffled.count)
        cards = Array(shuffled.prefix(count))

        currentIndex = 0
        knownCount = 0
        unknownCount = 0
        isFlipped = false
        cardOffset = .zero
        isFinished = false
    }

    private func restartFlashcards() {
        withAnimation {
            prepareFlashcards()
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

            session.englishToTurkishCount += cards.count
            try modelContext.save()
        } catch {
            print("Failed to record flashcard session: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        FlashcardView(config: QuizConfig(count: 10, type: .flashcards))
            .modelContainer(for: Word.self, inMemory: true)
    }
}
