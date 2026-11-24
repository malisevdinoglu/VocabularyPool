//
//  PracticeView.swift
//  VocabularyPool
//
//  Clean 2-step Practice hub: Source Filter (top) + 5 Focused Modes (below).
//  Custom Range works seamlessly across all 5 practice modes.
//

import SwiftUI
import SwiftData

// MARK: - Practice Configuration Models

enum PracticeSource: String, CaseIterable, Identifiable {
    case all = "All"
    case weak = "Weak"
    case customRange = "Range"
    case irregularVerbs = "Verbs"
    case phrasal = "Phrasal"

    var id: String { rawValue }

    var accentColor: Color {
        switch self {
        case .all: return DS.Colors.primary
        case .weak: return DS.Colors.danger
        case .customRange: return DS.Colors.warning
        case .irregularVerbs: return DS.Colors.accent
        case .phrasal: return DS.Colors.purple
        }
    }
}

enum PracticeMode: String, CaseIterable, Identifiable {
    case smartMix = "Smart Mix"
    case multipleChoice = "Multiple Choice"
    case typing = "Typing Quiz"
    case flashcards = "Flashcards"
    case listening = "Listening"
    case matching = "Matching"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .smartMix: return "Blends Multiple Choice, Typing & Listening"
        case .multipleChoice: return "Fast 4-option recall to build speed"
        case .typing: return "Type meanings with typo tolerance"
        case .flashcards: return "3D flip & swipe active review"
        case .listening: return "Type what you hear or auto audio play"
        case .matching: return "Match 5 word pairs side by side"
        }
    }

    var icon: String {
        switch self {
        case .smartMix: return "sparkles"
        case .multipleChoice: return "checklist"
        case .typing: return "keyboard"
        case .flashcards: return "rectangle.stack.fill"
        case .listening: return "headphones"
        case .matching: return "rectangle.2.swap"
        }
    }

    var color: Color {
        switch self {
        case .smartMix: return DS.Colors.primary
        case .multipleChoice: return DS.Colors.primary
        case .typing: return DS.Colors.accent
        case .flashcards: return DS.Colors.purple
        case .listening: return DS.Colors.warning
        case .matching: return DS.Colors.primary
        }
    }
}

enum QuizDirection: String, CaseIterable, Identifiable {
    case enToTr = "EN → TR"
    case trToEn = "TR → EN"
    var id: String { rawValue }
}

enum ListeningStyle: String, CaseIterable, Identifiable {
    case typeWhatYouHear = "Type Answer"
    case autoAudioPlay = "Auto Audio"
    var id: String { rawValue }
}

struct PracticeSessionConfig: Hashable {
    var mode: PracticeMode
    var source: PracticeSource
    var count: Int
    var direction: QuizDirection = .enToTr
    var listeningStyle: ListeningStyle = .typeWhatYouHear
    var rangeStart: Int? = nil
    var rangeEnd: Int? = nil
}

// MARK: - Single Source of Truth Pool Resolver

enum PracticePoolResolver {

    static func filteredBasePool(from allWords: [Word], source: PracticeSource) -> [Word] {
        switch source {
        case .all, .customRange:
            return allWords
        case .weak:
            return allWords.filter { $0.isWeak }
        case .phrasal:
            return allWords.filter { $0.isPhrasalVerb }
        case .irregularVerbs:
            return allWords.filter { $0.hasConjugations }
        }
    }

    static func resolveWords(from allWords: [Word], config: PracticeSessionConfig) -> [Word] {
        let base = filteredBasePool(from: allWords, source: config.source)
        guard !base.isEmpty else { return [] }

        let pool: [Word]
        if config.source == .customRange,
           let start = config.rangeStart,
           let end = config.rangeEnd {
            let chronological = base.sorted { $0.timestamp < $1.timestamp }
            let startIdx = max(0, start - 1)
            let endIdx = min(chronological.count - 1, end - 1)
            if startIdx <= endIdx && startIdx < chronological.count {
                pool = Array(chronological[startIdx...endIdx])
            } else {
                pool = chronological
            }
        } else {
            pool = base
        }

        guard !pool.isEmpty else { return [] }

        let targetCount = config.mode == .matching ? min(5, pool.count) : config.count
        if pool.count >= targetCount {
            return Array(pool.shuffled().prefix(targetCount))
        }

        // For matching or flashcards, don't duplicate within a small pool
        if config.mode == .matching || config.mode == .flashcards {
            return pool.shuffled()
        }

        var selected: [Word] = []
        while selected.count < targetCount {
            let needed = targetCount - selected.count
            selected.append(contentsOf: pool.shuffled().prefix(needed))
        }
        return selected
    }
}

// MARK: - PracticeView

struct PracticeView: View {
    @Query private var words: [Word]

    let onTapAddWord: () -> Void

    @State private var selectedSource: PracticeSource = .all
    @State private var rangeFromText: String = "1"
    @State private var rangeToText: String = ""

