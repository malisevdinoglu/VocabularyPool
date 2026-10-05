//
//  AudioListeningView.swift
//  VocabularyPool
//
//  Hands-free Audio Player Practice Mode (Otomatik Sesli Dinleme)
//

import SwiftUI
import SwiftData
import AVFoundation
import Combine

@MainActor
final class AudioPlayerManager: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published var words: [Word] = []
    @Published var currentIndex: Int = 0
    @Published var isPlaying: Bool = false
    @Published var activePhase: Phase = .idle
    @Published var isShuffle: Bool = false
    @Published var isLoop: Bool = true
    @Published var delayInterval: Double = 1.2
    @Published var isFinished: Bool = false

    enum Phase {
        case idle
        case speakingEN
        case pauseBetween
        case speakingTR
        case pauseNext
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var baseWords: [Word] = []
    private var delayTask: Task<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()
    }

    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session configuration error: \(error)")
        }
    }

    func setup(words: [Word]) {
        self.baseWords = words
        if isShuffle {
            self.words = words.shuffled()
        } else {
            self.words = words
        }
        self.currentIndex = 0
        self.isFinished = false
        self.activePhase = .idle
    }

    func toggleShuffle() {
        isShuffle.toggle()
        let current = currentWord
        if isShuffle {
            words = words.shuffled()
        } else {
            words = baseWords
        }
        if let current = current, let idx = words.firstIndex(where: { $0.id == current.id }) {
            currentIndex = idx
        } else {
            currentIndex = 0
        }
    }

    var currentWord: Word? {
        guard !words.isEmpty, currentIndex >= 0, currentIndex < words.count else { return nil }
        return words[currentIndex]
    }

    func play() {
        guard !words.isEmpty else { return }
        if isFinished {
            currentIndex = 0
            isFinished = false
        }
        isPlaying = true
        startPhaseEN()
    }

    func pause() {
        isPlaying = false
        cancelDelay()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        activePhase = .idle
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func next() {
        cancelDelay()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        if currentIndex < words.count - 1 {
            currentIndex += 1
            if isPlaying {
                startPhaseEN()
            } else {
                activePhase = .idle
            }
        } else if isLoop {
            currentIndex = 0
            if isPlaying {
                startPhaseEN()
            } else {
                activePhase = .idle
            }
        } else {
            isPlaying = false
            isFinished = true
            activePhase = .idle
        }
    }

    func previous() {
        cancelDelay()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        if currentIndex > 0 {
            currentIndex -= 1
        } else {
            currentIndex = max(0, words.count - 1)
        }

        if isPlaying {
            startPhaseEN()
        } else {
            activePhase = .idle
        }
    }

    func restart() {
        cancelDelay()
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        currentIndex = 0
        isFinished = false
        play()
    }

    private func cancelDelay() {
        delayTask?.cancel()
        delayTask = nil
    }

    private func startPhaseEN() {
        guard isPlaying, let word = currentWord else { return }
        activePhase = .speakingEN

        let utterance = AVSpeechUtterance(string: word.english)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synthesizer.speak(utterance)
    }

    private func startPhaseTR() {
        guard isPlaying, let word = currentWord else { return }
        activePhase = .speakingTR

        let utterance = AVSpeechUtterance(string: word.turkish)
        utterance.voice = AVSpeechSynthesisVoice(language: "tr-TR")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        synthesizer.speak(utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.isPlaying else { return }

            if self.activePhase == .speakingEN {
                self.activePhase = .pauseBetween
                self.delayTask = Task {
                    try? await Task.sleep(nanoseconds: UInt64(self.delayInterval * 1_000_000_000))
                    guard !Task.isCancelled, self.isPlaying else { return }
                    self.startPhaseTR()
                }
            } else if self.activePhase == .speakingTR {
                self.activePhase = .pauseNext
                self.delayTask = Task {
                    try? await Task.sleep(nanoseconds: UInt64(self.delayInterval * 1.3 * 1_000_000_000))
                    guard !Task.isCancelled, self.isPlaying else { return }
                    self.next()
                }
            }
        }
    }
}

struct AudioListeningView: View {
    let config: QuizConfig
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allWords: [Word]

    @StateObject private var playerManager = AudioPlayerManager()

