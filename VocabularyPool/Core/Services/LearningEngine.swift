//
//  LearningEngine.swift
//  VocabularyPool
//
//  Central SRS, Weak-Word state machine, Smart Mix selector, typo-tolerant evaluator, and Streak engine.
//

import Foundation
import SwiftData

enum LearningEngine {

    /// Number of consecutive correct answers required to graduate out of Weak status.
    static let weakGraduationThreshold = 3

    /// Spaced repetition intervals (days) mapped by mastery level 1...5.
    private static let srsIntervals = [1, 3, 7, 14, 30]

    // MARK: - SRS & Weak-Word State Machine

    /// Records a correct answer for a word, advancing mastery and SRS interval.
    static func recordCorrect(for word: Word, now: Date = Date()) {
        word.correctCount += 1
        word.consecutiveCorrect += 1
        word.masteryLevel = min(5, word.masteryLevel + 1)
        word.lastStudied = now

        if word.consecutiveCorrect >= weakGraduationThreshold {
            word.needsReview = false
        }

        let intervalIndex = max(0, min(srsIntervals.count - 1, word.masteryLevel - 1))
        let days = word.needsReview ? 1 : srsIntervals[intervalIndex]
        word.intervalDays = days
        word.nextReviewDate = Calendar.current.date(byAdding: .day, value: days, to: now)
    }

    /// Records an incorrect answer, immediately flagging the word as Weak and resetting consecutive streak.
    static func recordWrong(for word: Word, now: Date = Date()) {
        word.wrongCount += 1
        word.needsReview = true
        word.consecutiveCorrect = 0
        word.masteryLevel = max(0, word.masteryLevel - 1)
        word.intervalDays = 1
        word.nextReviewDate = Calendar.current.date(byAdding: .day, value: 1, to: now)
        word.lastStudied = now
    }

    // MARK: - One-Time Legacy Bootstrap (Preserves Weak History on V5 → V6 Upgrade)

    private static let bootstrapKey = "didBootstrapV6WeakWords"

    @MainActor
    static func bootstrapLegacyWeakWordsIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: bootstrapKey) else { return }
        defer { UserDefaults.standard.set(true, forKey: bootstrapKey) }

        let descriptor = FetchDescriptor<Word>()
        guard let words = try? context.fetch(descriptor), !words.isEmpty else { return }

        var changed = false
        for word in words {
            let total = word.correctCount + word.wrongCount
            guard total > 0 else { continue }

            let rate = Double(word.correctCount) / Double(total)
            if word.wrongCount > 0 && rate < 0.70 {
                word.needsReview = true
                word.masteryLevel = min(word.masteryLevel, 1)
                changed = true
            } else if word.masteryLevel == 0 && rate >= 0.70 {
                // Hydrate sensible initial mastery for previously well-known words
                word.masteryLevel = min(5, max(1, word.correctCount / 2))
                changed = true
            }
        }

        if changed {
            try? context.save()
        }
    }

    // MARK: - Smart Mix Selector (50% Weak/Due + 30% New + 20% General)

    static func selectSmartMixWords(from allWords: [Word], count: Int) -> [Word] {
        guard !allWords.isEmpty, count > 0 else { return [] }

        let dueOrWeak = allWords.filter { $0.isDueForReview }.shuffled()
        let newWords = allWords.filter { $0.isNew && !$0.isDueForReview }.shuffled()
        let general = allWords.filter { !$0.isDueForReview && !$0.isNew }.shuffled()

        let weakTarget = Int((Double(count) * 0.50).rounded())
        let newTarget = Int((Double(count) * 0.30).rounded())
        let generalTarget = max(0, count - weakTarget - newTarget)

        var selected: [Word] = []
        var usedIDs = Set<PersistentIdentifier>()

        func appendUnique(from source: [Word], limit: Int) {
            var added = 0
            for word in source where added < limit {
                if usedIDs.insert(word.persistentModelID).inserted {
                    selected.append(word)
                    added += 1
                }
            }
        }

        appendUnique(from: dueOrWeak, limit: weakTarget)
        appendUnique(from: newWords, limit: newTarget)
        appendUnique(from: general, limit: generalTarget)

        // Backfill remaining slots in priority order: due/weak -> new -> general
        if selected.count < count {
            appendUnique(from: dueOrWeak, limit: count - selected.count)
        }
        if selected.count < count {
            appendUnique(from: newWords, limit: count - selected.count)
        }
        if selected.count < count {
            appendUnique(from: general, limit: count - selected.count)
        }

        return selected.shuffled()
    }

    // MARK: - Answer Evaluation (Multi-meaning + Typo Tolerance)

    struct EvaluationResult {
        let isCorrect: Bool
        let matchedAnswer: String?
        let wasTypoTolerated: Bool
    }

    static func evaluateAnswer(_ rawInput: String, against validAnswers: [String]) -> EvaluationResult {
        let normalizedInput = normalize(rawInput)
        guard !normalizedInput.isEmpty else {
            return EvaluationResult(isCorrect: false, matchedAnswer: nil, wasTypoTolerated: false)
        }

        // 1. Exact normalized match
        for answer in validAnswers {
            if normalizedInput == normalize(answer) {
                return EvaluationResult(isCorrect: true, matchedAnswer: answer, wasTypoTolerated: false)
            }
        }

        // 2. Typo tolerance: Levenshtein distance <= 1 for answers with >= 4 characters
        for answer in validAnswers {
            let normalizedAnswer = normalize(answer)
            if normalizedAnswer.count >= 4, levenshteinDistance(normalizedInput, normalizedAnswer) <= 1 {
                return EvaluationResult(isCorrect: true, matchedAnswer: answer, wasTypoTolerated: true)
            }
        }

        return EvaluationResult(isCorrect: false, matchedAnswer: nil, wasTypoTolerated: false)
    }

    static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: Locale(identifier: "tr_TR"))
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "tr_TR"))
    }

    /// Standard Levenshtein edit distance for single-character typo tolerance.
    static func levenshteinDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        if abs(a.count - b.count) > 1 { return abs(a.count - b.count) }

        var previous = Array(0...b.count)
        var current = Array(repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )
            }
            swap(&previous, &current)
        }
        return previous[b.count]
    }

    // MARK: - Daily Streak Calculation

    static func calculateStreak(from sessions: [PracticeSession], now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let activeDays = Set(
            sessions
                .filter { $0.totalCount > 0 }
                .map { calendar.startOfDay(for: $0.date) }
        )

        guard !activeDays.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return 0 }

        // Start counting from today if active today, otherwise from yesterday
        var cursor: Date
        if activeDays.contains(today) {
            cursor = today
        } else if activeDays.contains(yesterday) {
            cursor = yesterday
        } else {
            return 0
        }

        var streak = 0
        while activeDays.contains(cursor) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }
}
