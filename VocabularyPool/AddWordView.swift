//
//  AddWordView.swift
//  VocabularyPool
//
//  Created by Assistant on 02.01.2026.
//

import SwiftUI
import SwiftData

struct AddWordView: View {
    @Environment(\.modelContext) private var modelContext
    
    @State private var english = ""
    @State private var turkish = ""
    @State private var englishAlt = ""
    @State private var turkishAlt = ""
    @State private var showAlternatives = false
    @State private var showSuccessSheet = false
    @State private var selectedTab: Int?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Primary Meanings")) {
                    TextField("English", text: $english)
                        .textInputAutocapitalization(.never)
                    TextField("Turkish", text: $turkish)
                        .textInputAutocapitalization(.never)
                }
                
                Section {
                    DisclosureGroup("Alternative Meanings (Optional)", isExpanded: $showAlternatives) {
                        TextField("Alternative English", text: $englishAlt)
                            .textInputAutocapitalization(.never)
                        TextField("Alternative Turkish", text: $turkishAlt)
                            .textInputAutocapitalization(.never)
                    }
                }
            }
            .navigationTitle("Add New Word")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWord()
                    }
                    .disabled(english.isEmpty || turkish.isEmpty)
                }
            }
            .sheet(isPresented: $showSuccessSheet) {
                SuccessView(
                    onAddAnother: {
                        showSuccessSheet = false
                        clearForm()
                    },
                    onGoToVocabulary: {
                        showSuccessSheet = false
                        // Switch to vocabulary tab (tab index 0)
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToVocabularyTab"), object: nil)
                    }
                )
            }
            .onDisappear {
                // Clear form when navigating away from this tab
                clearForm()
            }
        }
    }
    
    private func saveWord() {
        let newWord = Word(
            english: english,
            turkish: turkish,
            englishAlt: englishAlt.isEmpty ? nil : englishAlt,
            turkishAlt: turkishAlt.isEmpty ? nil : turkishAlt
        )
        modelContext.insert(newWord)
        
        // Update word addition tracker
        updateWordTracker()
        
        showSuccessSheet = true
    }
    
    /// Update word addition tracker and manage notifications
    private func updateWordTracker() {
        // Fetch the tracker
        let descriptor = FetchDescriptor<WordAdditionTracker>()
        guard let tracker = try? modelContext.fetch(descriptor).first else {
            return
        }
        
        // Add word to tracker
        tracker.addWord()
        
        // Check if goal is completed
        if tracker.isCurrentPeriodCompleted {
            // Cancel reminders since goal is achieved
            NotificationManager.shared.cancelWordReminderNotifications()
            
            // Start new period
            tracker.startNewPeriod()
            
            // Schedule reminders for the new period
            NotificationManager.shared.scheduleWordReminderNotifications(for: tracker)
            
            print("✅ 10 kelime hedefi tamamlandı! Yeni periyot başlatıldı.")
        } else {
            // Update notifications based on current status
            NotificationManager.shared.scheduleWordReminderNotifications(for: tracker)
        }
        
        // Save context
        try? modelContext.save()
    }
    
    private func clearForm() {
        english = ""
        turkish = ""
        englishAlt = ""
        turkishAlt = ""
        showAlternatives = false
    }
}

struct SuccessView: View {
    let onAddAnother: () -> Void
    let onGoToVocabulary: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)
            
            Text("Kelime Başarıyla Eklendi!")
                .font(.title2)
                .bold()
            
            VStack(spacing: 16) {
                Button {
                    onAddAnother()
                } label: {
                    Text("Yeni Kelime Ekle")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                
                Button {
                    onGoToVocabulary()
                } label: {
                    Text("Kelimelerime Git")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .foregroundStyle(.primary)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .presentationDetents([.medium])
    }
}

#Preview {
    AddWordView()
        .modelContainer(for: Word.self, inMemory: true)
}
