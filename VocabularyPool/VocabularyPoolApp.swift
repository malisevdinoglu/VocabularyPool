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
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Word.self,
            PracticeSession.self,
            CustomNotification.self,
            WordAdditionTracker.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Request notification permission on app launch
                    NotificationManager.shared.requestPermission { granted in
                        print("Notification permission granted: \(granted)")
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
}
