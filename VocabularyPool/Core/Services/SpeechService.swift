//
//  SpeechService.swift
//  VocabularyPool
//
//  Single shared AVSpeechSynthesizer service eliminating duplicated TTS setup across practice views.
//

import Foundation
import AVFoundation

@MainActor
final class SpeechService {
    static let shared = SpeechService()

    private let synthesizer = AVSpeechSynthesizer()

    private init() {}

    func configureAudioSession(soundEnabled: Bool) {
        do {
            if soundEnabled {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            } else {
                try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            }
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("SpeechService audio session error: \(error)")
        }
    }

    func speak(_ text: String, language: String = "en-US", rate: Float = 0.48) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = AVSpeechSynthesisVoice(language: language)
        utterance.rate = rate
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}
