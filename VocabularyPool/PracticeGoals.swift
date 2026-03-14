//
//  PracticeGoals.swift
//  VocabularyPool
//
//  Created by Assistant on 02.02.2026.
//

import Foundation
import Combine

enum GoalStatus: Equatable {
    case noGoals
    case allCompleted
    case partial(completed: Int, total: Int)
    case none
}

@MainActor
class PracticeGoals: ObservableObject {
    static let shared = PracticeGoals()
    
    @Published var englishToTurkishGoal: Int = 0
    @Published var turkishToEnglishGoal: Int = 0
    @Published var listeningGoal: Int = 0
    @Published var currentWeekStart: Date = Date()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let englishToTurkish = "dailyGoalEnglishToTurkish"
        static let turkishToEnglish = "dailyGoalTurkishToEnglish"
        static let listening = "dailyGoalListening"
        static let weekStart = "currentWeekStart"
    }
    
    init() {
        loadGoals()
    }
    
    func loadGoals() {
        englishToTurkishGoal = defaults.integer(forKey: Keys.englishToTurkish)
        turkishToEnglishGoal = defaults.integer(forKey: Keys.turkishToEnglish)
        listeningGoal = defaults.integer(forKey: Keys.listening)
        
        // Load week start, if not set use current week
        if let savedWeekStart = defaults.object(forKey: Keys.weekStart) as? Date {
            currentWeekStart = savedWeekStart
        } else {
            currentWeekStart = getWeekStart()
            updateWeekStart()
        }
    }
    
    func saveGoals() {
        defaults.set(englishToTurkishGoal, forKey: Keys.englishToTurkish)
        defaults.set(turkishToEnglishGoal, forKey: Keys.turkishToEnglish)
        defaults.set(listeningGoal, forKey: Keys.listening)
        updateWeekStart()
    }
    
    func hasAnyGoals() -> Bool {
        englishToTurkishGoal > 0 || turkishToEnglishGoal > 0 || listeningGoal > 0
    }
    
    // Hedef tamamlanma kontrolü
    func checkGoalCompletion(engToTr: Int, trToEng: Int, listening: Int) -> GoalStatus {
        guard hasAnyGoals() else { return .noGoals }
        
        var completedCount = 0
        var totalGoals = 0
        
        if englishToTurkishGoal > 0 {
            totalGoals += 1
            if engToTr >= englishToTurkishGoal { completedCount += 1 }
        }
        
        if turkishToEnglishGoal > 0 {
            totalGoals += 1
            if trToEng >= turkishToEnglishGoal { completedCount += 1 }
        }
        
        if listeningGoal > 0 {
            totalGoals += 1
            if listening >= listeningGoal { completedCount += 1 }
        }
        
        if completedCount == totalGoals {
            return .allCompleted
        } else if completedCount > 0 {
            return .partial(completed: completedCount, total: totalGoals)
        } else {
            return .none
        }
    }
    
    // Haftanın başlangıcını hesapla (Pazartesi)
    func getWeekStart(for date: Date = Date()) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        components.weekday = 2 // Pazartesi
        return calendar.date(from: components) ?? date
    }
    
    // Yeni hafta mı kontrol et
    func isNewWeek() -> Bool {
        let currentWeekStartCalculated = getWeekStart()
        return !Calendar.current.isDate(currentWeekStart, equalTo: currentWeekStartCalculated, toGranularity: .day)
    }
    
    // Hafta başlangıcını güncelle
    func updateWeekStart() {
        currentWeekStart = getWeekStart()
        defaults.set(currentWeekStart, forKey: Keys.weekStart)
    }
    
    // Hafta sonu tarihi
    func getWeekEnd() -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 6, to: currentWeekStart) ?? currentWeekStart
    }
}
