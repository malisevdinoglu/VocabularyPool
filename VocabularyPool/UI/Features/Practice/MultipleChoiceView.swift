//
//  MultipleChoiceView.swift
//  VocabularyPool
//
//  Fast 4-option Multiple Choice practice with multi-meaning display, SRS LearningEngine,
//  and in-session re-queue for missed words.
//

import SwiftUI
import SwiftData

struct MultipleChoiceView: View {
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
    @State private var options: [String] = []
    @State private var correctOption: String = ""
    @State private var selectedOption: String? = nil

    @State private var initialCount: Int = 0
    @State private var firstTryCorrect: Int = 0
    @State private var isFinished: Bool = false

    private var currentItem: QuestionItem? {
        guard currentIndex < queue.count else { return nil }
        return queue[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            if queue.isEmpty {
                ContentUnavailableView("No Words Available", systemImage: "text.book.closed")
            } else if isFinished {
                completionView
            } else if let item = currentItem {
                sessionBody(for: item)
            }
        }
        .background(DS.Surfaces.canvas.ignoresSafeArea())
        .navigationTitle("Multiple Choice")
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

    // MARK: - Active Question View

    private func sessionBody(for item: QuestionItem) -> some View {
        VStack(spacing: DS.Spacing.lg) {
            // Progress Bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(DS.Surfaces.muted).frame(height: 6)
                        Capsule()
                            .fill(DS.Colors.primary)
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
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.sm)

            // Editorial Prompt Card
            VStack(spacing: DS.Spacing.md) {
                HStack {
                    DSBadge(text: config.direction.rawValue, color: DS.Colors.primary)
                    Spacer()
                    Button {
                        speak(item.word)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DS.Colors.primary)
                            .frame(width: 34, height: 34)
                            .background(DS.Colors.primary.opacity(0.10))
                            .clipShape(Circle())
                    }
                }

                Spacer(minLength: 12)

                Text(config.direction == .enToTr ? item.word.english : item.word.formattedTurkishMeanings)
                    .font(.dsDisplay)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.65)
                    .lineLimit(3)

                Spacer(minLength: 12)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 190)
            .dsCard(padding: DS.Spacing.lg, cornerRadius: DS.Radius.xl)
            .padding(.horizontal, DS.Spacing.md)

            // 4 Option Cards
            VStack(spacing: DS.Spacing.sm + 2) {
                ForEach(options, id: \.self) { option in
                    optionButton(option, for: item)
                }
            }
            .padding(.horizontal, DS.Spacing.md)

            // Multi-meaning reinforcement banner after answering
            if selectedOption != nil && item.word.allTurkishMeanings.count > 1 && config.direction == .enToTr {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(DS.Colors.primary)
                        .font(.system(size: 13))
                    Text("All meanings: \(item.word.formattedTurkishMeanings)")
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.md)
                .transition(.opacity)
            }

            Spacer()
        }
    }

    private func optionButton(_ option: String, for item: QuestionItem) -> some View {
        let isAnswered = selectedOption != nil
        let isSelected = selectedOption == option
        let isCorrect = option == correctOption

        let borderColor: Color = {
            guard isAnswered else { return DS.Surfaces.border }
            if isCorrect { return DS.Colors.success }
            if isSelected { return DS.Colors.danger }
            return DS.Surfaces.border
        }()

        let bgColor: Color = {
            guard isAnswered else { return DS.Surfaces.card }
            if isCorrect { return DS.Colors.success.opacity(0.10) }
            if isSelected { return DS.Colors.danger.opacity(0.10) }
            return DS.Surfaces.card
        }()

        return Button {
            guard selectedOption == nil else { return }
            handleSelection(option, for: item)
        } label: {
            HStack {
                Text(option)
                    .font(.dsBody)
                    .fontWeight(isAnswered && (isCorrect || isSelected) ? .semibold : .regular)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer()

                if isAnswered && isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.Colors.success)
                } else if isAnswered && isSelected && !isCorrect {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(DS.Colors.danger)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isAnswered && (isCorrect || isSelected) ? 1.5 : 1)
            )
        }
        .buttonStyle(DSSpringButtonStyle())
        .disabled(isAnswered)
    }

    // MARK: - Completion View

    private var completionView: some View {
        let accuracy = initialCount > 0 ? Double(firstTryCorrect) / Double(initialCount) : 0
        return VStack(spacing: DS.Spacing.lg) {
            Spacer()

            VStack(spacing: DS.Spacing.md) {
                DSIconBadge(
                    systemImage: accuracy >= 0.8 ? "checkmark.seal.fill" : "flag.checkered",
                    color: accuracy >= 0.8 ? DS.Colors.success : DS.Colors.primary,
                    size: 64
                )

                Text("Session Complete")
                    .font(.dsTitle)

                Text("\(firstTryCorrect) / \(initialCount)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
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
                    setupSession()
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

    private func setupSession() {
        let resolved = PracticePoolResolver.resolveWords(from: allWords, config: config)
        queue = resolved.map { QuestionItem(word: $0, isRetry: false) }
        initialCount = queue.count
        currentIndex = 0
        firstTryCorrect = 0
        selectedOption = nil
        isFinished = false
        prepareCurrentOptions()
    }

    private func prepareCurrentOptions() {
        guard let item = currentItem else { return }
        let target = config.direction == .enToTr ? item.word.turkish : item.word.english
        correctOption = target

        let distractors = allWords
            .filter { $0.persistentModelID != item.word.persistentModelID }
            .map { config.direction == .enToTr ? $0.turkish : $0.english }
            .filter { $0.caseInsensitiveCompare(target) != .orderedSame && !$0.isEmpty }
            .shuffled()

        var uniqueOptions = [target]
        for d in distractors where uniqueOptions.count < 4 {
            if !uniqueOptions.contains(where: { $0.caseInsensitiveCompare(d) == .orderedSame }) {
                uniqueOptions.append(d)
            }
        }
        options = uniqueOptions.shuffled()

        if isSoundEnabled {
            speak(item.word)
        }
    }

    private func handleSelection(_ option: String, for item: QuestionItem) {
        selectedOption = option
        let isCorrect = option == correctOption

        if isCorrect {
            Haptics.success()
            if !item.isRetry { firstTryCorrect += 1 }
            LearningEngine.recordCorrect(for: item.word)
        } else {
            Haptics.error()
            LearningEngine.recordWrong(for: item.word)
            // In-session re-queue: bring missed word back at the end of the session
            queue.append(QuestionItem(word: item.word, isRetry: true))
        }

        try? modelContext.save()

        let delay: Double = isCorrect ? 0.85 : 1.45
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeInOut(duration: 0.2)) {
                if currentIndex + 1 < queue.count {
                    currentIndex += 1
                    selectedOption = nil
                    prepareCurrentOptions()
                } else {
                    SessionRecorder.record(count: initialCount, category: .multipleChoice, in: modelContext)
                    isFinished = true
                }
            }
        }
    }

    private func speak(_ word: Word) {
        if config.direction == .enToTr {
            SpeechService.shared.speak(word.english, language: "en-US")
        } else {
            SpeechService.shared.speak(word.turkish, language: "tr-TR")
        }
    }
}
