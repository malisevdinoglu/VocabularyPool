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
    
    init(english: String, turkish: String, englishAlt: String? = nil, turkishAlt: String? = nil, timestamp: Date = Date()) {
        self.english = english
        self.turkish = turkish
        self.englishAlt = englishAlt
        self.turkishAlt = turkishAlt
        self.correctCount = 0
        self.wrongCount = 0
        self.lastStudied = nil
        self.timestamp = timestamp
    }
}
