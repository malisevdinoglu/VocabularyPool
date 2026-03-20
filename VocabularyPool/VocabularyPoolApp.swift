//
//  VocabularyPoolApp.swift
//  VocabularyPool
//
//  Created by Mehmet Ali Sevdinoğlu on 27.12.2025.
//

import SwiftUI
import SwiftData

@main
struct VocabularyPoolApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Word.self,
            PracticeSession.self,
            CustomNotification.self,
            WordAdditionTracker.self,
            
            
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: AppMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Pass model container to AppDelegate
                    appDelegate.modelContainer = sharedModelContainer
                    
                    // Request notification permission on app launch
                    NotificationManager.shared.requestPermission { granted in
                        print("Notification permission granted: \(granted)")
                        
                        // Schedule daily summary notification at 23:55
                        if granted {
                            NotificationManager.shared.scheduleDailySummaryNotification()
                            
                            // Check if we should send today's summary now
                            self.checkAndSendDailySummary()
                        }
                    }
                }
                .task {
                    // Initialize word addition tracker and schedule reminders
                    await initializeWordTracker()
                }
        }
        .modelContainer(sharedModelContainer)
    }
    
    /// Initialize word addition tracker and schedule notifications
    @MainActor
    private func initializeWordTracker() async {
        let context = sharedModelContainer.mainContext
        
        // Check if tracker exists
        let descriptor = FetchDescriptor<WordAdditionTracker>()
        let trackers = try? context.fetch(descriptor)
        
        let tracker: WordAdditionTracker
        if let existingTracker = trackers?.first {
            tracker = existingTracker
        } else {
            // Create new tracker with initial state
            // User mentioned they added words today (Jan 8, 2026)
            // So next deadline is Jan 10, 2026
            let today = Date()
            let nextDeadline = Calendar.current.date(byAdding: .day, value: 2, to: today) ?? today
            tracker = WordAdditionTracker(lastCompletionDate: today, nextDeadlineDate: nextDeadline)
            context.insert(tracker)
            try? context.save()
        }
        
        // Schedule notifications based on tracker status
        NotificationManager.shared.scheduleWordReminderNotifications(for: tracker)
    }
    
    /// Check and send daily summary notification if conditions are met
    private func checkAndSendDailySummary() {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute], from: now)
        
        guard let hour = components.hour, let minute = components.minute else { return }
        
        // Check if it's between 23:55 and 23:59
        if hour == 23 && minute >= 55 {
            // Get today's practice count and send notification
            sendDailySummaryForToday()
        }
    }
    
    /// Calculate and send today's practice summary notification
    @MainActor
    private func sendDailySummaryForToday() {
        let context = sharedModelContainer.mainContext
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
