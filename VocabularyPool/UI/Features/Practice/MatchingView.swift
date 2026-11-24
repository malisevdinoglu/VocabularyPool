//
//  MatchingView.swift
//  VocabularyPool
//
//  5-pair Matching practice powered by PracticePoolResolver, LearningEngine, SpeechService, and SessionRecorder.
//

import SwiftUI
import SwiftData

private struct TurkishMatchOption: Identifiable, Equatable {
    let id = UUID()
    let word: Word
    var text: String { word.turkish }
}

struct MatchingView: View {
    let config: PracticeSessionConfig

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allWords: [Word]
    @AppStorage("isPracticeSoundEnabled") private var isSoundEnabled: Bool = true

    @State private var englishWords: [Word] = []
    @State private var turkishOptions: [TurkishMatchOption] = []
    @State private var selectedEnglish: Word? = nil
    @State private var selectedTurkish: TurkishMatchOption? = nil
    @State private var matchedIDs: Set<PersistentIdentifier> = []
    @State private var wrongAttempts: Int = 0
    @State private var isFinished: Bool = false

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            if englishWords.isEmpty {
                ContentUnavailableView("No Words Available", systemImage: "text.book.closed")
            } else if isFinished {
                completionView
            } else {
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        HStack {
                            Text("Match each English word with its meaning")
                                .font(.dsCaption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            DSBadge(text: "\(matchedIDs.count) / \(englishWords.count)", color: DS.Colors.success)
                        }

                        HStack(alignment: .top, spacing: DS.Spacing.md) {
                            VStack(spacing: DS.Spacing.sm) {
                                Text("English")
                                    .font(.dsCaption)
                                    .foregroundStyle(DS.Colors.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                ForEach(englishWords) { word in
                                    matchTile(
                                        title: word.english,
                                        isMatched: matchedIDs.contains(word.persistentModelID),
                                        isSelected: selectedEnglish?.persistentModelID == word.persistentModelID
                                    ) {
                                        selectEnglish(word)
                                    }
                                }
                            }

                            VStack(spacing: DS.Spacing.sm) {
                                Text("Turkish")
                                    .font(.dsCaption)
                                    .foregroundStyle(DS.Colors.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                ForEach(turkishOptions) { option in
                                    matchTile(
                                        title: option.text,
                                        isMatched: matchedIDs.contains(option.word.persistentModelID),
                                        isSelected: selectedTurkish?.id == option.id
                                    ) {
                                        selectTurkish(option)
                                    }
                                }
                            }
                        }
                    }
                    .padding(DS.Spacing.md)
                }
            }
        }
        .background(DS.Surfaces.canvas.ignoresSafeArea())
        .navigationTitle("Matching")
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
            setupRound()
        }
        .onDisappear {
            SpeechService.shared.stop()
        }
    }

    private func matchTile(title: String, isMatched: Bool, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.dsCallout)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundStyle(isMatched ? DS.Colors.success : .primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 58)
                .padding(.horizontal, 10)
                .background(
                    isMatched
                    ? DS.Colors.success.opacity(0.08)
                    : (isSelected ? DS.Colors.primary.opacity(0.10) : DS.Surfaces.card)
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .strokeBorder(
                            isMatched ? DS.Colors.success.opacity(0.4) : (isSelected ? DS.Colors.primary : DS.Surfaces.border),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
                .opacity(isMatched ? 0.55 : 1.0)
        }
        .buttonStyle(DSSpringButtonStyle())
        .disabled(isMatched)
    }

    private var completionView: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
            VStack(spacing: DS.Spacing.md) {
                DSIconBadge(systemImage: "checkmark.seal.fill", color: DS.Colors.success, size: 64)
                Text("All Pairs Matched!")
                    .font(.dsTitle)
                Text(wrongAttempts == 0 ? "Flawless round!" : "\(wrongAttempts) wrong attempt(s)")
                    .font(.dsCallout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .dsCard(padding: DS.Spacing.xl, cornerRadius: DS.Radius.xl)
            .padding(.horizontal, DS.Spacing.md)

            Spacer()

            VStack(spacing: DS.Spacing.sm) {
                DSPrimaryButton(title: "New Round", systemImage: "arrow.clockwise") {
                    setupRound()
                }
                DSSecondaryButton(title: "Done") {
                    dismiss()
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.lg)
        }
    }

    private func setupRound() {
        let resolved = PracticePoolResolver.resolveWords(from: allWords, config: config)
        englishWords = resolved.shuffled()
        turkishOptions = resolved.map { TurkishMatchOption(word: $0) }.shuffled()
        selectedEnglish = nil
        selectedTurkish = nil
        matchedIDs = []
        wrongAttempts = 0
        isFinished = false
    }

    private func selectEnglish(_ word: Word) {
        Haptics.selection()
        selectedEnglish = word
        if isSoundEnabled {
            SpeechService.shared.speak(word.english, language: "en-US")
        }
        evaluateMatchIfReady()
    }

    private func selectTurkish(_ option: TurkishMatchOption) {
        Haptics.selection()
        selectedTurkish = option
        evaluateMatchIfReady()
    }

    private func evaluateMatchIfReady() {
        guard let eng = selectedEnglish, let tr = selectedTurkish else { return }

        if eng.persistentModelID == tr.word.persistentModelID {
            Haptics.success()
            matchedIDs.insert(eng.persistentModelID)
            LearningEngine.recordCorrect(for: eng)
            try? modelContext.save()
            selectedEnglish = nil
            selectedTurkish = nil

            if matchedIDs.count == englishWords.count {
                SessionRecorder.record(count: englishWords.count, category: .matching, in: modelContext)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    withAnimation { isFinished = true }
                }
            }
        } else {
            Haptics.error()
            wrongAttempts += 1
            LearningEngine.recordWrong(for: eng)
            try? modelContext.save()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                selectedEnglish = nil
                selectedTurkish = nil
            }
        }
    }
}
