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

    @State private var count = 10
    @State private var type: PracticeType = .englishToTurkish
    @State private var useWordRange = false
    @State private var fromText = ""
    @State private var toText = ""
    @State private var showingQuiz = false
    @State private var showingReviewQuiz = false
    @State private var showingWeakQuiz = false
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

    var wordRangeStart: Int? {
        guard useWordRange, let from = Int(fromText), from > 0 else { return nil }
        return from
    }

    var wordRangeEnd: Int? {
        guard useWordRange, let to = Int(toText), to > 0 else { return nil }
        return to
    }

    var isRangeValid: Bool {
        if !useWordRange { return true }

        guard let from = wordRangeStart, let to = wordRangeEnd else {
            return false
        }

        return from <= to && from <= totalWords && to <= totalWords
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    
                    // MARK: - 🚀 Hızlı Başlat Bölümü
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        SectionHeaderView(title: "Hızlı Başlat", systemImage: "sparkles", color: DS.Colors.primary)

                        VStack(spacing: DS.Spacing.sm) {
                            // Hataları Pekiştir Card
                            QuickActionCard(
                                title: "Hataları Pekiştir",
                                subtitle: reviewWords.isEmpty ? "Tekrar bekleyen hatalı kelime yok" : "\(reviewWords.count) kelime tekrar bekliyor",
                                badgeCount: reviewWords.count,
                                icon: "arrow.counterclockwise",
                                color: DS.Colors.danger,
                                isDisabled: reviewWords.isEmpty
                            ) {
                                showingReviewQuiz = true
                            }

                            // Zayıf Kelimeleri Güçlendir Card
                            QuickActionCard(
                                title: "Zayıf Kelimeleri Güçlendir",
                                subtitle: weakWords.isEmpty ? "Zayıf performanslı kelime yok" : "\(weakWords.count) kelime ≤%70 başarı oranında",
                                badgeCount: weakWords.count,
                                icon: "chart.bar.fill",
                                color: DS.Colors.warning,
                                isDisabled: weakWords.isEmpty
                            ) {
                                showingWeakQuiz = true
                            }
                        }
                    }

                    // MARK: - 🎯 Pratik Modu Seçimi
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        SectionHeaderView(title: "Pratik Modu Seç", systemImage: "slider.horizontal.3", color: DS.Colors.accent)

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: DS.Spacing.sm), GridItem(.flexible(), spacing: DS.Spacing.sm)], spacing: DS.Spacing.sm) {
                            ForEach(PracticeType.allCases) { mode in
                                SelectableModeCard(
                                    mode: mode,
                                    isSelected: type == mode
                                ) {
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                        type = mode
                                    }
                                }
                            }
                        }
                    }

                    // MARK: - 🔢 Soru Sayısı
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        SectionHeaderView(title: "Soru Sayısı", systemImage: "number", color: DS.Colors.purple)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm), count: 3), spacing: DS.Spacing.sm) {
                            ForEach([5, 10, 15, 20, 25, 30], id: \.self) { n in
                                NumberChipButton(
                                    number: n,
                                    isSelected: count == n
                                ) {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        count = n
                                    }
                                }
                            }
                        }
                    }

                    // MARK: - 📚 Kelime Havuzu & Aralığı
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        SectionHeaderView(title: "Kelime Havuzu", systemImage: "books.vertical.fill", color: DS.Colors.primary)

                        VStack(spacing: DS.Spacing.md) {
                            HStack {
                                Label("Havuzdaki Toplam Kelime", systemImage: "tray.full.fill")
                                    .font(.dsBody)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(totalWords)")
                                    .font(.dsHeadline)
                                    .foregroundStyle(DS.Colors.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(DS.Colors.primary.opacity(0.12))
                                    .clipShape(Capsule())
                            }

                            Divider()

                            Toggle(isOn: $useWordRange.animation(.spring(response: 0.3, dampingFraction: 0.8))) {
                                Label("Belirli Kelime Aralığı Kullan", systemImage: "arrow.left.and.right.text.horizontal")
                                    .font(.dsBody)
                            }
                            .tint(DS.Colors.primary)

                            if useWordRange {
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
                                                .onChange(of: fromText) { _, newValue in
                                                    fromText = newValue.filter { $0.isNumber }
                                                }
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Bitiş (Sıra)")
                                                .font(.dsCaption)
                                                .foregroundStyle(.secondary)
                                            TextField("\(totalWords)", text: $toText)
                                                .keyboardType(.numberPad)
                                                .padding(DS.Spacing.sm)
                                                .background(Color(uiColor: .tertiarySystemBackground))
                                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                                                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                                                )
                                                .onChange(of: toText) { _, newValue in
                                                    toText = newValue.filter { $0.isNumber }
                                                }
                                        }
                                    }

                                    if !isRangeValid {
                                        HStack(spacing: 6) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundStyle(DS.Colors.danger)
                                            Text("Geçersiz aralık. Başlangıç ≤ Bitiş ve her ikisi de ≤ \(totalWords) olmalıdır.")
                                                .font(.dsCaption)
                                                .foregroundStyle(DS.Colors.danger)
                                        }
                                        .padding(.top, 4)
                                    }
                                }
                                .padding(.top, DS.Spacing.xs)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .padding(DS.Spacing.md)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    }

                    Spacer(minLength: DS.Spacing.xl)
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
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    DSPrimaryButton(
                        title: type == .matching ? "Pratiğe Başla (5 Çift Eşleştirme)" : (type == .audioListening ? "Dinlemeyi Başlat (\(count) Kelime)" : "Pratiğe Başla (\(count) Soru)"),
                        isDisabled: words.isEmpty || !isRangeValid
                    ) {
                        showingQuiz = true
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationDestination(isPresented: $showingQuiz) {
                if type == .matching {
                    MatchingView(config: QuizConfig(
                        count: 5,
                        type: .matching,
                        wordRangeStart: wordRangeStart,
                        wordRangeEnd: wordRangeEnd
                    ))
                } else if type == .flashcards {
                    FlashcardView(config: QuizConfig(
                        count: count,
                        type: .flashcards,
                        wordRangeStart: wordRangeStart,
                        wordRangeEnd: wordRangeEnd
                    ))
                } else if type == .audioListening {
                    AudioListeningView(config: QuizConfig(
                        count: count,
                        type: .audioListening,
                        wordRangeStart: wordRangeStart,
                        wordRangeEnd: wordRangeEnd
                    ))
                } else {
                    QuizView(config: QuizConfig(
                        count: count,
                        type: type,
                        wordRangeStart: wordRangeStart,
                        wordRangeEnd: wordRangeEnd
                    ))
                }
            }
            .navigationDestination(isPresented: $showingReviewQuiz) {
                QuizView(config: QuizConfig(
                    count: reviewWords.count,
                    type: .englishToTurkish,
                    wordRangeStart: nil,
                    wordRangeEnd: nil,
                    reviewMode: true
                ))
            }
            .navigationDestination(isPresented: $showingWeakQuiz) {
                QuizView(config: QuizConfig(
                    count: weakWords.count,
                    type: .englishToTurkish,
                    wordRangeStart: nil,
                    wordRangeEnd: nil,
                    reviewMode: false,
                    weakWordsMode: true
                ))
            }
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

// MARK: - Quick Action Card Component

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let badgeCount: Int
    let icon: String
    let color: Color
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(isDisabled ? Color.secondary.opacity(0.12) : color.opacity(0.15))
                        .frame(width: 46, height: 46)
                    Image(systemName: isDisabled ? "checkmark" : icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isDisabled ? Color.secondary : color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.dsHeadline)
                        .foregroundStyle(isDisabled ? .secondary : .primary)
                    Text(subtitle)
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !isDisabled {
                    HStack(spacing: 6) {
                        Text("\(badgeCount)")
                            .font(.dsCallout)
                            .fontWeight(.bold)
                            .foregroundStyle(color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(color.opacity(0.12))
                            .clipShape(Capsule())

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(DS.Spacing.md)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(isDisabled ? Color.clear : color.opacity(0.20), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
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
                        .fill(isSelected ? mode.color : mode.color.opacity(0.12))
                        .frame(width: 44, height: 44)

                    Image(systemName: mode.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : mode.color)
                }

                Text(mode.shortTitle)
                    .font(.dsHeadline)
                    .foregroundStyle(isSelected ? mode.color : .primary)

                Text(mode.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .padding(.horizontal, DS.Spacing.xs)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(isSelected ? mode.color : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            .shadow(color: isSelected ? mode.color.opacity(0.15) : Color.black.opacity(0.03), radius: isSelected ? 8 : 4, x: 0, y: 3)
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
