//
//  NotificationManager.swift
//  VocabularyPool
//
//  Created by Assistant on 08.01.2026.
//

import Foundation
import UserNotifications
import Combine

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private let hourlyPrefix = "hourlyWeakWord_"
    
    private init() {}
    
    // MARK: - Permission
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Notification permission error: \(error)")
                }
                completion(granted)
            }
        }
    }
    
    func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }
    
    // MARK: - Hourly Weak Word Notifications
    
    /// Schedule hourly notifications at the top of the hour for weak words from pool
    func scheduleHourlyWeakWordNotifications(words: [Word]) {
        // Cancel previous hourly notifications
        cancelHourlyNotifications { [weak self] in
            guard let self = self else { return }
            
            // Filter weak words: wrongCount > 0 or accuracy <= 70%
            let weakWords = words.filter { word in
                let total = word.correctCount + word.wrongCount
                if word.wrongCount > 0 { return true }
                if total > 0 {
                    let rate = Double(word.correctCount) / Double(total)
                    return rate <= 0.70
                }
                return false
            }
            
            // Fallback to all words if there are no weak words yet
            let poolToUse = weakWords.isEmpty ? words : weakWords
            guard !poolToUse.isEmpty else { return }
            
            let shuffled = poolToUse.shuffled()
            let calendar = Calendar.current
            let now = Date()
            
            // Schedule for the next 24 upcoming hours (at the top of each hour: minute = 0)
            for hourOffset in 1...24 {
                guard let targetDate = calendar.date(byAdding: .hour, value: hourOffset, to: now) else { continue }
                
                var dateComponents = calendar.dateComponents([.year, .month, .day, .hour], from: targetDate)
                dateComponents.minute = 0
                dateComponents.second = 0
                
                let word = shuffled[(hourOffset - 1) % shuffled.count]
                
                let content = UNMutableNotificationContent()
                content.title = "\(word.english) ➔ \(word.turkish)"
                content.body = "💡 Saatlik kelime hatırlatıcısı! Zayıf kelimelerini pekiştirmek için pratik yap."
                content.sound = .default
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                let identifier = "\(self.hourlyPrefix)\(hourOffset)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Failed to schedule hourly notification for hour \(hourOffset): \(error)")
                    }
                }
            }
            print("✅ 24 saatlik zayıf kelime bildirimleri saat başlarına planlandı.")
        }
    }
    
    func cancelHourlyNotifications(completion: (() -> Void)? = nil) {
        var identifiers: [String] = []
        for i in 1...24 {
            identifiers.append("\(hourlyPrefix)\(i)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion?()
        }
    }
    
    // MARK: - Utility
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
