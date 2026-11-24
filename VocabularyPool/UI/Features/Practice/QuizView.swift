//
//  QuizView.swift
//  VocabularyPool
//
//  Typing Quiz & Listening-Type mode powered by LearningEngine (multi-meaning, typo tolerance,
//  SRS + Weak state machine, in-session re-queue) in Apple Crafted / Editorial style.
//

import SwiftUI
import SwiftData

struct QuizView: View {
    let config: PracticeSessionConfig

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allWords: [Word]
    @AppStorage("isPracticeSoundEnabled") private var isSoundEnabled: Bool = true

    private struct QuestionItem: Identifiable {
        let id = UUID()
        let word: Word
        let isRetry: Bool
    }

    @State private var queue: [QuestionItem] = []
    @State private var currentIndex: Int = 0
    @State private var initialCount: Int = 0
    @State private var firstTryCorrect: Int = 0
    @State private var isFinished: Bool = false

    @State private var userAnswer: String = ""
    @State private var feedbackMessage: String? = nil
    @State private var isCorrect: Bool = false
    @State private var isProcessing: Bool = false
    @State private var showAnswerRevealed: Bool = false
    @State private var markedWrongThisQuestion: Bool = false
    @FocusState private var isInputFocused: Bool

    private var isListeningMode: Bool {
        config.mode == .listening
    }

