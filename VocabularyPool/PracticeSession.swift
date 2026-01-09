//
//  PracticeSession.swift
//  VocabularyPool
//
//  Created by Assistant on 05.01.2026.
//

import Foundation
import SwiftData

@Model
final class PracticeSession {
    var date: Date
    var englishToTurkishCount: Int
    var turkishToEnglishCount: Int
    var listeningCount: Int = 0
    
    init(date: Date = Date(), englishToTurkishCount: Int = 0, turkishToEnglishCount: Int = 0, listeningCount: Int = 0) {
        self.date = date
        self.englishToTurkishCount = englishToTurkishCount
        self.turkishToEnglishCount = turkishToEnglishCount
        self.listeningCount = listeningCount
    }
}
