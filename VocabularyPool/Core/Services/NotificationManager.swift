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
    
    // UserDefaults keys
    private let dailyReminderEnabledKey = "dailyReminderEnabled"
    private let dailyReminderHourKey = "dailyReminderHour"
    private let dailyReminderMinuteKey = "dailyReminderMinute"
    
    // Notification identifiers
    private let dailyReminderIdentifier = "dailyReminder"
    private let wordReminder13Identifier = "wordReminder_13"
    private let wordReminder20Identifier = "wordReminder_20"
    private let dailySummaryIdentifier = "dailySummary"
    
    @Published var isDailyReminderEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isDailyReminderEnabled, forKey: dailyReminderEnabledKey)
            if isDailyReminderEnabled {
                scheduleDailyReminder()
            } else {
                cancelDailyReminder()
            }
        }
    }
    
    @Published var dailyReminderTime: Date {
        didSet {
            saveDailyReminderTime()
            if isDailyReminderEnabled {
                scheduleDailyReminder()
            }
        }
    }
    
    private init() {
        // Load saved settings
        self.isDailyReminderEnabled = UserDefaults.standard.bool(forKey: dailyReminderEnabledKey)
        
        // Load saved time or default to 9:00 AM
        let savedHour = UserDefaults.standard.integer(forKey: dailyReminderHourKey)
        let savedMinute = UserDefaults.standard.integer(forKey: dailyReminderMinuteKey)
        
        var components = DateComponents()
        components.hour = savedHour == 0 && !UserDefaults.standard.bool(forKey: "hasSetDailyReminderTime") ? 9 : savedHour
        components.minute = savedMinute
        
        self.dailyReminderTime = Calendar.current.date(from: components) ?? Date()
    }
    
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
    
    // MARK: - Daily Reminder
    
    private func saveDailyReminderTime() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: dailyReminderTime)
        UserDefaults.standard.set(components.hour ?? 9, forKey: dailyReminderHourKey)
        UserDefaults.standard.set(components.minute ?? 0, forKey: dailyReminderMinuteKey)
        UserDefaults.standard.set(true, forKey: "hasSetDailyReminderTime")
    }
    
    func scheduleDailyReminder() {
        // Cancel existing daily reminder first
        cancelDailyReminder()
        
        let content = UNMutableNotificationContent()
        content.title = "📚 Kelime Zamanı!"
        content.body = "Bugün kelime pratiği yapmayı unutma!"
        content.sound = .default
        
        // Get hour and minute from the reminder time
        let components = Calendar.current.dateComponents([.hour, .minute], from: dailyReminderTime)
        
        var dateComponents = DateComponents()
        dateComponents.hour = components.hour
        dateComponents.minute = components.minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderIdentifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule daily reminder: \(error)")
            } else {
                print("Daily reminder scheduled for \(components.hour ?? 0):\(components.minute ?? 0)")
            }
        }
    }
    
    func cancelDailyReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
    }
    
    // MARK: - Custom Notifications
    
    func scheduleCustomNotification(id: UUID, title: String, body: String, hour: Int, minute: Int, weekdays: [Int]) {
        // Cancel existing notifications for this ID first
        cancelCustomNotification(id: id)
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        if weekdays.isEmpty {
            // One-time notification (next occurrence of this time)
            var dateComponents = DateComponents()
            dateComponents.hour = hour
            dateComponents.minute = minute
            
            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(identifier: id.uuidString, content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Failed to schedule custom notification: \(error)")
                }
            }
        } else {
            // Schedule for each selected weekday
            for weekday in weekdays {
                var dateComponents = DateComponents()
                dateComponents.hour = hour
                dateComponents.minute = minute
                dateComponents.weekday = weekday
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let identifier = "\(id.uuidString)_\(weekday)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                
                UNUserNotificationCenter.current().add(request) { error in
                    if let error = error {
                        print("Failed to schedule custom notification for weekday \(weekday): \(error)")
                    }
                }
            }
        }
    }
    
    func cancelCustomNotification(id: UUID) {
        // Cancel all notifications for this ID (including weekday variants)
        var identifiers = [id.uuidString]
        for weekday in 1...7 {
            identifiers.append("\(id.uuidString)_\(weekday)")
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    // MARK: - Word Addition Reminders
    
    /// Schedule word reminder notifications based on tracker status
    func scheduleWordReminderNotifications(for tracker: WordAdditionTracker) {
        // Cancel existing reminders first
        cancelWordReminderNotifications()
        
        // If goal is already completed, don't schedule reminders
        if tracker.isCurrentPeriodCompleted {
            return
        }
        
        // If we're past the deadline, schedule reminders for today
        if tracker.shouldSendReminders {
            scheduleReminderForToday(at: 13, identifier: wordReminder13Identifier)
            scheduleReminderForToday(at: 20, identifier: wordReminder20Identifier)
        } else {
            // Schedule reminders for the deadline date
            scheduleReminderForDate(tracker.nextDeadlineDate, at: 13, identifier: wordReminder13Identifier)
            scheduleReminderForDate(tracker.nextDeadlineDate, at: 20, identifier: wordReminder20Identifier)
        }
    }
    
    /// Cancel word reminder notifications
    func cancelWordReminderNotifications() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [wordReminder13Identifier, wordReminder20Identifier]
        )
    }
    
    /// Schedule a reminder for today at a specific hour
    private func scheduleReminderForToday(at hour: Int, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "📚 Kelime Ekleme Zamanı!"
        content.body = "Bu hafta 10 kelime ekleme hedefinizi tamamlamayı unutmayın!"
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule word reminder for today at \(hour):00 - \(error)")
            } else {
                print("Word reminder scheduled for today at \(hour):00")
            }
        }
    }
    
    /// Schedule a reminder for a specific date at a specific hour
    private func scheduleReminderForDate(_ date: Date, at hour: Int, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = "📚 Kelime Ekleme Zamanı!"
        content.body = "Bu hafta 10 kelime ekleme hedefinizi tamamlamayı unutmayın!"
        content.sound = .default
        
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.hour = hour
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule word reminder for \(date) at \(hour):00 - \(error)")
            } else {
                print("Word reminder scheduled for \(date) at \(hour):00")
            }
        }
    }
    
    // MARK: - Daily Practice Summary
    
    /// Schedule a daily notification at 23:55 to summarize the day's practice exercises
    func scheduleDailySummaryNotification() {
        // Cancel existing daily summary notification first
        cancelDailySummaryNotification()
        
        // Schedule for 23:55 every day
        var dateComponents = DateComponents()
        dateComponents.hour = 23
        dateComponents.minute = 55
        
        let content = UNMutableNotificationContent()
        content.title = "📊 Günlük Özet"
        content.body = "Bugün yaptığın alıştırmaları kontrol et!"
        content.sound = .default
        content.categoryIdentifier = "DAILY_SUMMARY"
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: dailySummaryIdentifier, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule daily summary notification: \(error)")
            } else {
                print("Daily summary notification scheduled for 23:55")
            }
        }
    }
    
    /// Manually send a daily summary notification with the actual practice count
    func sendDailySummaryNotification(practiceCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = "📊 Günlük Özet"
        
        if practiceCount == 0 {
            content.body = "Bugün hiç kelime alıştırması yapmadın."
        } else if practiceCount == 1 {
            content.body = "Bugün 1 kelime alıştırması yaptın! 🎉"
        } else {
            content.body = "Bugün \(practiceCount) kelime alıştırması yaptın! 🎉"
        }
        
        content.sound = .default
        
        // Schedule for immediate delivery
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "dailySummary_now", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send daily summary notification: \(error)")
            }
        }
    }
    
    /// Cancel the daily summary notification
    func cancelDailySummaryNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailySummaryIdentifier])
    }
    
    // MARK: - Utility
    
    func listPendingNotifications(completion: @escaping ([UNNotificationRequest]) -> Void) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            DispatchQueue.main.async {
                completion(requests)
            }
        }
    }
    
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