    @State private var modeForConfigSheet: PracticeMode? = nil
    @State private var activeConfig: PracticeSessionConfig? = nil
    @State private var showingSession = false
    @State private var showingVerbDeck = false

    private var availablePoolCount: Int {
        if selectedSource == .customRange {
            guard isRangeValid, let start = parsedStart, let end = parsedEnd else { return 0 }
            return max(0, end - start + 1)
        }
        return PracticePoolResolver.filteredBasePool(from: words, source: selectedSource).count
    }

    private var parsedStart: Int? {
        guard let v = Int(rangeFromText), v > 0 else { return nil }
        return v
    }

    private var parsedEnd: Int? {
        guard let v = Int(rangeToText), v > 0 else { return nil }
        return v
    }

    private var isRangeValid: Bool {
        if selectedSource != .customRange { return true }
        guard let s = parsedStart, let e = parsedEnd, !words.isEmpty else { return false }
        return s <= e && s <= words.count && e <= words.count
    }

    private func badgeCount(for source: PracticeSource) -> Int? {
        switch source {
        case .all: return words.count
        case .weak: return words.filter { $0.isWeak }.count
        case .phrasal: return words.filter { $0.isPhrasalVerb }.count
        case .irregularVerbs: return words.filter { $0.hasConjugations }.count
        case .customRange: return nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                // MARK: - Step 1: Word Source Filter
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    DSSectionHeader(title: "1. Word Source", trailingText: "\(availablePoolCount) available")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DS.Spacing.sm) {
                            ForEach(PracticeSource.allCases) { source in
                                DSChip(
                                    label: source.rawValue,
                                    count: badgeCount(for: source),
                                    isSelected: selectedSource == source,
                                    accentColor: source.accentColor
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedSource = source
                                        if source == .customRange && rangeToText.isEmpty && !words.isEmpty {
                                            rangeToText = "\(min(50, words.count))"
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Inline Custom Range Selector (applies to ALL 5 modes)
                    if selectedSource == .customRange {
                        customRangeCard
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                // MARK: - Irregular Verb Deck Shortcut (when Verbs source selected)
                if selectedSource == .irregularVerbs {
                    Button {
                        Haptics.light()
                        showingVerbDeck = true
                    } label: {
                        HStack(spacing: DS.Spacing.md) {
                            DSIconBadge(systemImage: "repeat", color: DS.Colors.accent, size: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("V1 → V2 → V3 Conjugation Deck")
                                    .font(.dsHeadline)
                                    .foregroundStyle(.primary)
                                Text("Quick-review irregular verb forms")
                                    .font(.dsCaption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .dsCard()
                    }
                    .buttonStyle(DSSpringButtonStyle())
                    .disabled(availablePoolCount == 0)
                }

                // MARK: - Step 2: Practice Modes
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    DSSectionHeader(title: "2. Choose Mode")

                    if words.isEmpty {
                        VStack(spacing: DS.Spacing.md) {
                            Image(systemName: "text.book.closed")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text("Add words to start practicing")
                                .font(.dsHeadline)
                            DSPrimaryButton(title: "Add First Word", systemImage: "plus") {
                                onTapAddWord()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .dsCard(padding: DS.Spacing.lg)
                    } else {
                        VStack(spacing: DS.Spacing.sm + 2) {
                            ForEach(PracticeMode.allCases) { mode in
                                PracticeModeRow(
                                    mode: mode,
                                    isDisabled: availablePoolCount == 0 || !isRangeValid
                                ) {
                                    Haptics.light()
                                    modeForConfigSheet = mode
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
        .background(DS.Surfaces.canvas.ignoresSafeArea())
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Haptics.light()
                    onTapAddWord()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DS.Colors.primary)
                        .frame(width: 34, height: 34)
                        .background(DS.Colors.primary.opacity(0.11))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Add Word")
            }
        }
        .sheet(item: $modeForConfigSheet) { mode in
            PracticeConfigSheet(
                mode: mode,
                source: selectedSource,
                availableCount: availablePoolCount,
                rangeStart: parsedStart,
                rangeEnd: parsedEnd
            ) { config in
                activeConfig = config
                showingSession = true
            }
        }
        .navigationDestination(isPresented: $showingSession) {
            if let config = activeConfig {
                switch config.mode {
                case .smartMix:
                    SmartMixSessionView(config: config)
                case .multipleChoice:
                    MultipleChoiceView(config: config)
                case .typing:
                    QuizView(config: config)
                case .flashcards:
                    FlashcardView(config: config)
                case .listening:
                    if config.listeningStyle == .autoAudioPlay {
                        AudioListeningView(config: config)
                    } else {
                        QuizView(config: config)
                    }
                case .matching:
                    MatchingView(config: config)
                }
            }
        }
        .navigationDestination(isPresented: $showingVerbDeck) {
            VerbConjugationView()
        }
    }

    // MARK: - Inline Custom Range Card

    private var customRangeCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                    TextField("1", text: $rangeFromText)
                        .keyboardType(.numberPad)
                        .font(.dsHeadline)
                        .padding(10)
                        .background(DS.Surfaces.muted)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                        .onChange(of: rangeFromText) { _, val in rangeFromText = val.filter(\.isNumber) }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("To")
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
                        TextField("\(words.count)", text: $rangeToText)
                            .keyboardType(.numberPad)
                            .font(.dsHeadline)
                            .onChange(of: rangeToText) { _, val in rangeToText = val.filter(\.isNumber) }

                        if !words.isEmpty {
                            Button {
                                Haptics.selection()
                                rangeToText = "\(words.count)"
                            } label: {
                                Text("Max")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(DS.Colors.warning)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(DS.Colors.warning.opacity(0.14))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(DSSpringButtonStyle())
                            .accessibilityLabel("Set maximum \(words.count)")
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(DS.Surfaces.muted)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                }
            }

            if !isRangeValid {
                Text("Enter a valid range between 1 and \(words.count).")
                    .font(.dsCaption)
                    .foregroundStyle(DS.Colors.danger)
            }
        }
        .dsCard()
    }
}

// MARK: - Mode Row Component

struct PracticeModeRow: View {
    let mode: PracticeMode
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                DSIconBadge(systemImage: mode.icon, color: mode.color, size: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text(mode.rawValue)
                        .font(.dsHeadline)
                        .foregroundStyle(isDisabled ? .secondary : .primary)
                    Text(mode.subtitle)
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .dsCard(padding: 14, cornerRadius: DS.Radius.md)
            .opacity(isDisabled ? 0.55 : 1.0)
        }
        .buttonStyle(DSSpringButtonStyle())
        .disabled(isDisabled)
    }
}

// MARK: - Compact Practice Config Sheet

struct PracticeConfigSheet: View {
    let mode: PracticeMode
    let source: PracticeSource
    let availableCount: Int
    let rangeStart: Int?
    let rangeEnd: Int?
    let onStart: (PracticeSessionConfig) -> Void

    @Environment(\.dismiss) private var dismiss
    @AppStorage("lastQuestionCount") private var savedCount: Int = 10

    @State private var questionCount: Int = 10
    @State private var direction: QuizDirection = .enToTr
    @State private var listeningStyle: ListeningStyle = .typeWhatYouHear

    private let counts = [5, 10, 15, 20, 25, 30]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                // Mode Header Summary
                HStack(spacing: DS.Spacing.md) {
                    DSIconBadge(systemImage: mode.icon, color: mode.color, size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.rawValue)
                            .font(.dsHeadline)
                        Text("Source: \(source.rawValue) (\(availableCount) words)")
                            .font(.dsCaption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .dsCard()

                // Direction Picker (for Typing & Multiple Choice)
                if mode == .typing || mode == .multipleChoice {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader(title: "Direction")
                        Picker("Direction", selection: $direction) {
                            ForEach(QuizDirection.allCases) { dir in
                                Text(dir.rawValue).tag(dir)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // Listening Style Picker
                if mode == .listening {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader(title: "Listening Style")
                        Picker("Style", selection: $listeningStyle) {
                            ForEach(ListeningStyle.allCases) { style in
                                Text(style.rawValue).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // Question Count Picker (except Matching which is 5 pairs)
                if mode != .matching {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader(title: "Word Count")
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm), count: 3), spacing: DS.Spacing.sm) {
                            ForEach(counts, id: \.self) { n in
                                Button {
                                    Haptics.selection()
                                    questionCount = n
                                } label: {
                                    Text("\(n)")
                                        .font(.dsHeadline)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 44)
                                        .background(questionCount == n ? mode.color : DS.Surfaces.card)
                                        .foregroundStyle(questionCount == n ? DS.Colors.onColor : .primary)
                                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                                .strokeBorder(questionCount == n ? Color.clear : DS.Surfaces.border, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(DSSpringButtonStyle())
                            }
                        }
                    }
                }

                Spacer()

                DSPrimaryButton(
                    title: mode == .matching
                        ? "Start Matching (5 Pairs)"
                        : "Start Practice (\(questionCount) Words)",
                    systemImage: "play.fill",
                    color: mode.color
                ) {
                    savedCount = questionCount
                    let config = PracticeSessionConfig(
                        mode: mode,
                        source: source,
                        count: mode == .matching ? 5 : questionCount,
                        direction: direction,
                        listeningStyle: listeningStyle,
                        rangeStart: rangeStart,
                        rangeEnd: rangeEnd
                    )
                    dismiss()
                    onStart(config)
                }
            }
            .padding(DS.Spacing.md)
            .background(DS.Surfaces.canvas.ignoresSafeArea())
            .navigationTitle("Session Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                questionCount = savedCount
            }
        }
        .presentationDetents([.fraction(0.62), .fraction(0.75)])
        .presentationDragIndicator(.visible)
    }
}
