//
//  Word.swift
//  VocabularyPool
//
//  Created by Assistant on 02.01.2026.
//

import Foundation
import SwiftData

@Model
final class Word {
    var english: String
    var turkish: String
    var englishAlt: String?
    var turkishAlt: String?
    var correctCount: Int
    var wrongCount: Int
    var lastStudied: Date?
    var timestamp: Date

    /// True when the word is currently in the Weak / Needs Review state.
    /// Set to true on any wrong answer; cleared after 3 consecutive correct answers.
    var needsReview: Bool = false

    /// Verb conjugation fields (V2 / V3 optional on any word)
    var isVerb: Bool = false
    var v2: String?
    var v3: String?

    /// Phrasal verb tag
    var isPhrasalVerb: Bool = false

    // MARK: - Schema V6 Fields (Lightweight Migration Safe Primitives)

    /// Newline-delimited additional Turkish meanings beyond `turkish` and `turkishAlt`.
    var additionalTurkishRaw: String = ""

    /// Consecutive correct answers in a row. Reaching 3 graduates the word out of Weak status.
    var consecutiveCorrect: Int = 0

    /// Mastery level from 0 (new) to 5 (mastered).
    var masteryLevel: Int = 0

    /// Current SRS review interval in days.
    var intervalDays: Int = 0

    /// Next scheduled SRS review date.
    var nextReviewDate: Date? = nil

    init(
        english: String,
        turkish: String,
        englishAlt: String? = nil,
        turkishAlt: String? = nil,
        additionalTurkish: [String] = [],
        isVerb: Bool = false,
        isPhrasalVerb: Bool = false,
        v2: String? = nil,
        v3: String? = nil,
        timestamp: Date = Date()
    ) {
        self.english = english
        self.turkish = turkish
        self.englishAlt = englishAlt
        self.turkishAlt = turkishAlt
        self.additionalTurkishRaw = additionalTurkish
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        self.isVerb = isVerb
        self.isPhrasalVerb = isPhrasalVerb
        self.v2 = v2
        self.v3 = v3
        self.correctCount = 0
        self.wrongCount = 0
        self.lastStudied = nil
        self.timestamp = timestamp
        self.needsReview = false
        self.consecutiveCorrect = 0
        self.masteryLevel = 0
        self.intervalDays = 0
        self.nextReviewDate = nil
    }
}

// MARK: - Computed Helpers

extension Word {

    /// All Turkish meanings combined from `turkish`, `turkishAlt`, and `additionalTurkishRaw` (deduplicated).
    var allTurkishMeanings: [String] {
        var result: [String] = []
        var seen = Set<String>()

        func appendIfValid(_ raw: String?) {
            guard let raw else { return }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                result.append(trimmed)
            }
        }

        appendIfValid(turkish)
        appendIfValid(turkishAlt)
        if !additionalTurkishRaw.isEmpty {
            for part in additionalTurkishRaw.components(separatedBy: "\n") {
                appendIfValid(part)
            }
        }
        return result
    }

    /// Replaces all Turkish meanings cleanly while keeping `turkish` and `turkishAlt` synchronized for backward compatibility.
    func setTurkishMeanings(_ meanings: [String]) {
        var cleaned: [String] = []
        var seen = Set<String>()
        for item in meanings {
            let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed.lowercased()).inserted {
                cleaned.append(trimmed)
            }
        }

        self.turkish = cleaned.first ?? ""
        self.turkishAlt = cleaned.count > 1 ? cleaned[1] : nil
        self.additionalTurkishRaw = cleaned.count > 2
            ? cleaned.dropFirst(2).joined(separator: "\n")
            : ""
    }

    /// Appends one or more Turkish meanings without duplicates.
    func appendTurkishMeanings(_ newMeanings: [String]) {
        let merged = allTurkishMeanings + newMeanings
        setTurkishMeanings(merged)
    }

    /// Compact dot-separated display string (e.g. "koşmak • işletmek • çalışmak").
    var formattedTurkishMeanings: String {
        allTurkishMeanings.joined(separator: " • ")
    }

    /// All English forms (`english` + optional `englishAlt`).
    var allEnglishForms: [String] {
        var forms = [english.trimmingCharacters(in: .whitespacesAndNewlines)]
        if let alt = englishAlt?.trimmingCharacters(in: .whitespacesAndNewlines), !alt.isEmpty {
            forms.append(alt)
        }
        return forms
    }

    /// Lifetime accuracy rate (0.0...1.0), or nil if never studied.
    var accuracyRate: Double? {
        let total = correctCount + wrongCount
        guard total > 0 else { return nil }
        return Double(correctCount) / Double(total)
    }

    /// True if the word has never been studied yet.
    var isNew: Bool {
        correctCount == 0 && wrongCount == 0
    }

    /// True if the word is currently flagged as weak / needs review.
    var isWeak: Bool {
        needsReview
    }

    /// True if the word is due for SRS review right now.
    var isDueForReview: Bool {
        if needsReview { return true }
        if let nextDate = nextReviewDate {
            return nextDate <= Date()
        }
        return false
    }

    /// True if the word has irregular verb conjugations (V2 & V3).
    var hasConjugations: Bool {
        let hasV2 = !(v2?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasV3 = !(v3?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return isVerb || (hasV2 && hasV3)
    }
}
