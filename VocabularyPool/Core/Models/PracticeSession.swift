//
//  PracticeSession.swift
//  VocabularyPool
//
//  Created by Assistant on 05.01.2026.
//
import Foundation
import SwiftData

/// PracticeSession, bir gün içindeki çalışma oturumunu temsil eden kalıcı bir modeldir.
@Model
final class PracticeSession {
    
    var date: Date
    var englishToTurkishCount: Int
    var turkishToEnglishCount: Int
    var listeningCount: Int = 0
    var audioListeningCount: Int = 0
    var flashcardsCount: Int = 0
    var matchingCount: Int = 0
    
    // Legacy goal snapshots preserved for schema compatibility
    var dailyGoalEngToTr: Int = 0
    var dailyGoalTrToEng: Int = 0
    var dailyGoalListening: Int = 0
    
    init(
        date: Date = Date(),
        englishToTurkishCount: Int = 0,
        turkishToEnglishCount: Int = 0,
        listeningCount: Int = 0,
        audioListeningCount: Int = 0,
        flashcardsCount: Int = 0,
        matchingCount: Int = 0,
        dailyGoalEngToTr: Int = 0,
        dailyGoalTrToEng: Int = 0,
        dailyGoalListening: Int = 0
    ) {
        self.date = date
        self.englishToTurkishCount = englishToTurkishCount
        self.turkishToEnglishCount = turkishToEnglishCount
        self.listeningCount = listeningCount
        self.audioListeningCount = audioListeningCount
        self.flashcardsCount = flashcardsCount
        self.matchingCount = matchingCount
        self.dailyGoalEngToTr = dailyGoalEngToTr
        self.dailyGoalTrToEng = dailyGoalTrToEng
        self.dailyGoalListening = dailyGoalListening
    }
}