    var body: some View {
        VStack(spacing: 0) {
            if playerManager.words.isEmpty {
                ContentUnavailableView("Kelime Bulunamadı", systemImage: "headphones")
            } else if playerManager.isFinished {
                // MARK: - Completion View
                VStack(spacing: DS.Spacing.lg) {
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(DS.Colors.warning.opacity(0.15))
                            .frame(width: 100, height: 100)
                        Image(systemName: "headphones.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(DS.Colors.warning)
                    }

                    Text("Dinleme Tamamlandı!")
                        .font(.dsTitle)
                        .foregroundStyle(.primary)

                    Text("Seçilen kelime aralığındaki tüm kelimeleri sesli dinlediniz.")
                        .font(.dsBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DS.Spacing.xl)

                    Spacer()

                    VStack(spacing: DS.Spacing.md) {
                        Button {
                            playerManager.restart()
                        } label: {
                            Label("Tekrar Dinle", systemImage: "arrow.clockwise")
                                .font(.dsHeadline)
                                .frame(maxWidth: .infinity)
                                .padding(DS.Spacing.md)
                                .background(DS.Colors.warning)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        }

                        Button {
                            playerManager.pause()
                            dismiss()
                        } label: {
                            Text("Pratik Sayfasına Dön")
                                .font(.dsHeadline)
                                .frame(maxWidth: .infinity)
                                .padding(DS.Spacing.md)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                                .foregroundStyle(.primary)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.lg)
                }
            } else if let word = playerManager.currentWord {
                // MARK: - Active Player Screen
                VStack(spacing: DS.Spacing.md) {

                    // MARK: Top Bar
                    HStack {
                        Button {
                            playerManager.pause()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        HStack(spacing: DS.Spacing.xs) {
                            Image(systemName: "headphones")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(DS.Colors.warning)
                            Text("Kelime \(playerManager.currentIndex + 1) / \(playerManager.words.count)")
                                .font(.dsHeadline)
                                .foregroundStyle(DS.Colors.warning)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(DS.Colors.warning.opacity(0.12))
                        .clipShape(Capsule())

                        Spacer()

                        // Balance spacer
                        Color.clear
                            .frame(width: 24, height: 24)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.top, DS.Spacing.sm)

                    Spacer()

                    // MARK: Main Hero Card
                    VStack(spacing: DS.Spacing.lg) {
                        
                        // Equalizer / Waveform animation
                        HStack(spacing: 6) {
                            ForEach(0..<5) { index in
                                AnimatedSoundBar(isPlaying: playerManager.isPlaying, index: index)
                            }
                        }
                        .padding(.top, DS.Spacing.md)

                        // English Word Block
                        VStack(spacing: DS.Spacing.xs) {
                            HStack(spacing: DS.Spacing.xs) {
                                Text("İNGİLİZCE")
                                    .font(.dsCaption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(playerManager.activePhase == .speakingEN ? DS.Colors.warning : .secondary)

                                if playerManager.activePhase == .speakingEN {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.caption2)
                                        .foregroundStyle(DS.Colors.warning)
                                }
                            }

                            Text(word.english)
                                .font(.dsDisplay)
                                .foregroundStyle(playerManager.activePhase == .speakingEN ? DS.Colors.warning : .primary)
                                .multilineTextAlignment(.center)
                                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: playerManager.activePhase)
                        }
                        .padding(.vertical, DS.Spacing.sm)

                        Divider()
                            .padding(.horizontal, DS.Spacing.xl)

                        // Turkish Word Block
                        VStack(spacing: DS.Spacing.xs) {
                            HStack(spacing: DS.Spacing.xs) {
                                Text("TÜRKÇE")
                                    .font(.dsCaption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(playerManager.activePhase == .speakingTR ? DS.Colors.accent : .secondary)

                                if playerManager.activePhase == .speakingTR {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .font(.caption2)
                                        .foregroundStyle(DS.Colors.accent)
                                }
                            }

                            Text(word.turkish)
                                .font(.dsTitle)
                                .foregroundStyle(playerManager.activePhase == .speakingTR ? DS.Colors.accent : .secondary)
                                .multilineTextAlignment(.center)
                                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: playerManager.activePhase)
                        }
                        .padding(.vertical, DS.Spacing.sm)

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(DS.Spacing.lg)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
                    .padding(.horizontal, DS.Spacing.md)

                    Spacer()

                    // MARK: Player Controls Bar
                    VStack(spacing: DS.Spacing.md) {
                        
                        // Row 1: Playback Buttons
                        HStack(spacing: DS.Spacing.lg) {
                            
                            // Shuffle Button
                            Button {
                                playerManager.toggleShuffle()
                            } label: {
                                Image(systemName: "shuffle")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(playerManager.isShuffle ? DS.Colors.warning : .secondary)
                                    .padding(12)
                                    .background(playerManager.isShuffle ? DS.Colors.warning.opacity(0.15) : Color(uiColor: .tertiarySystemFill))
                                    .clipShape(Circle())
                            }

                            // Previous Word
                            Button {
                                playerManager.previous()
                            } label: {
                                Image(systemName: "backward.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }

                            // Play / Pause Main Button
                            Button {
                                playerManager.togglePlayPause()
                            } label: {
                                Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 68, height: 68)
                                    .background(DS.Colors.warning)
                                    .clipShape(Circle())
                                    .shadow(color: DS.Colors.warning.opacity(0.35), radius: 10, x: 0, y: 4)
                            }

                            // Next Word
                            Button {
                                playerManager.next()
                            } label: {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 22, weight: .semibold))
                                    .foregroundStyle(.primary)
                            }

                            // Loop Button
                            Button {
                                playerManager.isLoop.toggle()
                            } label: {
                                Image(systemName: playerManager.isLoop ? "repeat.1" : "repeat")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(playerManager.isLoop ? DS.Colors.warning : .secondary)
                                    .padding(12)
                                    .background(playerManager.isLoop ? DS.Colors.warning.opacity(0.15) : Color(uiColor: .tertiarySystemFill))
                                    .clipShape(Circle())
                            }
                        }

                        // Row 2: Delay Speed Picker
                        HStack(spacing: DS.Spacing.sm) {
                            Text("Geçiş Aralığı:")
                                .font(.dsCaption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            ForEach([("Hızlı", 0.6), ("Normal", 1.2), ("Yavaş", 2.0)], id: \.0) { item in
                                Button {
                                    playerManager.delayInterval = item.1
                                } label: {
                                    Text(item.0)
                                        .font(.dsCaption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(playerManager.delayInterval == item.1 ? DS.Colors.warning : Color(uiColor: .tertiarySystemFill))
                                        .foregroundStyle(playerManager.delayInterval == item.1 ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal, DS.Spacing.sm)
                    }
                    .padding(DS.Spacing.md)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.lg)
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarBackButtonHidden(true)
        .onAppear {
            prepareAndStart()
        }
        .onDisappear {
            playerManager.pause()
        }
    }

    private func prepareAndStart() {
        let sorted = allWords.sorted(by: { $0.timestamp < $1.timestamp })
        var wordsToPlay: [Word] = []

        if let start = config.wordRangeStart, let end = config.wordRangeEnd, start <= end {
            let startIndex = max(0, start - 1)
            let endIndex = min(sorted.count, end)
            if startIndex < endIndex {
                wordsToPlay = Array(sorted[startIndex..<endIndex])
            }
        } else {
            let count = min(config.count, sorted.count)
            wordsToPlay = Array(sorted.prefix(count))
        }

        playerManager.setup(words: wordsToPlay)
        playerManager.play()
    }
}

// MARK: - Sound Wave Animated Bar
struct AnimatedSoundBar: View {
    let isPlaying: Bool
    let index: Int

    @State private var barHeight: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(DS.Colors.warning)
            .frame(width: 4, height: isPlaying ? barHeight : 8)
            .animation(
                isPlaying
                    ? Animation.easeInOut(duration: 0.4 + Double(index) * 0.1).repeatForever(autoreverses: true)
                    : .default,
                value: barHeight
            )
            .onAppear {
                if isPlaying {
                    barHeight = CGFloat.random(in: 12...32)
                }
            }
            .onChange(of: isPlaying) { _, playing in
                if playing {
                    barHeight = CGFloat.random(in: 12...32)
                } else {
                    barHeight = 8
                }
            }
    }
}

#Preview {
    AudioListeningView(config: QuizConfig(count: 10, type: .audioListening, wordRangeStart: 1, wordRangeEnd: 10))
        .modelContainer(for: Word.self, inMemory: true)
}
