//
//  VerbConjugationView.swift
//  VocabularyPool
//
//  Quick-review Irregular Verb Conjugation Deck (V1 → V2 → V3) in Apple Crafted / Editorial style.
//

import SwiftUI
import SwiftData

struct VerbConjugationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allWords: [Word]
    @AppStorage("isPracticeSoundEnabled") private var isSoundEnabled: Bool = true

    @State private var cards: [Word] = []
    @State private var currentIndex: Int = 0
    @State private var cardOffset: CGSize = .zero
    @State private var isFinished: Bool = false

    private var verbWords: [Word] {
        allWords.filter { $0.hasConjugations }
    }

    private var currentWord: Word? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            if verbWords.isEmpty {
                ContentUnavailableView(
                    "No Irregular Verbs Yet",
                    systemImage: "repeat",
                    description: Text("Add a word and toggle Irregular Verb (V2 / V3) to practice conjugations here.")
                )
            } else if isFinished {
                completionView
            } else if let word = currentWord {
                HStack {
                    Text("Swipe card to review next verb")
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    DSBadge(text: "\(currentIndex + 1) / \(cards.count)", color: DS.Colors.accent)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.sm)

                Spacer()

                VStack(spacing: DS.Spacing.lg) {
                    VStack(spacing: 4) {
                        DSBadge(text: "V1 • Base", color: DS.Colors.primary)
                        Text(word.english)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    Divider()

                    HStack(spacing: DS.Spacing.md) {
                        VStack(spacing: 4) {
                            Text("V2 • Past")
                                .font(.dsCaption)
                                .foregroundStyle(DS.Colors.purple)
                            Text(word.v2 ?? "-")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(DS.Surfaces.muted)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))

                        Image(systemName: "arrow.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.tertiary)

                        VStack(spacing: 4) {
                            Text("V3 • Participle")
                                .font(.dsCaption)
                                .foregroundStyle(DS.Colors.accent)
                            Text(word.v3 ?? "-")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.md)
                        .background(DS.Surfaces.muted)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    }

                    Text(word.formattedTurkishMeanings)
                        .font(.dsTitle)
                        .foregroundStyle(DS.Colors.accent)
                        .multilineTextAlignment(.center)

                    Button {
                        speak(word)
                    } label: {
                        Label("Listen", systemImage: "speaker.wave.2.fill")
                            .font(.dsCaption)
                            .foregroundStyle(DS.Colors.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(DS.Colors.primary.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .dsCard(padding: DS.Spacing.xl, cornerRadius: DS.Radius.xl)
                .padding(.horizontal, DS.Spacing.md)
                .offset(x: cardOffset.width, y: cardOffset.height * 0.2)
                .rotationEffect(.degrees(Double(cardOffset.width / 20)))
                .gesture(
                    DragGesture()
                        .onChanged { cardOffset = $0.translation }
                        .onEnded { gesture in
                            if abs(gesture.translation.width) > 95 {
                                advanceCard(direction: gesture.translation.width > 0 ? 1 : -1)
                            } else {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    cardOffset = .zero
                                }
                            }
                        }
                )

                Spacer()

                DSPrimaryButton(title: "Next Verb", systemImage: "arrow.right", color: DS.Colors.accent) {
                    advanceCard(direction: 1)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.md)
            }
        }
        .background(DS.Surfaces.canvas.ignoresSafeArea())
        .navigationTitle("Irregular Verbs")
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

    private var completionView: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            VStack(spacing: DS.Spacing.md) {
                DSIconBadge(systemImage: "repeat", color: DS.Colors.accent, size: 64)
                Text("Verbs Reviewed!")
                    .font(.dsTitle)
                Text("\(cards.count) irregular verbs completed")
                    .font(.dsCallout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .dsCard(padding: DS.Spacing.xl, cornerRadius: DS.Radius.xl)
            .padding(.horizontal, DS.Spacing.md)

            Spacer()

            VStack(spacing: DS.Spacing.sm) {
                DSPrimaryButton(title: "Review Again", systemImage: "arrow.clockwise", color: DS.Colors.accent) {
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
        cards = verbWords.shuffled()
        currentIndex = 0
        cardOffset = .zero
        isFinished = false
        if isSoundEnabled, let first = cards.first {
            speak(first)
        }
    }

    private func speak(_ word: Word) {
        let forms = [word.english, word.v2, word.v3].compactMap { $0 }.joined(separator: ", ")
        SpeechService.shared.speak(forms, language: "en-US", rate: 0.45)
    }

    private func advanceCard(direction: CGFloat) {
        Haptics.light()
        withAnimation(.easeIn(duration: 0.2)) {
            cardOffset = CGSize(width: direction * 460, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            cardOffset = .zero
            if currentIndex + 1 < cards.count {
                currentIndex += 1
                if isSoundEnabled, let next = currentWord {
                    speak(next)
                }
            } else {
                SessionRecorder.record(count: cards.count, category: .verbConjugations, in: modelContext)
                Haptics.success()
                isFinished = true
            }
        }
    }
}
