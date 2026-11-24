//
//  SmartMixSessionView.swift
//  VocabularyPool
//
//  Flagship Daily Smart Mix session blending Multiple Choice, Typing, and Listening
//  with SRS priority (50% Weak/Due + 30% New + 20% General) and in-session re-queue.
//

import SwiftUI
import SwiftData

struct SmartMixSessionView: View {
    let weakOnly: Bool
    let targetCount: Int
    let customConfig: PracticeSessionConfig?

    init(weakOnly: Bool, targetCount: Int) {
        self.weakOnly = weakOnly
        self.targetCount = targetCount
        self.customConfig = nil
    }

    init(config: PracticeSessionConfig) {
        self.weakOnly = config.source == .weak
        self.targetCount = config.count
        self.customConfig = config
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allWords: [Word]
    @AppStorage("isPracticeSoundEnabled") private var isSoundEnabled: Bool = true

    private enum StepKind: String {
        case multipleChoice = "Multiple Choice"
        case typing = "Typing"
        case listening = "Listening"
    }

    private struct MixStep: Identifiable {
        let id = UUID()
        let word: Word
        let kind: StepKind
        let isRetry: Bool
    }

    @State private var queue: [MixStep] = []
    @State private var currentIndex: Int = 0
    @State private var initialCount: Int = 0
    @State private var firstTryCorrect: Int = 0
    @State private var isFinished: Bool = false

    // Multiple Choice State
    @State private var mcOptions: [String] = []
    @State private var mcSelected: String? = nil

    // Typing / Listening State
    @State private var typedAnswer: String = ""
    @State private var feedbackText: String? = nil
    @State private var feedbackIsCorrect: Bool = false
    @State private var revealedAnswer: Bool = false
    @State private var isLocked: Bool = false
    @FocusState private var isInputFocused: Bool

    private var currentStep: MixStep? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            if queue.isEmpty {
                ContentUnavailableView(
                    weakOnly ? "No Weak Words Left" : "Add Words to Begin",
                    systemImage: weakOnly ? "checkmark.seal.fill" : "text.book.closed"
                )
            } else if isFinished {
                completionView
            } else if let step = currentStep {
                activeStepView(step)
            }
        }
        .background(DS.Surfaces.canvas.ignoresSafeArea())
        .navigationTitle(customConfig != nil ? "Smart Mix" : (weakOnly ? "Weak Words Focus" : "Daily Smart Mix"))
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
            setupSession()
        }
        .onDisappear {
            SpeechService.shared.stop()
        }
    }

    // MARK: - Active Step UI

    private func activeStepView(_ step: MixStep) -> some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                // Progress Header
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(DS.Surfaces.muted).frame(height: 6)
                            Capsule()
                                .fill(weakOnly ? DS.Colors.danger : DS.Colors.primary)
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
                        HStack(spacing: 6) {
                            if step.isRetry {
                                DSBadge(text: "Review Again", color: DS.Colors.warning)
                            }
                            DSBadge(text: step.kind.rawValue, color: badgeColor(for: step.kind))
                        }
                    }
                }
                .padding(.top, DS.Spacing.sm)

                // Prompt Card
                VStack(spacing: DS.Spacing.md) {
                    HStack {
                        DSMasteryDots(level: step.word.masteryLevel, isWeak: step.word.isWeak)
                        Spacer()
                        Button {
                            SpeechService.shared.speak(step.word.english, language: "en-US")
                        } label: {
                            Image(systemName: "speaker.wave.2.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DS.Colors.primary)
                                .frame(width: 36, height: 36)
                                .background(DS.Colors.primary.opacity(0.10))
                                .clipShape(Circle())
                        }
                    }

                    Spacer(minLength: 8)

                    if step.kind == .listening {
                        VStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "headphones")
                                .font(.system(size: 40))
                                .foregroundStyle(DS.Colors.warning)
                            Text("Listen and type the English word")
                                .font(.dsCallout)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text(step.word.english)
                            .font(.dsDisplay)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.65)
                    }

                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 184)
                .dsCard(padding: DS.Spacing.lg, cornerRadius: DS.Radius.xl)

                // Interaction Area
                switch step.kind {
                case .multipleChoice:
                    mcSection(for: step)
                case .typing, .listening:
                    typingSection(for: step)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.xl)
        }
    }

    // MARK: - Multiple Choice Sub-area

    private func mcSection(for step: MixStep) -> some View {
        VStack(spacing: DS.Spacing.sm + 2) {
            ForEach(mcOptions, id: \.self) { option in
                let isAnswered = mcSelected != nil
                let isSelected = mcSelected == option
                let isCorrect = option == step.word.turkish

                Button {
                    guard mcSelected == nil else { return }
                    submitMC(option, for: step)
                } label: {
                    HStack {
                        Text(option)
                            .font(.dsBody)
                            .fontWeight(isAnswered && (isCorrect || isSelected) ? .semibold : .regular)
                            .foregroundStyle(.primary)
                        Spacer()
                        if isAnswered && isCorrect {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(DS.Colors.success)
                        } else if isAnswered && isSelected && !isCorrect {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(DS.Colors.danger)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(
                        isAnswered
                        ? (isCorrect ? DS.Colors.success.opacity(0.10) : (isSelected ? DS.Colors.danger.opacity(0.10) : DS.Surfaces.card))
                        : DS.Surfaces.card
                    )
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .strokeBorder(
                                isAnswered
                                ? (isCorrect ? DS.Colors.success : (isSelected ? DS.Colors.danger : DS.Surfaces.border))
                                : DS.Surfaces.border,
                                lineWidth: isAnswered && (isCorrect || isSelected) ? 1.5 : 1
                            )
                    )
                }
                .buttonStyle(DSSpringButtonStyle())
                .disabled(isAnswered)
            }

            if mcSelected != nil && step.word.allTurkishMeanings.count > 1 {
                Text("All meanings: \(step.word.formattedTurkishMeanings)")
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
    }

    // MARK: - Typing & Listening Sub-area

    private func typingSection(for step: MixStep) -> some View {
        VStack(spacing: DS.Spacing.md) {
            HStack {
                TextField(
                    step.kind == .listening ? "Type the English word..." : "Type a Turkish meaning...",
                    text: $typedAnswer
                )
                .font(.dsHeadline)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($isInputFocused)
                .disabled(isLocked)
                .onSubmit { submitTyped(for: step) }

                if !typedAnswer.isEmpty && !isLocked {
                    Button { typedAnswer = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
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

            if let feedbackText {
                Text(feedbackText)
                    .font(.dsCallout)
                    .fontWeight(.semibold)
                    .foregroundStyle(feedbackIsCorrect ? DS.Colors.success : DS.Colors.danger)
                    .multilineTextAlignment(.center)
            }

            if revealedAnswer {
                DSPrimaryButton(title: "Continue", color: DS.Colors.primary) {
                    advanceStep()
                }
            } else {
                DSPrimaryButton(
                    title: "Check Answer",
                    isDisabled: typedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLocked
                ) {
                    submitTyped(for: step)
                }

                DSSecondaryButton(title: "Show Answer", tint: DS.Colors.warning) {
                    revealAnswer(for: step)
                }
                .disabled(isLocked)
            }
        }
    }

    // MARK: - Completion View

    private var completionView: some View {
        let accuracy = initialCount > 0 ? Double(firstTryCorrect) / Double(initialCount) : 0
        return VStack(spacing: DS.Spacing.lg) {
            Spacer()

            VStack(spacing: DS.Spacing.md) {
                DSIconBadge(systemImage: "sparkles", color: DS.Colors.success, size: 64)

                Text(weakOnly ? "Weak Words Sharpened!" : "Daily Session Complete!")
                    .font(.dsTitle)

                Text("\(firstTryCorrect) / \(initialCount)")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(DS.Colors.primary)

                Text("\(Int(accuracy * 100))% first-try accuracy • SRS updated")
                    .font(.dsCallout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .dsCard(padding: DS.Spacing.xl, cornerRadius: DS.Radius.xl)
            .padding(.horizontal, DS.Spacing.md)

            Spacer()

            VStack(spacing: DS.Spacing.sm) {
                DSPrimaryButton(title: "Another Round", systemImage: "arrow.clockwise") {
                    setupSession()
                }
                DSSecondaryButton(title: customConfig != nil ? "Done" : "Back to Today") {
                    dismiss()
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.bottom, DS.Spacing.lg)
        }
    }

    // MARK: - Session Orchestration

    private var progressFraction: Double {
        guard !queue.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(queue.count)
    }

    private func badgeColor(for kind: StepKind) -> Color {
        switch kind {
        case .multipleChoice: return DS.Colors.primary
        case .typing: return DS.Colors.accent
        case .listening: return DS.Colors.warning
        }
    }

    private func setupSession() {
        let selectedWords: [Word]
        if let customConfig {
            selectedWords = PracticePoolResolver.resolveWords(from: allWords, config: customConfig)
        } else if weakOnly {
            selectedWords = Array(allWords.filter { $0.isWeak }.shuffled().prefix(targetCount))
        } else {
            selectedWords = LearningEngine.selectSmartMixWords(from: allWords, count: targetCount)
        }

        // Dynamic blend: ~45% Multiple Choice (warm-up & speed), ~35% Typing, ~20% Listening
        queue = selectedWords.enumerated().map { idx, word in
            let kind: StepKind
            if allWords.count < 4 {
                kind = (idx % 3 == 2) ? .listening : .typing
            } else {
                switch idx % 5 {
                case 0, 1: kind = .multipleChoice
                case 2, 3: kind = .typing
                default:   kind = .listening
                }
            }
            return MixStep(word: word, kind: kind, isRetry: false)
        }

        initialCount = queue.count
        currentIndex = 0
        firstTryCorrect = 0
        isFinished = false
        prepareCurrentStep()
    }

    private func prepareCurrentStep() {
        mcSelected = nil
        typedAnswer = ""
        feedbackText = nil
        feedbackIsCorrect = false
        revealedAnswer = false
        isLocked = false

        guard let step = currentStep else { return }

        if step.kind == .multipleChoice {
            let target = step.word.turkish
            let distractors = allWords
                .filter { $0.persistentModelID != step.word.persistentModelID }
                .map(\.turkish)
                .filter { $0.caseInsensitiveCompare(target) != .orderedSame && !$0.isEmpty }
                .shuffled()
            var opts = [target]
            for d in distractors where opts.count < 4 {
                if !opts.contains(where: { $0.caseInsensitiveCompare(d) == .orderedSame }) {
                    opts.append(d)
                }
            }
            mcOptions = opts.shuffled()
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isInputFocused = true
            }
        }

        if step.kind == .listening || isSoundEnabled {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                SpeechService.shared.speak(step.word.english, language: "en-US")
            }
        }
    }

    private func submitMC(_ option: String, for step: MixStep) {
        mcSelected = option
        let isCorrect = option == step.word.turkish

        if isCorrect {
            Haptics.success()
            if !step.isRetry { firstTryCorrect += 1 }
            LearningEngine.recordCorrect(for: step.word)
        } else {
            Haptics.error()
            LearningEngine.recordWrong(for: step.word)
            queue.append(MixStep(word: step.word, kind: .multipleChoice, isRetry: true))
        }
        try? modelContext.save()

        DispatchQueue.main.asyncAfter(deadline: .now() + (isCorrect ? 0.85 : 1.45)) {
            advanceStep()
        }
    }

    private func submitTyped(for step: MixStep) {
        guard !isLocked else { return }
        let validAnswers = step.kind == .listening ? step.word.allEnglishForms : step.word.allTurkishMeanings
        let result = LearningEngine.evaluateAnswer(typedAnswer, against: validAnswers)

        if result.isCorrect {
            isLocked = true
            feedbackIsCorrect = true
            Haptics.success()
            if !step.isRetry { firstTryCorrect += 1 }
            LearningEngine.recordCorrect(for: step.word)
            try? modelContext.save()

            let others = step.word.allTurkishMeanings.filter { $0.caseInsensitiveCompare(result.matchedAnswer ?? "") != .orderedSame }
            if step.kind == .listening {
                feedbackText = "Correct! Meaning: \(step.word.formattedTurkishMeanings)"
            } else if !others.isEmpty {
                feedbackText = "Correct! Also: \(others.joined(separator: " • "))"
            } else if result.wasTypoTolerated, let matched = result.matchedAnswer {
                feedbackText = "Correct! (Spell: \(matched))"
            } else {
                feedbackText = "Correct!"
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
                advanceStep()
            }
        } else {
            Haptics.error()
            feedbackIsCorrect = false
            feedbackText = "Not quite — try again or tap Show Answer."
            LearningEngine.recordWrong(for: step.word)
            queue.append(MixStep(word: step.word, kind: step.kind, isRetry: true))
            try? modelContext.save()
        }
    }

    private func revealAnswer(for step: MixStep) {
        isLocked = true
        revealedAnswer = true
        feedbackIsCorrect = false
        Haptics.error()
        LearningEngine.recordWrong(for: step.word)
        queue.append(MixStep(word: step.word, kind: step.kind, isRetry: true))
        try? modelContext.save()

        if step.kind == .listening {
            feedbackText = "\(step.word.english) — \(step.word.formattedTurkishMeanings)"
        } else {
            feedbackText = "Answer: \(step.word.formattedTurkishMeanings)"
        }
    }

    private func advanceStep() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if currentIndex + 1 < queue.count {
                currentIndex += 1
                prepareCurrentStep()
            } else {
                SessionRecorder.record(count: initialCount, category: .smartMix, in: modelContext)
                Haptics.success()
                isFinished = true
            }
        }
    }
}
