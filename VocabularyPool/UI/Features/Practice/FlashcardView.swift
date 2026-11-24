//
//  FlashcardView.swift
//  VocabularyPool
//
//  3D Flippable & Swipable Flashcards with multi-meaning back card, LearningEngine SRS,
//  and Apple Crafted / Editorial styling.
//

import SwiftUI
import SwiftData

struct FlashcardView: View {
    let config: PracticeSessionConfig

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allWords: [Word]
    @AppStorage("isPracticeSoundEnabled") private var isSoundEnabled: Bool = true

    @State private var cards: [Word] = []
    @State private var currentIndex: Int = 0
    @State private var isFlipped: Bool = false
    @State private var cardOffset: CGSize = .zero

    @State private var knownCount: Int = 0
    @State private var unknownCount: Int = 0
    @State private var isFinished: Bool = false

    private var currentWord: Word? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            if cards.isEmpty {
                ContentUnavailableView("No Words Available", systemImage: "text.book.closed")
            } else if isFinished {
                completionView
            } else if let word = currentWord {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tap to flip • Swipe right if known")
                            .font(.dsCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    DSBadge(text: "\(currentIndex + 1) / \(cards.count)", color: DS.Colors.primary)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.sm)

                Spacer()

                // 3D Flippable Card
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                        .fill(DS.Surfaces.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.xl, style: .continuous)
                                .strokeBorder(cardBorderColor, lineWidth: abs(cardOffset.width) > 30 ? 2 : 1)
                        )
                        .shadow(color: DS.Surfaces.shadow, radius: 14, x: 0, y: 6)

                    // Swipe Badges
                    VStack {
                        HStack {
                            if cardOffset.width > 30 {
                                DSBadge(text: "KNOW IT", color: DS.Colors.success)
                                    .padding(DS.Spacing.md)
                            }
                            Spacer()
                            if cardOffset.width < -30 {
                                DSBadge(text: "STILL LEARNING", color: DS.Colors.danger)
                                    .padding(DS.Spacing.md)
                            }
                        }
                        Spacer()
                    }

