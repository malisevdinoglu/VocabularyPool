//
//  PracticeConfigView.swift
//  VocabularyPool
//
//  Created by Assistant on 02.01.2026.
//

import SwiftUI
import SwiftData

struct PracticeConfigView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var words: [Word]
    
    @State private var count = 10
    @State private var type: PracticeType = .englishToTurkish
    @State private var useWordRange = false
    @State private var fromText = ""
    @State private var toText = ""
    @State private var showingQuiz = false
    @State private var showingSettings = false
    
    enum PracticeType: String, CaseIterable, Identifiable {
        case englishToTurkish = "English -> Turkish"
        case turkishToEnglish = "Turkish -> English"
        case listening = "Listening (Write what you hear)"
        
        var id: String { self.rawValue }
    }
    
    var totalWords: Int {
        words.count
    }
    
    var wordRangeStart: Int? {
        guard useWordRange, let from = Int(fromText), from > 0 else { return nil }
        return from
    }
    
    var wordRangeEnd: Int? {
        guard useWordRange, let to = Int(toText), to > 0 else { return nil }
        return to
    }
    
    var isRangeValid: Bool {
        if !useWordRange { return true }
        
        guard let from = wordRangeStart, let to = wordRangeEnd else {
            return false
        }
        
        return from <= to && from <= totalWords && to <= totalWords
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Word Pool")) {
                    Text("Total Words: \(totalWords)")
                        .font(.headline)
                    
                    Toggle("Select Word Range", isOn: $useWordRange)
                    
                    if useWordRange {
                        HStack {
                            Text("From:")
                            TextField("1", text: $fromText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: fromText) { oldValue, newValue in
                                    // Filter non-numeric characters
                                    fromText = newValue.filter { $0.isNumber }
                                }
                        }
                        
                        HStack {
                            Text("To:")
                            TextField("\(totalWords)", text: $toText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .onChange(of: toText) { oldValue, newValue in
                                    // Filter non-numeric characters
                                    toText = newValue.filter { $0.isNumber }
                                }
                        }
                        
                        if !isRangeValid {
                            Text("⚠️ Invalid range. From must be ≤ To and both must be ≤ \(totalWords)")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                
                Section(header: Text("Settings")) {
                    Picker("Number of Questions", selection: $count) {
                        ForEach([5, 10, 15, 20, 25, 30], id: \.self) { num in
                            Text("\(num)").tag(num)
                        }
                    }
                    
                    Picker("Practice Type", selection: $type) {
                        Text("English → Turkish").tag(PracticeType.englishToTurkish)
                        Text("Turkish → English").tag(PracticeType.turkishToEnglish)
                        Text("Listening Challenge").tag(PracticeType.listening)
                    }
                }
            }
            .navigationTitle("Setup Practice")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    showingQuiz = true
                } label: {
                    Text("Start Practice")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(words.isEmpty || !isRangeValid ? Color.gray : Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .disabled(words.isEmpty || !isRangeValid)
                .padding()
                .background(Color(uiColor: .systemBackground))
            }
            .navigationDestination(isPresented: $showingQuiz) {
                QuizView(config: QuizConfig(
                    count: count,
                    type: type,
                    wordRangeStart: wordRangeStart,
                    wordRangeEnd: wordRangeEnd
                ))
            }
        }
    }
}

struct QuizConfig {
    var count: Int
    var type: PracticeConfigView.PracticeType
    var wordRangeStart: Int?
    var wordRangeEnd: Int?
}

#Preview {
    NavigationStack {
        PracticeConfigView()
            .modelContainer(for: Word.self, inMemory: true)
    }
}
