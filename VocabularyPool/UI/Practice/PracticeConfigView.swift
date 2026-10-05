//
//  PracticeConfigView.swift
//  VocabularyPool
//
//  Created by Assistant on 02.01.2026.
//

import SwiftUI
import SwiftData

struct QuizConfig {
    var count: Int
    var type: PracticeConfigView.PracticeType
    var wordRangeStart: Int?
    var wordRangeEnd: Int?
    var reviewMode: Bool = false
    var weakWordsMode: Bool = false
}

struct PracticeConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var words: [Word]
    @Query(filter: #Predicate<Word> { $0.needsReview == true }) private var reviewWords: [Word]

    @State private var selectedModeForSheet: PracticeType? = nil
    @State private var activeQuizConfig: QuizConfig? = nil
    @State private var showingQuiz = false
    @State private var showingSettings = false

    enum PracticeType: String, CaseIterable, Identifiable {
        case englishToTurkish = "İngilizce → Türkçe"
        case turkishToEnglish = "Türkçe → İngilizce"
        case listening = "Yazarak Dinle"
        case audioListening = "Otomatik Sesli Dinleme"
        case matching = "Eşleştirme"
        case flashcards = "Kartlar"

        var id: String { self.rawValue }

        var shortTitle: String {
            switch self {
            case .englishToTurkish: return "EN → TR"
            case .turkishToEnglish: return "TR → EN"
            case .listening: return "Yazarak Dinle"
            case .audioListening: return "Oto Dinle"
            case .matching: return "Eşleştir"
            case .flashcards: return "Kartlar"
            }
        }

        var description: String {
            switch self {
            case .englishToTurkish: return "İngilizce kelimenin Türkçe karşılığını yazın"
            case .turkishToEnglish: return "Türkçe kelimenin İngilizce karşılığını yazın"
            case .listening: return "Duyduğunuz İngilizce kelimeyi yazarak test edin"
            case .audioListening: return "Kelimeleri ve Türkçe karşılıklarını sırayla otomatik dinleyin"
            case .matching: return "5 kelimeyi Türkçe karşılıklarıyla eşleştirin"
            case .flashcards: return "3D çevirmeli & kaydırmalı akıllı kartlar"
            }
        }

        var icon: String {
            switch self {
            case .englishToTurkish: return "text.book.closed.fill"
            case .turkishToEnglish: return "globe"
            case .listening: return "headphones"
            case .audioListening: return "headphones.circle.fill"
            case .matching: return "rectangle.2.swap"
            case .flashcards: return "rectangle.stack.fill"
            }
        }

        var color: Color {
            switch self {
            case .englishToTurkish: return DS.Colors.primary
            case .turkishToEnglish: return DS.Colors.accent
            case .listening: return DS.Colors.warning
            case .audioListening: return Color.orange
            case .matching: return DS.Colors.purple
            case .flashcards: return DS.Colors.total
            }
        }
    }

    var totalWords: Int {
        words.count
    }

    var weakWords: [Word] {
        words.filter { word in
            let total = word.correctCount + word.wrongCount
            if word.wrongCount > 0 { return true }
            if total > 0 {
                let rate = Double(word.correctCount) / Double(total)
                return rate <= 0.70
            }
            return false
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    
                    // MARK: Header Title & Description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Pratik Modu Seçin")
                            .font(.dsTitle)
                            .foregroundStyle(.primary)
                        Text("Çalışmak istediğiniz alıştırma türüne dokunarak başlayın")
                            .font(.dsCaption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)

                    // MARK: 6 Practice Mode Cards Grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.sm), GridItem(.flexible(), spacing: DS.Spacing.sm)], spacing: DS.Spacing.sm) {
                        ForEach(PracticeType.allCases) { mode in
                            SelectableModeCard(
                                mode: mode,
                                isSelected: false
                            ) {
                                selectedModeForSheet = mode
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.md)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Pratik Yap")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(item: $selectedModeForSheet) { mode in
                PracticeConfigSheetView(
                    mode: mode,
                    totalWordsCount: totalWords,
                    reviewWordsCount: reviewWords.count,
                    weakWordsCount: weakWords.count
                ) { config in
                    activeQuizConfig = config
                    showingQuiz = true
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .navigationDestination(isPresented: $showingQuiz) {
                if let config = activeQuizConfig {
                    switch config.type {
                    case .matching:
                        MatchingView(config: config)
                    case .flashcards:
                        FlashcardView(config: config)
                    case .audioListening:
                        AudioListeningView(config: config)
                    default:
                        QuizView(config: config)
                    }
                }
            }
        }
    }
}

// MARK: - 🎛️ Practice Config Bottom Sheet
struct PracticeConfigSheetView: View {
    let mode: PracticeConfigView.PracticeType
    let totalWordsCount: Int
    let reviewWordsCount: Int
    let weakWordsCount: Int
    let onStart: (QuizConfig) -> Void

    @Environment(\.dismiss) private var dismiss

    enum WordSource: String, CaseIterable, Identifiable {
        case all = "Tüm Havuz"
        case review = "Hatalı Kelimeler"
        case weak = "Zayıf Kelimeler"
        case range = "Özel Kelime Aralığı"

        var id: String { rawValue }
    }

    @AppStorage("lastSelectedWordSource") private var savedSourceRaw: String = WordSource.all.rawValue
    @AppStorage("lastQuestionCount") private var savedCount: Int = 10

    @State private var selectedSource: WordSource = .all
    @State private var questionCount: Int = 10
    @State private var fromText: String = ""
    @State private var toText: String = ""

    var wordRangeStart: Int? {
        guard selectedSource == .range, let from = Int(fromText), from > 0 else { return nil }
        return from
    }

    var wordRangeEnd: Int? {
        guard selectedSource == .range, let to = Int(toText), to > 0 else { return nil }
        return to
    }

    var isRangeValid: Bool {
        if selectedSource != .range { return true }
        guard let from = wordRangeStart, let to = wordRangeEnd else { return false }
        return from <= to && from <= totalWordsCount && to <= totalWordsCount
    }

    var body: some View {
        VStack(spacing: DS.Spacing.md) {

            // Header Title Bar
            HStack(spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(mode.color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: mode.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(mode.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(mode.rawValue) Ayarları")
                        .font(.dsHeadline)
                        .foregroundStyle(.primary)
                    Text(mode.description)
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)

            Divider()

            ScrollView {
                VStack(spacing: DS.Spacing.lg) {

                    // MARK: Section 1: Kelime Kaynağı
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        SectionHeaderView(title: "Kelime Kaynağı Seçin", systemImage: "tray.full.fill", color: mode.color)

                        VStack(spacing: DS.Spacing.xs) {
                            ForEach(WordSource.allCases) { source in
                                let countBadge: Int? = {
                                    switch source {
                                    case .all: return totalWordsCount
                                    case .review: return reviewWordsCount
                                    case .weak: return weakWordsCount
                                    case .range: return nil
                                    }
                                }()

                                let isDisabled: Bool = {
                                    switch source {
                                    case .review: return reviewWordsCount == 0
                                    case .weak: return weakWordsCount == 0
                                    default: return false
                                    }
                                }()

                                Button {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        selectedSource = source
                                    }
                                } label: {
                                    HStack {
                                        Text(source.rawValue)
                                            .font(.dsBody)
                                            .fontWeight(selectedSource == source ? .semibold : .regular)
                                            .foregroundStyle(isDisabled ? .secondary : (selectedSource == source ? mode.color : .primary))

                                        Spacer()

                                        if let badge = countBadge {
                                            Text("\(badge) Kelime")
                                                .font(.dsCaption)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 3)
                                                .background(selectedSource == source ? mode.color.opacity(0.15) : Color(uiColor: .tertiarySystemFill))
                                                .foregroundStyle(selectedSource == source ? mode.color : .secondary)
                                                .clipShape(Capsule())
                                        }

                                        Image(systemName: selectedSource == source ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 18))
                                            .foregroundStyle(selectedSource == source ? mode.color : Color.secondary.opacity(0.3))
                                    }
                                    .padding(DS.Spacing.md)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.md)
                                            .stroke(selectedSource == source ? mode.color : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isDisabled)
                            }
                        }

                        // Range Inputs
                        if selectedSource == .range {
                            VStack(spacing: DS.Spacing.sm) {
                                HStack(spacing: DS.Spacing.md) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Başlangıç (Sıra)")
                                            .font(.dsCaption)
                                            .foregroundStyle(.secondary)
                                        TextField("1", text: $fromText)
                                            .keyboardType(.numberPad)
                                            .padding(DS.Spacing.sm)
                                            .background(Color(uiColor: .tertiarySystemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: DS.Radius.sm)
                                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                            )
                                            .onChange(of: fromText) { _, val in fromText = val.filter { $0.isNumber } }
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Bitiş (Sıra)")
                                            .font(.dsCaption)
                                            .foregroundStyle(.secondary)
                                        TextField("\(totalWordsCount)", text: $toText)
                                            .keyboardType(.numberPad)
                                            .padding(DS.Spacing.sm)
                                            .background(Color(uiColor: .tertiarySystemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: DS.Radius.sm)
                                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                            )
                                            .onChange(of: toText) { _, val in toText = val.filter { $0.isNumber } }
                                    }
                                }

                                if !isRangeValid {
                                    Text("Geçersiz aralık. Başlangıç ≤ Bitiş ve her ikisi de ≤ \(totalWordsCount) olmalıdır.")
                                        .font(.dsCaption)
                                        .foregroundStyle(DS.Colors.danger)
                                }
                            }
                            .padding(.top, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    // MARK: Section 2: Soru / Kelime Sayısı
                    if mode != .matching {
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            SectionHeaderView(title: "Soru / Kelime Sayısı", systemImage: "number", color: mode.color)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm), count: 3), spacing: DS.Spacing.sm) {
                                ForEach([5, 10, 15, 20, 25, 30], id: \.self) { n in
                                    NumberChipButton(
                                        number: n,
                                        isSelected: questionCount == n
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            questionCount = n
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
            }

            // MARK: Start Button
            VStack(spacing: 0) {
                Divider()
                DSPrimaryButton(
                    title: mode == .matching
                        ? "🚀 Alıştırmayı Başlat (5 Çift Eşleştirme)"
                        : "🚀 Alıştırmayı Başlat (\(questionCount) Kelime)",
                    isDisabled: totalWordsCount == 0 || !isRangeValid
                ) {
                    // Save smart defaults
                    savedSourceRaw = selectedSource.rawValue
                    savedCount = questionCount

                    let config = QuizConfig(
                        count: mode == .matching ? 5 : questionCount,
                        type: mode,
                        wordRangeStart: wordRangeStart,
                        wordRangeEnd: wordRangeEnd,
                        reviewMode: selectedSource == .review,
                        weakWordsMode: selectedSource == .weak
                    )
                    dismiss()
                    onStart(config)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.md)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear {
            if let saved = WordSource(rawValue: savedSourceRaw) {
                if (saved == .review && reviewWordsCount == 0) || (saved == .weak && weakWordsCount == 0) {
                    selectedSource = .all
                } else {
                    selectedSource = saved
                }
            }
            questionCount = savedCount
        }
    }
}

// MARK: - Section Header Component

struct SectionHeaderView: View {
    let title: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
            Text(title)
                .font(.dsHeadline)
                .foregroundStyle(.primary)
        }
        .padding(.leading, 4)
    }
}

// MARK: - Mode Selection Card Component

struct SelectableModeCard: View {
    let mode: PracticeConfigView.PracticeType
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(mode.color.opacity(0.12))
                        .frame(width: 48, height: 48)

                    Image(systemName: mode.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(mode.color)
                }

                Text(mode.shortTitle)
                    .font(.dsHeadline)
                    .foregroundStyle(.primary)

                Text(mode.rawValue)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
            .padding(.horizontal, DS.Spacing.xs)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Number Chip Button Component

struct NumberChipButton: View {
    let number: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("\(number)")
                .font(.dsHeadline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.sm + 2)
                .background(isSelected ? DS.Colors.primary : Color(uiColor: .secondarySystemGroupedBackground))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(isSelected ? DS.Colors.primary : Color.secondary.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        PracticeConfigView()
            .modelContainer(for: Word.self, inMemory: true)
    }
}
