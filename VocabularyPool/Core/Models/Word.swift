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
    /// Set to true when answered incorrectly in a quiz session.
    /// Reset to false when answered correctly in any subsequent session.
    var needsReview: Bool = false
    
    /// Verb conjugation fields
    var isVerb: Bool = false
    var v2: String?
    var v3: String?

    /// Phrasal verb field
    var isPhrasalVerb: Bool = false

    init(
        english: String,
        turkish: String,
        englishAlt: String? = nil,
        turkishAlt: String? = nil,
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
        self.isVerb = isVerb
        self.isPhrasalVerb = isPhrasalVerb
        self.v2 = v2
        self.v3 = v3
        self.correctCount = 0
        self.wrongCount = 0
        self.lastStudied = nil
        self.timestamp = timestamp
        self.needsReview = false
    }
}