    private var currentItem: QuestionItem? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            if queue.isEmpty {
                ContentUnavailableView("No Words Available", systemImage: "text.book.closed")
            } else if isFinished {
                resultsView
            } else if let item = currentItem {
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {
                        // Progress Bar
                        VStack(spacing: 6) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule().fill(DS.Surfaces.muted).frame(height: 6)
                                    Capsule()
                                        .fill(isListeningMode ? DS.Colors.warning : DS.Colors.primary)
                                        .frame(width: geo.size.width * progressFraction, height: 6)
                                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentIndex)
                                }
                            }
                            .frame(height: 6)

                            HStack {
                                Text("\(currentIndex + 1) of \(queue.count)")
                                    .font(.dsCaption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if item.isRetry {
                                    DSBadge(text: "Review Again", color: DS.Colors.warning)
                                }
                            }
                        }
                        .padding(.top, DS.Spacing.sm)

                        // Prompt Card
                        VStack(spacing: DS.Spacing.md) {
                            HStack {
                                DSMasteryDots(level: item.word.masteryLevel, isWeak: item.word.isWeak)
                                Spacer()
                                Button {
                                    speakCurrentWord(force: true)
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(DS.Colors.primary)
                                        .frame(width: 36, height: 36)
                                        .background(DS.Colors.primary.opacity(0.10))
                                        .clipShape(Circle())
                                }
                            }

                            Spacer(minLength: 10)

                            if isListeningMode {
                                VStack(spacing: DS.Spacing.sm) {
                                    Image(systemName: "headphones")
                                        .font(.system(size: 42))
                                        .foregroundStyle(DS.Colors.warning)
                                    Text("Listen carefully and type the word")
                                        .font(.dsCallout)
                                        .foregroundStyle(.secondary)
                                }
                            } else {
                                Text(config.direction == .enToTr ? item.word.english : item.word.formattedTurkishMeanings)
                                    .font(.dsDisplay)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.65)
                                    .lineLimit(3)
                            }

                            Spacer(minLength: 10)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 190)
                        .dsCard(padding: DS.Spacing.lg, cornerRadius: DS.Radius.xl)

                        // Input & Actions
                        VStack(spacing: DS.Spacing.md) {
                            HStack {
                                TextField(
                                    isListeningMode || config.direction == .trToEn
                                    ? "Type English word..."
                                    : "Type a Turkish meaning...",
                                    text: $userAnswer
                                )
                                .font(.dsHeadline)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isInputFocused)
                                .disabled(isProcessing)
                                .onSubmit { checkAnswer() }

                                if !userAnswer.isEmpty && !isProcessing {
                                    Button { userAnswer = "" } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                            .padding(DS.Spacing.md)
                            .background(DS.Surfaces.card)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                    .strokeBorder(isInputFocused ? DS.Colors.primary : DS.Surfaces.border, lineWidth: isInputFocused ? 1.5 : 1)
                            )

                            if let feedback = feedbackMessage {
                                Text(feedback)
                                    .font(.dsCallout)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(isCorrect ? DS.Colors.success : DS.Colors.danger)
                                    .multilineTextAlignment(.center)
                                    .transition(.opacity)
                            }

                            if showAnswerRevealed {
                                DSPrimaryButton(title: "Next Question", color: DS.Colors.primary) {
                                    advanceQuestion()
                                }
                            } else {
                                DSPrimaryButton(
                                    title: "Check Answer",
                                    isDisabled: userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing
                                ) {
                                    checkAnswer()
                                }

                                DSSecondaryButton(title: "Show Answer", tint: DS.Colors.warning) {
                                    revealAnswer()
                                }
                                .disabled(isProcessing)
                            }
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.xl)
                }
            }
        }
        .background(DS.Surfaces.canvas.ignoresSafeArea())
        .navigationTitle(isListeningMode ? "Listening" : "Typing Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isListeningMode {
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
        }
        .onAppear {
            SpeechService.shared.configureAudioSession(soundEnabled: isListeningMode || isSoundEnabled)
            setupQuiz()
        }
        .onDisappear {
            SpeechService.shared.stop()
        }
    }

    // MARK: - Results View

    private var resultsView: some View {
        let accuracy = initialCount > 0 ? Double(firstTryCorrect) / Double(initialCount) : 0
        return VStack(spacing: DS.Spacing.lg) {
            Spacer()

            VStack(spacing: DS.Spacing.md) {
                DSIconBadge(
                    systemImage: accuracy >= 0.8 ? "checkmark.seal.fill" : "flag.checkered",
                    color: accuracy >= 0.8 ? DS.Colors.success : DS.Colors.primary,
                    size: 64
                )

                Text("Practice Complete")
                    .font(.dsTitle)

                Text("\(firstTryCorrect) / \(initialCount)")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.primary)

                Text("\(Int(accuracy * 100))% first-try accuracy")
                    .font(.dsCallout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .dsCard(padding: DS.Spacing.xl, cornerRadius: DS.Radius.xl)
            .padding(.horizontal, DS.Spacing.md)

            Spacer()

            VStack(spacing: DS.Spacing.sm) {
                DSPrimaryButton(title: "Practice Again", systemImage: "arrow.clockwise") {
                    setupQuiz()
                }
                DSSecondaryButton(title: "Done") {
                    dismiss()
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.lg)
        }
    }

    // MARK: - Logic

    private var progressFraction: Double {
        guard !queue.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(queue.count)
    }

    private func setupQuiz() {
        let resolved = PracticePoolResolver.resolveWords(from: allWords, config: config)
        queue = resolved.map { QuestionItem(word: $0, isRetry: false) }
        initialCount = queue.count
        currentIndex = 0
        firstTryCorrect = 0
        isFinished = false
        resetQuestionState()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            isInputFocused = true
            speakCurrentWord(force: false)
        }
    }

    private func resetQuestionState() {
        userAnswer = ""
        feedbackMessage = nil
        isCorrect = false
        isProcessing = false
        showAnswerRevealed = false
        markedWrongThisQuestion = false
    }

    private func speakCurrentWord(force: Bool) {
        guard let item = currentItem else { return }
        guard force || isListeningMode || isSoundEnabled else { return }

        if isListeningMode || config.direction == .enToTr {
            SpeechService.shared.speak(item.word.english, language: "en-US")
        } else {
            SpeechService.shared.speak(item.word.turkish, language: "tr-TR")
        }
    }

    private func checkAnswer() {
        guard let item = currentItem, !isProcessing else { return }
        let validAnswers = (isListeningMode || config.direction == .trToEn)
            ? item.word.allEnglishForms
            : item.word.allTurkishMeanings

        let result = LearningEngine.evaluateAnswer(userAnswer, against: validAnswers)

        if result.isCorrect {
            isProcessing = true
            isCorrect = true
            Haptics.success()

            if !item.isRetry && !markedWrongThisQuestion {
                firstTryCorrect += 1
            }
            LearningEngine.recordCorrect(for: item.word)
            try? modelContext.save()

            if isListeningMode {
                feedbackMessage = "Correct! Meaning: \(item.word.formattedTurkishMeanings)"
            } else if config.direction == .enToTr {
                let others = item.word.allTurkishMeanings.filter {
                    $0.caseInsensitiveCompare(result.matchedAnswer ?? "") != .orderedSame
                }
                if !others.isEmpty {
                    feedbackMessage = "Correct! Also: \(others.joined(separator: " • "))"
                } else if result.wasTypoTolerated, let matched = result.matchedAnswer {
                    feedbackMessage = "Correct! (Spell: \(matched))"
                } else {
                    feedbackMessage = "Correct!"
                }
            } else {
                feedbackMessage = result.wasTypoTolerated && result.matchedAnswer != nil
                    ? "Correct! (Spell: \(result.matchedAnswer!))"
                    : "Correct!"
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.05) {
                advanceQuestion()
            }
        } else {
            Haptics.error()
            isCorrect = false
            feedbackMessage = "Incorrect — try again or tap Show Answer."
            if !markedWrongThisQuestion {
                markedWrongThisQuestion = true
                LearningEngine.recordWrong(for: item.word)
                queue.append(QuestionItem(word: item.word, isRetry: true))
                try? modelContext.save()
            }
        }
    }

    private func revealAnswer() {
        guard let item = currentItem else { return }
        isProcessing = true
        isCorrect = false
        showAnswerRevealed = true
        Haptics.error()

        if !markedWrongThisQuestion {
            markedWrongThisQuestion = true
            LearningEngine.recordWrong(for: item.word)
            queue.append(QuestionItem(word: item.word, isRetry: true))
            try? modelContext.save()
        }

        if isListeningMode {
            feedbackMessage = "\(item.word.english) — \(item.word.formattedTurkishMeanings)"
        } else if config.direction == .enToTr {
            feedbackMessage = "Answer: \(item.word.formattedTurkishMeanings)"
        } else {
            feedbackMessage = "Answer: \(item.word.allEnglishForms.joined(separator: " • "))"
        }
    }

    private func advanceQuestion() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if currentIndex + 1 < queue.count {
                currentIndex += 1
                resetQuestionState()
                isInputFocused = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    speakCurrentWord(force: false)
                }
            } else {
                recordSession()
                isFinished = true
            }
        }
    }

    private func recordSession() {
        let category: SessionCategory
        if isListeningMode {
            category = .listening
        } else if config.source == .phrasal {
            category = .phrasalVerbs
        } else if config.direction == .enToTr {
            category = .englishToTurkish
        } else {
            category = .turkishToEnglish
        }
        SessionRecorder.record(count: initialCount, category: category, in: modelContext)
    }
}
