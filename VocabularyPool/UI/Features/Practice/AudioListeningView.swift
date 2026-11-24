//
//  AudioListeningView.swift
//  VocabularyPool
//
//  Hands-free Auto Audio Play mode in Apple Crafted / Editorial style.
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
        case idle, speakingEN, pauseBetween, speakingTR, pauseNext
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var baseWords: [Word] = []
    private var delayTask: Task<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
        SpeechService.shared.configureAudioSession(soundEnabled: true)
    }

    func setup(words: [Word]) {
        baseWords = words
        self.words = isShuffle ? words.shuffled() : words
        currentIndex = 0
        isFinished = false
        activePhase = .idle
    }

    func toggleShuffle() {
        isShuffle.toggle()
        let current = currentWord
        words = isShuffle ? words.shuffled() : baseWords
        if let current, let idx = words.firstIndex(where: { $0.persistentModelID == current.persistentModelID }) {
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
        delayTask?.cancel()
        delayTask = nil
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        activePhase = .idle
    }

    func next() {
        guard !words.isEmpty else { return }
        let wasPlaying = isPlaying
        pause()
        currentIndex = (currentIndex + 1) % words.count
        if wasPlaying { play() }
    }

    func previous() {
        guard !words.isEmpty else { return }
        let wasPlaying = isPlaying
        pause()
        currentIndex = (currentIndex - 1 + words.count) % words.count
        if wasPlaying { play() }
    }

    private func startPhaseEN() {
        guard isPlaying, let word = currentWord else { return }
        activePhase = .speakingEN
        let utterance = AVSpeechUtterance(string: word.english)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.48
        synthesizer.speak(utterance)
    }

    private func startPhaseTR() {
        guard isPlaying, let word = currentWord else { return }
        activePhase = .speakingTR
        let utterance = AVSpeechUtterance(string: word.formattedTurkishMeanings)
        utterance.voice = AVSpeechSynthesisVoice(language: "tr-TR")
        utterance.rate = 0.50
        synthesizer.speak(utterance)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard self.isPlaying else { return }
            switch self.activePhase {
            case .speakingEN:
                self.activePhase = .pauseBetween
                self.delayTask = Task {
                    try? await Task.sleep(for: .seconds(self.delayInterval))
                    guard !Task.isCancelled, self.isPlaying else { return }
                    self.startPhaseTR()
                }
            case .speakingTR:
                self.activePhase = .pauseNext
                self.delayTask = Task {
                    try? await Task.sleep(for: .seconds(self.delayInterval))
                    guard !Task.isCancelled, self.isPlaying else { return }
                    if self.currentIndex + 1 < self.words.count {
                        self.currentIndex += 1
                        self.startPhaseEN()
                    } else if self.isLoop {
                        self.currentIndex = 0
                        self.startPhaseEN()
                    } else {
                        self.isPlaying = false
                        self.activePhase = .idle
                        self.isFinished = true
                    }
                }
            default:
                break
            }
        }
    }
}

struct AudioListeningView: View {
    let config: PracticeSessionConfig

    @Environment(\.modelContext) private var modelContext
    @Query private var allWords: [Word]
    @StateObject private var player = AudioPlayerManager()
    @State private var didRecordSession = false

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            if player.words.isEmpty {
                ContentUnavailableView("No Words Available", systemImage: "waveform")
            } else if let word = player.currentWord {
                HStack {
                    Text("Hands-free EN → TR audio loop")
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    DSBadge(text: "\(player.currentIndex + 1) / \(player.words.count)", color: DS.Colors.warning)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.sm)

                Spacer()

                VStack(spacing: DS.Spacing.lg) {
                    DSIconBadge(
                        systemImage: player.isPlaying ? "waveform" : "headphones",
                        color: DS.Colors.warning,
                        size: 56
                    )

                    Text(word.english)
                        .font(.dsDisplay)
                        .foregroundStyle(player.activePhase == .speakingEN ? DS.Colors.primary : .primary)
                        .multilineTextAlignment(.center)

                    Divider()

                    Text(word.formattedTurkishMeanings)
                        .font(.dsTitle)
                        .foregroundStyle(player.activePhase == .speakingTR ? DS.Colors.accent : .secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .dsCard(padding: DS.Spacing.xl, cornerRadius: DS.Radius.xl)
                .padding(.horizontal, DS.Spacing.md)

                Spacer()

                // Transport Controls
                VStack(spacing: DS.Spacing.md) {
                    HStack(spacing: DS.Spacing.xl) {
                        Button {
                            Haptics.light()
                            player.toggleShuffle()
                        } label: {
                            Image(systemName: "shuffle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(player.isShuffle ? DS.Colors.primary : .secondary)
                        }

                        Button {
                            Haptics.light()
                            player.previous()
                        } label: {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.primary)
                        }

                        Button {
                            Haptics.medium()
                            if player.isPlaying {
                                player.pause()
                            } else {
                                player.play()
                            }
                        } label: {
                            Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(.white)
                                .frame(width: 68, height: 68)
                                .background(DS.Colors.primary)
                                .clipShape(Circle())
                        }
                        .buttonStyle(DSSpringButtonStyle())

                        Button {
                            Haptics.light()
                            player.next()
                        } label: {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.primary)
                        }

                        Button {
                            Haptics.light()
                            player.isLoop.toggle()
                        } label: {
                            Image(systemName: "repeat")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(player.isLoop ? DS.Colors.primary : .secondary)
                        }
                    }

                    // Pause interval selector
                    HStack {
                        Text("Pause")
                            .font(.dsCaption)
                            .foregroundStyle(.secondary)
                        Picker("Pause", selection: $player.delayInterval) {
                            Text("0.8s").tag(0.8)
                            Text("1.2s").tag(1.2)
                            Text("2.0s").tag(2.0)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal, DS.Spacing.md)
                }
                .padding(.bottom, DS.Spacing.lg)
            }
        }
        .background(DS.Surfaces.canvas.ignoresSafeArea())
        .navigationTitle("Auto Audio")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let resolved = PracticePoolResolver.resolveWords(from: allWords, config: config)
            player.setup(words: resolved)
        }
        .onDisappear {
            player.pause()
            if !didRecordSession && !player.words.isEmpty && player.currentIndex > 0 {
                didRecordSession = true
                SessionRecorder.record(count: player.currentIndex + 1, category: .audioListening, in: modelContext)
            }
        }
    }
}
