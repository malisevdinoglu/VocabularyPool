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
    
    // Sound toggle
    @State private var isSoundEnabled = true
    
    // Speech synthesizer
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    // Colorful gradients for question boxes
    private let questionColors: [LinearGradient] = [
        LinearGradient(colors: [Color(red: 0.2, green: 0.5, blue: 0.9), Color(red: 0.1, green: 0.3, blue: 0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.9, green: 0.3, blue: 0.5), Color(red: 0.7, green: 0.1, blue: 0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.3, green: 0.8, blue: 0.4), Color(red: 0.1, green: 0.6, blue: 0.2)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.9, green: 0.6, blue: 0.2), Color(red: 0.7, green: 0.4, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.6, green: 0.3, blue: 0.9), Color(red: 0.4, green: 0.1, blue: 0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.2, green: 0.8, blue: 0.8), Color(red: 0.1, green: 0.6, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.9, green: 0.5, blue: 0.3), Color(red: 0.7, green: 0.3, blue: 0.1)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.5, green: 0.3, blue: 0.8), Color(red: 0.3, green: 0.1, blue: 0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.3, green: 0.6, blue: 0.9), Color(red: 0.1, green: 0.4, blue: 0.7)], startPoint: .topLeading, endPoint: .bottomTrailing),
        LinearGradient(colors: [Color(red: 0.8, green: 0.3, blue: 0.6), Color(red: 0.6, green: 0.1, blue: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
    ]
    
    var body: some View {
        VStack {
            if questions.isEmpty {
                ContentUnavailableView("Loading...", systemImage: "clock")
            } else if currentQuestionIndex < questions.count {
                ScrollView { // Added ScrollView to handle keyboard
                    VStack(spacing: 30) {
                        // Progress
                        Text("Question \(currentQuestionIndex + 1) / \(questions.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // Question Card with Speaker Button
                        RoundedRectangle(cornerRadius: 16)
                            .fill(questionColors[currentQuestionIndex % questionColors.count])
                            .frame(height: 200)
                            .shadow(radius: 5)
                            .overlay(
                                // Centered text or icon
                                Group {
                                    if config.type == .listening {
                                        VStack(spacing: 16) {
                                            Image(systemName: "headphones")
                                                .font(.system(size: 60))
                                                .foregroundStyle(.white)
                                            Text("Listen...")
                                                .font(.title2)
                                                .foregroundStyle(.white.opacity(0.8))
                                        }
                                    } else {
                                        Text(config.type == .englishToTurkish ? questions[currentQuestionIndex].english : questions[currentQuestionIndex].turkish)
                                            .font(.system(size: 40, weight: .bold))
                                            .foregroundStyle(.white)
                                            .multilineTextAlignment(.center)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .padding(.horizontal, 50)
                                    }
                                }
                            )
                            .overlay(
                                // Speaker button in top-right corner
                                Button {
                                    speakCurrentWord()
                                } label: {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                        .padding()
                                }
                                , alignment: .topTrailing
                            )
                        
                        // Input Area
                        VStack(spacing: 16) {
                            TextField(config.type == .englishToTurkish ? "Enter Turkish meaning" : "Enter English word", text: $userAnswer)
                                .textFieldStyle(.roundedBorder)
                                .font(.title2)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isInputFocused)
                                .disabled(isProcessing)
                                .onSubmit {
                                    checkAnswer()
                                }
                                .overlay(
                                    HStack {
                                        Spacer()
                                        if !userAnswer.isEmpty && !isProcessing {
                                            Button {
                                                userAnswer = ""
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.gray)
                                                    .padding(.trailing, 8)
                                            }
                                        }
                                    }
                                )
                            
                            if let feedback = feedbackMessage {
                                Text(feedback)
                                    .font(.headline)
                                    .foregroundStyle(isCorrect ? .green : .red)
                                    .transition(.opacity)
                            }
                            
                            Button {
                                checkAnswer()
                            } label: {
                                Text("Check Answer")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(isProcessing ? Color.gray : Color.blue)
                                    .foregroundStyle(.white)
                                    .cornerRadius(12)
                            }
                            .disabled(userAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing || showAnswerRevealed)
                            
                            // Show Answer Button - only show if answer was wrong or not yet checked
                            if showAnswerRevealed {
                                Button {
                                    proceedToNext()
                                } label: {
                                    Text("Next Question")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.green)
                                        .foregroundStyle(.white)
                                        .cornerRadius(12)
                                }
                            } else {
                                Button {
                                    showAnswer()
                                } label: {
                                    Text("Show Answer")
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.orange.opacity(0.2))
                                        .foregroundStyle(.orange)
                                        .cornerRadius(12)
                                }
                                .disabled(isProcessing)
                            }
                        }
                        .padding()
                    }
                    .padding()
                }
                .onChange(of: currentQuestionIndex) { oldValue, newValue in
                    // Speak the new word when question changes
                    if newValue < questions.count {
                        speakCurrentWord()
                    }
                }
            } else {
                // Results View
                VStack(spacing: 20) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.yellow)
                    
                    Text("Session Complete!")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Score: \(score) / \(questions.count)")
                        .font(.title2)
                    
                    Button("Finish") {
                        recordPracticeSession()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top)
                }
            }
        }
        .navigationTitle("Practice")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isSoundEnabled.toggle()
                } label: {
                    Image(systemName: isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .foregroundStyle(isSoundEnabled ? .blue : .gray)
                }
            }
        }
        .onAppear {
            // Configure audio session for playback
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
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
        // Sort words by timestamp in ascending order (oldest first)
        let sortedWords = allWords.sorted { $0.timestamp < $1.timestamp }
        
        // Filter by range if specified
        var wordsToUse: [Word]
        if let rangeStart = config.wordRangeStart, let rangeEnd = config.wordRangeEnd {
            // Convert 1-indexed user input to 0-indexed array indices
            let startIndex = max(0, rangeStart - 1)
            let endIndex = min(sortedWords.count - 1, rangeEnd - 1)
            
            // Ensure valid range
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
        guard currentQuestionIndex < questions.count, isSoundEnabled else { return }
        
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
            // Correct
            isProcessing = true
            isCorrect = true
            feedbackMessage = "Doğru!"
            score += 1
            currentWord.correctCount += 1
            
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
            // Wrong - don't auto-advance, wait for user to click "Show Answer"
            isCorrect = false
            feedbackMessage = "Yanlış!"
            currentWord.wrongCount += 1
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
            
            if let existingSession = sessions.first {
                session = existingSession
            } else {
                session = PracticeSession(date: today)
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
