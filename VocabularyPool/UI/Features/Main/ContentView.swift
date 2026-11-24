//
//  ContentView.swift
//  VocabularyPool
//
//  Clean 3-Tab Application Shell: Today • Pool • Practice
//  Single NavigationStack per tab (no nested stacks) and global Quick-Add Word sheet.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Query private var words: [Word]
    @AppStorage("appThemeMode") private var appThemeMode: String = "system"
    @State private var selectedTab = 0
    @State private var showingAddWordSheet = false

    private var preferredScheme: ColorScheme? {
        switch appThemeMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayView(onTapAddWord: { showingAddWordSheet = true })
            }
            .tabItem {
                Label("Today", systemImage: "sun.max.fill")
            }
            .tag(0)

            NavigationStack {
                PoolView(onTapAddWord: { showingAddWordSheet = true })
            }
            .tabItem {
                Label("Pool", systemImage: "books.vertical.fill")
            }
            .tag(1)

            NavigationStack {
                PracticeView(onTapAddWord: { showingAddWordSheet = true })
            }
            .tabItem {
                Label("Practice", systemImage: "bolt.fill")
            }
            .tag(2)
        }
        .tint(DS.Colors.primary)
        .preferredColorScheme(preferredScheme)
        .sheet(isPresented: $showingAddWordSheet) {
            AddWordView()
                .preferredColorScheme(preferredScheme)
        }
        .onAppear {
            NotificationManager.shared.scheduleHourlyWeakWordNotifications(words: words)
        }
        .onChange(of: words.count) { _, _ in
            NotificationManager.shared.scheduleHourlyWeakWordNotifications(words: words)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Word.self, PracticeSession.self], inMemory: true)
}
