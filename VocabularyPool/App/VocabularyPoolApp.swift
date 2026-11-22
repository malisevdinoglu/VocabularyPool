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
            print("⚠️ MigrationPlan Container failed: \(error). Trying automatic lightweight migration...")
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
            } catch {
                print("⚠️ Automatic migration failed: \(error). Initializing basic fallback ModelContainer...")
                do {
                    return try ModelContainer(for: schema)
                } catch {
                    fatalError("Critical: Could not create ModelContainer: \(error)")
                }
            }
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
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
