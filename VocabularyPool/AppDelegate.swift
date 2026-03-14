//
//  AppDelegate.swift
//  VocabularyPool
//
//  Created by Assistant on 24.01.2026.
//

import UIKit
import UserNotifications
import SwiftData

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var modelContainer: ModelContainer?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // This method is called when a notification is about to be delivered
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // Check if this is the daily summary notification
        if notification.request.identifier == "dailySummary" {
            // Cancel the original notification and send a new one with today's count
            replaceDailySummaryNotification()
            // Don't show the original notification
            completionHandler([])
        } else {
            // Show other notifications normally
            completionHandler([.banner, .sound, .badge])
        }
    }
    
    // This method is called when the user taps on a notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        completionHandler()
    }
    
    /// Replace the daily summary notification with actual practice count
    private func replaceDailySummaryNotification() {
        guard let container = modelContainer else {
            // If container is not available, send with 0 count
            NotificationManager.shared.sendDailySummaryNotification(practiceCount: 0)
            return
        }
        
        // Calculate today's practice count
        let context = ModelContext(container)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        
        // Create a fetch descriptor for today's practice sessions
        let descriptor = FetchDescriptor<PracticeSession>(
            predicate: #Predicate { session in
                session.date >= today && session.date < tomorrow
            }
        )
        
        do {
            let sessions = try context.fetch(descriptor)
            
            // Calculate total practice count (sum of all exercise types)
            let totalCount = sessions.reduce(0) { total, session in
                total + session.englishToTurkishCount + session.turkishToEnglishCount + session.listeningCount
            }
            
            // Send notification with the actual count
            NotificationManager.shared.sendDailySummaryNotification(practiceCount: totalCount)
        } catch {
            print("Failed to fetch practice sessions: \(error)")
            NotificationManager.shared.sendDailySummaryNotification(practiceCount: 0)
        }
    }
}