                    // Card Content
                    if !isFlipped {
                        VStack(spacing: DS.Spacing.md) {
                            Spacer()
                            Text(word.english)
                                .font(.dsDisplay)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DS.Spacing.lg)

                            if let alt = word.englishAlt, !alt.isEmpty {
                                Text("(\(alt))")
                                    .font(.dsCallout)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Label("Tap to reveal meaning", systemImage: "arrow.triangle.2.circlepath")
                                .font(.dsCaption)
                                .foregroundStyle(.tertiary)
                                .padding(.bottom, DS.Spacing.md)
                        }
                    } else {
                        VStack(spacing: DS.Spacing.md) {
                            Spacer()
                            Text(word.formattedTurkishMeanings)
                                .font(.dsTitle)
                                .foregroundStyle(DS.Colors.primary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, DS.Spacing.lg)

                            if word.hasConjugations, let v2 = word.v2, let v3 = word.v3 {
                                Text("V2: \(v2) • V3: \(v3)")
                                    .font(.dsCallout)
                                    .foregroundStyle(DS.Colors.accent)
                            }
                            Spacer()
                            Button {
                                SpeechService.shared.speak(word.english, language: "en-US")
                            } label: {
                                Label("Listen", systemImage: "speaker.wave.2.fill")
                                    .font(.dsCaption)
                                    .foregroundStyle(DS.Colors.primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(DS.Colors.primary.opacity(0.10))
                                    .clipShape(Capsule())
                            }
                            .padding(.bottom, DS.Spacing.md)
                        }
                        .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    }
                }
                .frame(height: 330)
                .padding(.horizontal, DS.Spacing.md)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
                .offset(x: cardOffset.width, y: cardOffset.height * 0.25)
                .rotationEffect(.degrees(Double(cardOffset.width / 18)))
                .gesture(
                    DragGesture()
                        .onChanged { cardOffset = $0.translation }
                        .onEnded { gesture in
                            if gesture.translation.width > 110 {
                                handleSwipe(known: true, word: word)
                            } else if gesture.translation.width < -110 {
                                handleSwipe(known: false, word: word)
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) {
                                    cardOffset = .zero
                                }
                            }
                        }
                )
                .onTapGesture {
                    Haptics.light()
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                        isFlipped.toggle()
                    }
                }

                Spacer()

                // Explicit Action Buttons
                HStack(spacing: DS.Spacing.md) {
                    DSSecondaryButton(title: "Still Learning", systemImage: "xmark", tint: DS.Colors.danger) {
                        handleSwipe(known: false, word: word)
                    }
                    DSPrimaryButton(title: "Know It", systemImage: "checkmark", color: DS.Colors.success) {
                        handleSwipe(known: true, word: word)
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.md)
            }
        }
        .background(DS.Surfaces.canvas.ignoresSafeArea())
        .navigationTitle("Flashcards")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isSoundEnabled.toggle()
                    SpeechService.shared.configureAudioSession(soundEnabled: isSoundEnabled)
                } label: {
                    Image(systemName: isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .foregroundStyle(isSoundEnabled ? DS.Colors.primary : .secondary)
                }
            }
        }
        .onAppear {
            SpeechService.shared.configureAudioSession(soundEnabled: isSoundEnabled)
            setupDeck()
        }
        .onDisappear {
            SpeechService.shared.stop()
        }
    }

    private var cardBorderColor: Color {
        if cardOffset.width > 30 { return DS.Colors.success }
        if cardOffset.width < -30 { return DS.Colors.danger }
        return DS.Surfaces.border
    }

    private var completionView: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            VStack(spacing: DS.Spacing.md) {
                DSIconBadge(systemImage: "rectangle.stack.fill", color: DS.Colors.purple, size: 64)
                Text("Deck Complete")
                    .font(.dsTitle)
                HStack(spacing: DS.Spacing.xl) {
                    VStack {
                        Text("\(knownCount)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.success)
                        Text("Known")
                            .font(.dsCaption)
                            .foregroundStyle(.secondary)
                    }
                    VStack {
                        Text("\(unknownCount)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.danger)
                        Text("Still Learning")
                            .font(.dsCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .dsCard(padding: DS.Spacing.xl, cornerRadius: DS.Radius.xl)
            .padding(.horizontal, DS.Spacing.md)

            Spacer()

            VStack(spacing: DS.Spacing.sm) {
                DSPrimaryButton(title: "Review Again", systemImage: "arrow.clockwise") {
                    setupDeck()
                }
                DSSecondaryButton(title: "Done") {
                    dismiss()
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.lg)
        }
    }

    private func setupDeck() {
        cards = PracticePoolResolver.resolveWords(from: allWords, config: config)
        currentIndex = 0
        knownCount = 0
        unknownCount = 0
        isFlipped = false
        cardOffset = .zero
        isFinished = false
        if isSoundEnabled, let first = cards.first {
            SpeechService.shared.speak(first.english, language: "en-US")
        }
    }

    private func handleSwipe(known: Bool, word: Word) {
        if known {
            Haptics.success()
            knownCount += 1
            LearningEngine.recordCorrect(for: word)
        } else {
            Haptics.error()
            unknownCount += 1
            LearningEngine.recordWrong(for: word)
        }
        try? modelContext.save()

        withAnimation(.easeIn(duration: 0.22)) {
            cardOffset = CGSize(width: known ? 480 : -480, height: 0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isFlipped = false
            cardOffset = .zero
            if currentIndex + 1 < cards.count {
                currentIndex += 1
                if isSoundEnabled, let next = currentWord {
                    SpeechService.shared.speak(next.english, language: "en-US")
                }
            } else {
                SessionRecorder.record(count: cards.count, category: .flashcards, in: modelContext)
                isFinished = true
            }
        }
    }
}
