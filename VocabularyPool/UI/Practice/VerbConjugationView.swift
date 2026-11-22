//
//  VerbConjugationView.swift
//  VocabularyPool
//
//  Created by Assistant on 08.10.2026.
//

import SwiftUI
import SwiftData
import AVFoundation

struct VerbConjugationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allWords: [Word]

    @State private var cards: [Word] = []
    @State private var currentIndex: Int = 0
    @State private var cardOffset: CGSize = .zero
    @State private var isFinished: Bool = false

    @AppStorage("isPracticeSoundEnabled") private var isSoundEnabled: Bool = true
    private let speechSynthesizer = AVSpeechSynthesizer()

    var verbWords: [Word] {
        allWords.filter { $0.isVerb }
    }

    var currentWord: Word? {
        guard currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var body: some View {
        VStack {
            if verbWords.isEmpty {
                VStack(spacing: DS.Spacing.lg) {
                    ContentUnavailableView(
                        "Henüz Fiil Eklenmedi",
                        systemImage: "repeat.circle",
                        description: Text("Fiil çekimleri alıştırması yapmak için 'Kelime Ekle' sayfasından 'Fiil Çekimi' seçeneği ile düzensiz fiillerinizi ekleyin.")
                    )
                    
                    Button {
                        dismiss()
                    } label: {
                        Text("Tamam")
                            .font(.dsHeadline)
                            .frame(maxWidth: 200)
                            .padding(.vertical, DS.Spacing.md)
                            .background(DS.Colors.purple)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                }
                .padding()
            } else if !isFinished, let word = currentWord {
                VStack(spacing: DS.Spacing.lg) {
                    
                    // MARK: - Header Info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fiil Çekimleri")
                                .font(.dsHeadline)
                                .foregroundStyle(.primary)
                            Text("Kartı sağa/sola kaydırarak fiilleri tekrar edin")
                                .font(.dsCaption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()

                        Text("\(currentIndex + 1) / \(cards.count)")
                            .font(.dsHeadline)
                            .foregroundStyle(DS.Colors.purple)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(DS.Colors.purple.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, DS.Spacing.md)

                    Spacer()

                    // MARK: - Swipable Verb Conjugation Card
                    ZStack {
                        // Card Background & Shadow
                        RoundedRectangle(cornerRadius: DS.Radius.xl)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                            .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 8)

                        VStack(spacing: DS.Spacing.lg) {
                            Spacer()

                            // V1 (Base Form) Header
                            VStack(spacing: 4) {
                                Text("V1 (Yalın Hal)")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(DS.Colors.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(DS.Colors.primary.opacity(0.12))
                                    .clipShape(Capsule())
                                
                                Text(word.english)
                                    .font(.system(size: 38, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                            }

                            Divider()
                                .padding(.horizontal, DS.Spacing.xl)

                            // V2 & V3 Conjugation Display Row
                            HStack(spacing: DS.Spacing.lg) {
                                // V2 Box
                                VStack(spacing: 4) {
                                    Text("V2 (Past)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(DS.Colors.purple)
                                    Text(word.v2 ?? "-")
                                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.md)
                                .background(DS.Colors.purple.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.tertiary)

                                // V3 Box
                                VStack(spacing: 4) {
                                    Text("V3 (Participle)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(DS.Colors.total)
                                    Text(word.v3 ?? "-")
                                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DS.Spacing.md)
                                .background(DS.Colors.total.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            }
                            .padding(.horizontal, DS.Spacing.lg)

                            // Turkish Meaning
                            VStack(spacing: 4) {
                                Text("Türkçe Anlamı")
                                    .font(.dsCaption)
                                    .foregroundStyle(.secondary)
                                Text(word.turkish)
                                    .font(.dsTitle)
                                    .foregroundStyle(DS.Colors.accent)
                            }
                            .padding(.top, 4)

                            Spacer()

                            // Audio Pronunciation Button
                            Button {
                                speakConjugations(v1: word.english, v2: word.v2, v3: word.v3)
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "speaker.wave.2.fill")
                                    Text("Çekimleri Sesli Dinle")
                                }
                                .font(.dsCaption)
                                .fontWeight(.semibold)
                                .foregroundStyle(DS.Colors.purple)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(DS.Colors.purple.opacity(0.12))
                                .clipShape(Capsule())
                            }
                            .padding(.bottom, DS.Spacing.lg)
                        }
                    }
                    .frame(height: 380)
                    .padding(.horizontal, DS.Spacing.md)
                    .offset(x: cardOffset.width, y: cardOffset.height * 0.2)
                    .rotationEffect(.degrees(Double(cardOffset.width / 18)))
                    .gesture(
                        DragGesture()
                            .onChanged { gesture in
                                cardOffset = gesture.translation
                            }
                            .onEnded { gesture in
                                if abs(gesture.translation.width) > 100 {
                                    advanceToNextCard()
                                } else {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        cardOffset = .zero
                                    }
                                }
                            }
                    )

                    Spacer()

                    // MARK: - Navigation Ergonomic Buttons
                    HStack(spacing: DS.Spacing.md) {
                        // Previous Card Button
                        Button {
                            if currentIndex > 0 {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    currentIndex -= 1
                                    if let next = currentWord {
                                        speakConjugations(v1: next.english, v2: next.v2, v3: next.v3)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.system(size: 20))
                                Text("Önceki")
                                    .font(.dsHeadline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.secondary.opacity(0.12))
                            .foregroundStyle(currentIndex > 0 ? Color.primary : Color.secondary.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                        .disabled(currentIndex == 0)

                        // Next Card Button
                        Button {
                            advanceToNextCard()
                        } label: {
                            HStack(spacing: 6) {
                                Text("Sonraki Fiil")
                                    .font(.dsHeadline)
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 20))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(DS.Colors.purple)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.lg)
                }
                .padding(.top, DS.Spacing.md)
            } else if isFinished {
                // MARK: - Completion Results View
                VStack(spacing: DS.Spacing.lg) {
                    Spacer()

                    VStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(DS.Colors.purple)

                        Text("Fiil Çekimleri Tamamlandı!")
                            .font(.dsTitle)

                        Text("\(cards.count) Fiil Tekrar Edildi")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.purple)

                        Text("Düzensiz fiillerin V1, V2 ve V3 hallerini başarıyla gözden geçirdiniz.")
                            .font(.dsCallout)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
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
                            recordSession()
                            prepareCards()
                        } label: {
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Karıştır ve Tekrar Et")
                                    .font(.dsHeadline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(DS.Colors.purple)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        }

                        Button {
                            recordSession()
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
            } else {
                // Loading state while cards array is being prepared
                ProgressView()
                    .onAppear {
                        prepareCards()
                    }
            }
        }
        .navigationTitle("Fiil Çekimleri")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            prepareCards()
            if let first = currentWord {
                speakConjugations(v1: first.english, v2: first.v2, v3: first.v3)
            }
        }
        .onChange(of: allWords) { _, _ in
            if cards.isEmpty {
                prepareCards()
            }
        }
    }

    // MARK: - Actions & Logic

    private func advanceToNextCard() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        withAnimation(.easeOut(duration: 0.22)) {
            cardOffset = CGSize(width: 450, height: 0)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            cardOffset = .zero
            currentIndex += 1

            if currentIndex < cards.count {
                if let next = currentWord {
                    speakConjugations(v1: next.english, v2: next.v2, v3: next.v3)
                }
            } else {
                withAnimation {
                    isFinished = true
                }
            }
        }
    }

    private func prepareCards() {
        guard !verbWords.isEmpty else {
            cards = []
            return
        }
        cards = verbWords.shuffled()
        currentIndex = 0
        cardOffset = .zero
        isFinished = false
    }

    private func speakConjugations(v1: String, v2: String?, v3: String?) {
        guard isSoundEnabled else { return }
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        var fullPhrase = v1
        if let v2 = v2, !v2.isEmpty { fullPhrase += ", \(v2)" }
        if let v3 = v3, !v3.isEmpty { fullPhrase += ", \(v3)" }

        let utterance = AVSpeechUtterance(string: fullPhrase)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45
        speechSynthesizer.speak(utterance)
    }

    private func recordSession() {
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

            session.verbConjugationsCount += cards.count
            try modelContext.save()
        } catch {
            print("Failed to record verb conjugation session: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        VerbConjugationView()
            .modelContainer(for: Word.self, inMemory: true)
    }
}
