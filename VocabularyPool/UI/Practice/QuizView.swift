//
//  QuizView.swift
//  VocabularyPool
//
//  Created by Assistant on 02.01.2026.
//

import SwiftUI
import SwiftData
import AVFoundation

struct QuizView: View {
    let config: QuizConfig
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allWords: [Word]
    
    @State private var questions: [Word] = []
    @State private var currentQuestionIndex = 0
    @State private var score = 0
    
    // UI State
    @State private var userAnswer = ""
    @State private var feedbackMessage: String? = nil
    @State private var isCorrect: Bool = false
    @State private var isProcessing = false
    @State private var showAnswerRevealed = false
    @FocusState private var isInputFocused: Bool
    
    // Sound toggle - @AppStorage ile otomatik senkronizasyon
    // Listening modunda ses her zaman açık olacak, diğer modlarda bu ayar kontrol edilecek
    @AppStorage("isPracticeSoundEnabled") private var isSoundEnabled: Bool = true
    
    // Speech synthesizer
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // Curated gradients for question cards
    private let questionColors: [LinearGradient] = [
        LinearGradient(colors: [DS.Colors.primary,  Color(red: 0.24, green: 0.20, blue: 0.75)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [DS.Colors.accent,   Color(red: 0.02, green: 0.44, blue: 0.40)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [DS.Colors.warning,  Color(red: 0.65, green: 0.35, blue: 0.01)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [DS.Colors.purple,   Color(red: 0.40, green: 0.25, blue: 0.75)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.88, green: 0.28, blue: 0.48), Color(red: 0.68, green: 0.10, blue: 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.18, green: 0.70, blue: 0.72), Color(red: 0.08, green: 0.50, blue: 0.58)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.82, green: 0.42, blue: 0.22), Color(red: 0.62, green: 0.27, blue: 0.08)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.42, green: 0.22, blue: 0.80), Color(red: 0.28, green: 0.08, blue: 0.60)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.22, green: 0.52, blue: 0.90), Color(red: 0.08, green: 0.36, blue: 0.70)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.72, green: 0.22, blue: 0.58), Color(red: 0.52, green: 0.08, blue: 0.40)], startPoint: .topLeading, endPoint: .bottomTrailing)
    ]
    
    var body: some View {
        VStack {
            if questions.isEmpty {
                ContentUnavailableView("Loading...", systemImage: "clock")
            } else if currentQuestionIndex < questions.count {
                ScrollView {
                    VStack(spacing: DS.Spacing.lg) {

                        // Question Card
                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: DS.Radius.xl)
                                .fill(questionColors[currentQuestionIndex % questionColors.count])
                                .frame(height: 220)
                                .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 6)
                                .overlay(
                                    Group {
                                        if config.type == .listening {
                                            VStack(spacing: DS.Spacing.md) {
                                                Image(systemName: "headphones")
                                                    .font(.system(size: 56))
                                                    .foregroundStyle(.white)
                                                Text("Listen...")
                                                    .font(.dsTitle)
                                                    .foregroundStyle(.white.opacity(0.85))
                                            }
                                        } else {
                                            Text(config.type == .englishToTurkish
                                                 ? questions[currentQuestionIndex].english
                                                 : questions[currentQuestionIndex].turkish)
                                                .font(.dsDisplay)
                                                .foregroundStyle(.white)
                                                .multilineTextAlignment(.center)
                                                .padding(.horizontal, DS.Spacing.xl)
                                        }
                                    }
                                )
                                .overlay(alignment: .top) {
                                    // Slim progress bar
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(.white.opacity(0.25))
                                                .frame(height: 4)
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(.white.opacity(0.85))
                                                .frame(
                                                    width: geo.size.width * (Double(currentQuestionIndex + 1) / Double(questions.count)),
                                                    height: 4
                                                )
                                                .animation(.easeInOut(duration: 0.3), value: currentQuestionIndex)
                                        }
                                    }
                                    .frame(height: 4)
                                    .padding(.horizontal, DS.Spacing.md)
                                    .padding(.top, DS.Spacing.md)
                                }
                                .overlay(alignment: .topTrailing) {
                                    // Speaker button with material background
                                    Button { speakCurrentWord() } label: {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .frame(width: 36, height: 36)
                                            .background(.ultraThinMaterial)
                                            .clipShape(Circle())
                                    }
                                    .padding(DS.Spacing.md)
                                }

                            // Progress label
                            VStack {
                                Spacer()
                                Text("Question \(currentQuestionIndex + 1) of \(questions.count)")
                                    .font(.dsCaption)
                                    .foregroundStyle(.white.opacity(0.75))
                                    .padding(.bottom, DS.Spacing.sm)
                            }
                            .frame(height: 220)
                        }

                        // Input Area
                        VStack(spacing: DS.Spacing.md) {
                            // Answer field
                            HStack {
                                TextField(
                                    config.type == .englishToTurkish ? "Enter Turkish meaning" : "Enter English word",
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
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(DS.Spacing.md)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))

                            // Feedback message
                            if let feedback = feedbackMessage {
                                Text(feedback)
                                    .font(.dsHeadline)
                                    .foregroundStyle(isCorrect ? DS.Colors.success : DS.Colors.danger)
                                    .multilineTextAlignment(.center)
                                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                            }

                            // Action buttons
                            Button {
                                checkAnswer()
                            } label: {
                                Text("Check Answer")
                                    .font(.dsHeadline)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(isProcessing ? Color.secondary.opacity(0.25) : DS.Colors.primary)
                                    .foregroundStyle(DS.Colors.onColor)
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            }
                            .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing || showAnswerRevealed)

                            if showAnswerRevealed {
                                Button {
                                    proceedToNext()
                                } label: {
                                    Text("Next Question")
                                        .font(.dsHeadline)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                        .background(DS.Colors.success)
                                        .foregroundStyle(DS.Colors.onColor)
                                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                                }
                            } else {
                                Button {
                                    showAnswer()
                                } label: {
                                    Text("Show Answer")
                                        .font(.dsCallout)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 52)
                                        .background(DS.Colors.warning.opacity(0.12))
                                        .foregroundStyle(DS.Colors.warning)
                                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                                }
                                .disabled(isProcessing)
                            }
                        }
                        .padding(.horizontal, DS.Spacing.md)
                    }
                    .padding(DS.Spacing.md)
                }
                .onChange(of: currentQuestionIndex) { oldValue, newValue in
                    // Speak the new word when question changes
                    if newValue < questions.count {
                        speakCurrentWord()
                    }
                }
            } else {
                // Results View
                VStack(spacing: DS.Spacing.lg) {
                    Spacer()

                    // Score card
                    VStack(spacing: DS.Spacing.lg) {
                        Image(systemName: score == questions.count ? "star.fill" : "checkmark.seal.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(score == questions.count ? .yellow : DS.Colors.primary)

                        Text("Session Complete!")
                            .font(.dsTitle)

                        Text("\(score) / \(questions.count)")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(DS.Colors.primary)

                        // Accuracy bar
                        let pct = questions.isEmpty ? 0.0 : Double(score) / Double(questions.count)
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            HStack {
                                Text("Accuracy")
                                    .font(.dsCaption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(Int(pct * 100))%")
                                    .font(.dsCaption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(pct >= 0.7 ? DS.Colors.success : DS.Colors.warning)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.secondary.opacity(0.2))
                                        .frame(height: 10)
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(pct >= 0.7 ? DS.Colors.success : DS.Colors.warning)
                                        .frame(width: geo.size.width * pct, height: 10)
                                }
                            }
                            .frame(height: 10)
                        }
                        .padding(.horizontal, DS.Spacing.md)
                    }
                    .padding(DS.Spacing.xl)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
                    .shadow(color: Color.black.opacity(0.07), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, DS.Spacing.md)

                    Spacer()

                    // Action buttons
                    VStack(spacing: DS.Spacing.sm) {
                        Button {
                            recordPracticeSession()
                            dismiss()
                        } label: {
                            Text("Finish")
                                .font(.dsHeadline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(DS.Colors.primary)
                                .foregroundStyle(DS.Colors.onColor)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.lg)
                }
            }
        }
        .navigationTitle(config.reviewMode ? "Hataları Pekiştir" : "Practice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Listening modunda ses butonu gösterme (zaten her zaman açık)
            if config.type != .listening {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isSoundEnabled.toggle()
                        // @AppStorage otomatik kaydeder, manuel kaydetmeye gerek yok
                    } label: {
                        Image(systemName: isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .foregroundStyle(isSoundEnabled ? .blue : .gray)
                    }
                }
            }
        }
        .onAppear {
            // Configure audio session based on sound preference
            do {
                if isSoundEnabled {
                    // Ses açıksa playback mode (medya kesilir)
                    try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                } else {
                    // Ses kapalıysa ambient mode (medya kesintiye uğramaz)
                    try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
                }
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("Failed to configure audio session: \(error)")
            }
            
            prepareQuiz()
            isInputFocused = true
            
            // Speak the first word after a small delay to ensure questions are loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                speakCurrentWord()
            }
        }
    }
    
    private func prepareQuiz() {
        // Review mode: use only words flagged for review, shuffled
        if config.reviewMode {
            questions = allWords.filter { $0.needsReview }.shuffled()
            return
        }

        // Sort words by timestamp in ascending order (oldest first)
        let sortedWords = allWords.sorted { $0.timestamp < $1.timestamp }

        // Filter by range if specified
        var wordsToUse: [Word]
        if let rangeStart = config.wordRangeStart, let rangeEnd = config.wordRangeEnd {
            let startIndex = max(0, rangeStart - 1)
            let endIndex = min(sortedWords.count - 1, rangeEnd - 1)

            if startIndex <= endIndex && startIndex < sortedWords.count {
                wordsToUse = Array(sortedWords[startIndex...endIndex])
            } else {
                wordsToUse = sortedWords
            }
        } else {
            wordsToUse = sortedWords
        }

        // Shuffle and select questions
        let shuffled = wordsToUse.shuffled()
        let count = min(config.count, shuffled.count)
        questions = Array(shuffled.prefix(count))
    }
    
    private func speakCurrentWord() {
        guard currentQuestionIndex < questions.count else { return }
        
        // Listening modunda ses her zaman açık, diğer modlarda ayara bakılır
        let shouldPlaySound = config.type == .listening || isSoundEnabled
        guard shouldPlaySound else { return }
        
        let currentWord = questions[currentQuestionIndex]
        let textToSpeak: String
        let languageCode: String
        
        // Determine what to speak based on practice type
        if config.type == .englishToTurkish || config.type == .listening {
            textToSpeak = currentWord.english
            languageCode = "en-US"
        } else {
            textToSpeak = currentWord.turkish
            languageCode = "tr-TR"
        }
        
        // Stop any ongoing speech
        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        
        // Create and configure speech utterance
        let utterance = AVSpeechUtterance(string: textToSpeak)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        utterance.rate = 0.5 // Slightly slower for better comprehension
        
        // Speak
        speechSynthesizer.speak(utterance)
    }
    
    private func checkAnswer() {
        guard !userAnswer.isEmpty, !isProcessing else { return }
        
        let currentWord = questions[currentQuestionIndex]
        
        // Trim and normalize input
        let input = userAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
        
        // Build list of correct answers
        var correctAnswers: [String] = []
        
        if config.type == .englishToTurkish {
            // Normalize Turkish answer
            correctAnswers.append(currentWord.turkish.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .folding(options: .diacriticInsensitive, locale: .current))
            if let turkishAlt = currentWord.turkishAlt, !turkishAlt.isEmpty {
                correctAnswers.append(turkishAlt.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current))
            }
        } else {
            // Normalize English answer
            correctAnswers.append(currentWord.english.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
                .folding(options: .diacriticInsensitive, locale: .current))
            if let englishAlt = currentWord.englishAlt, !englishAlt.isEmpty {
                correctAnswers.append(englishAlt.trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current))
            }
        }
        
        // Check if input matches any of the correct answers
        let isAnswerCorrect = correctAnswers.contains { answer in
            input == answer
        }
        
        if isAnswerCorrect {
            // Correct — clear review flag so it leaves the mistake queue
            isProcessing = true
            isCorrect = true
            feedbackMessage = "Doğru!"
            score += 1
            currentWord.correctCount += 1
            currentWord.needsReview = false

            // Move to next question after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    currentQuestionIndex += 1
                    userAnswer = ""
                    feedbackMessage = nil
                    isProcessing = false
                    isInputFocused = true
                }
            }
        } else {
            // Wrong — mark for review
            isCorrect = false
            feedbackMessage = "Yanlış!"
            currentWord.wrongCount += 1
            currentWord.needsReview = true
        }
        
        // In listening mode, if correct, show the Turkish meaning
        if isCorrect && config.type == .listening {
             feedbackMessage = "Correct! Meaning: \(currentWord.turkish)"
        }
        
        // Update last studied
        currentWord.lastStudied = Date()
    }
    
    private func showAnswer() {
        guard currentQuestionIndex < questions.count else { return }
        
        let currentWord = questions[currentQuestionIndex]
        let correctAnswer: String
        let alternativeAnswer: String?
        
        if config.type == .englishToTurkish {
            correctAnswer = currentWord.turkish
            alternativeAnswer = currentWord.turkishAlt
        } else {
            correctAnswer = currentWord.english
            alternativeAnswer = currentWord.englishAlt
        }
        
        // Show the answer
        var message = ""
        
        if config.type == .listening {
             message = "Word: \(currentWord.english)\nMeaning: \(currentWord.turkish)"
        } else {
            if let alt = alternativeAnswer, !alt.isEmpty {
                message = "Answer: \(correctAnswer) (or \(alt))"
            } else {
                message = "Answer: \(correctAnswer)"
            }
        }
        
        feedbackMessage = message
        isCorrect = false
        showAnswerRevealed = true
        currentWord.needsReview = true

        // Update statistics if not already marked wrong
        if feedbackMessage?.contains("Yanlış") == false {
            currentWord.wrongCount += 1
        }
        currentWord.lastStudied = Date()
    }
    
    private func proceedToNext() {
        withAnimation {
            currentQuestionIndex += 1
            userAnswer = ""
            feedbackMessage = nil
            isProcessing = false
            showAnswerRevealed = false
            isInputFocused = true
        }
    }
    
    private func recordPracticeSession() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Calculate the end of today
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return }
        
        // Find or create today's session using date range
        let descriptor = FetchDescriptor<PracticeSession>(
            predicate: #Predicate { session in
                session.date >= today && session.date < tomorrow
            }
        )
        
        do {
            let sessions = try modelContext.fetch(descriptor)
            let session: PracticeSession
            
            // Determine if this is the first session of the day
            let isFirstSessionToday = sessions.isEmpty
            
            if let existingSession = sessions.first {
                session = existingSession
                
                // Backfill goal snapshot if not set (session created before goals were set)
                let currentGoals = PracticeGoals.shared
                if session.dailyGoalEngToTr == 0 && session.dailyGoalTrToEng == 0 && session.dailyGoalListening == 0 {
                    // Only update if current goals are set
                    if currentGoals.hasAnyGoals() {
                        session.dailyGoalEngToTr = currentGoals.englishToTurkishGoal
                        session.dailyGoalTrToEng = currentGoals.turkishToEnglishGoal
                        session.dailyGoalListening = currentGoals.listeningGoal
                    }
                }
            } else {
                // First session of the day - capture current goals as snapshot
                let currentGoals = PracticeGoals.shared
                session = PracticeSession(
                    date: today,
                    dailyGoalEngToTr: currentGoals.englishToTurkishGoal,
                    dailyGoalTrToEng: currentGoals.turkishToEnglishGoal,
                    dailyGoalListening: currentGoals.listeningGoal
                )
                modelContext.insert(session)
            }
            
            // Update counts based on practice type
            if config.type == .listening {
                session.listeningCount += questions.count
            } else if config.type == .englishToTurkish {
                session.englishToTurkishCount += questions.count
            } else {
                session.turkishToEnglishCount += questions.count
            }
            
            try modelContext.save()
        } catch {
            print("Failed to record practice session: \(error)")
        }
    }
}
