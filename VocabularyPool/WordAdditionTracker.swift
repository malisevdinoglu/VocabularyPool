//
//  WordAdditionTracker.swift
//  VocabularyPool
//
//  Created by Assistant on 08.01.2026.
//

import Foundation
import SwiftData

@Model
final class WordAdditionTracker {
    var lastCompletionDate: Date
    var nextDeadlineDate: Date
    var currentPeriodWordCount: Int
    var wordsAddedToday: Int
    var lastWordAddedDate: Date?
    
    init(lastCompletionDate: Date = Date(), nextDeadlineDate: Date? = nil) {
        self.lastCompletionDate = lastCompletionDate
        
        // Calculate next deadline (2 days from last completion)
        if let nextDeadline = nextDeadlineDate {
            self.nextDeadlineDate = nextDeadline
        } else {
            self.nextDeadlineDate = Calendar.current.date(byAdding: .day, value: 2, to: lastCompletionDate) ?? Date()
        }
        
        self.currentPeriodWordCount = 0
        self.wordsAddedToday = 0
        self.lastWordAddedDate = nil
    }
    
    /// Check if we need to reset daily counter
    func checkAndResetDailyCounter() {
        guard let lastAdded = lastWordAddedDate else { return }
        
        let calendar = Calendar.current
        if !calendar.isDate(lastAdded, inSameDayAs: Date()) {
            wordsAddedToday = 0
        }
    }
    
    /// Add a word to the tracker
    func addWord() {
        checkAndResetDailyCounter()
        currentPeriodWordCount += 1
        wordsAddedToday += 1
        lastWordAddedDate = Date()
    }
    
    /// Check if the current period goal is completed (10 words)
    var isCurrentPeriodCompleted: Bool {
        return currentPeriodWordCount >= 10
    }
    
    /// Start a new period
    func startNewPeriod() {
        lastCompletionDate = Date()
        nextDeadlineDate = Calendar.current.date(byAdding: .day, value: 2, to: lastCompletionDate) ?? Date()
        currentPeriodWordCount = 0
    }
    
    /// Check if we're past the deadline
    var isPastDeadline: Bool {
        return Date() >= nextDeadlineDate
    }
    
    /// Check if we should send reminders (past deadline and not completed)
    var shouldSendReminders: Bool {
        return isPastDeadline && !isCurrentPeriodCompleted
    }
}
