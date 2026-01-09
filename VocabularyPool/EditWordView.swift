//
//  EditWordView.swift
//  VocabularyPool
//
//  Created by Assistant on 04.01.2026.
//

import SwiftUI
import SwiftData

struct EditWordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var word: Word
    
    @State private var showAlternatives = false
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Primary Meanings")) {
                    TextField("English", text: $word.english)
                        .textInputAutocapitalization(.never)
                    TextField("Turkish", text: $word.turkish)
                        .textInputAutocapitalization(.never)
                }
                
                Section {
                    DisclosureGroup("Alternative Meanings (Optional)", isExpanded: $showAlternatives) {
                        TextField("Alternative English", text: Binding(
                            get: { word.englishAlt ?? "" },
                            set: { word.englishAlt = $0.isEmpty ? nil : $0 }
                        ))
                        .textInputAutocapitalization(.never)
                        
                        TextField("Alternative Turkish", text: Binding(
                            get: { word.turkishAlt ?? "" },
                            set: { word.turkishAlt = $0.isEmpty ? nil : $0 }
                        ))
                        .textInputAutocapitalization(.never)
                    }
                }
                
                Section(header: Text("Statistics")) {
                    HStack {
                        Text("Correct Answers")
                        Spacer()
                        Text("\(word.correctCount)")
                            .foregroundStyle(.green)
                    }
                    HStack {
                        Text("Wrong Answers")
                        Spacer()
                        Text("\(word.wrongCount)")
                            .foregroundStyle(.red)
                    }
                    if let lastStudied = word.lastStudied {
                        HStack {
                            Text("Last Studied")
                            Spacer()
                            Text(lastStudied, style: .date)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Text("Added On")
                        Spacer()
                        Text(word.timestamp, format: .dateTime.day().month().year().hour().minute())
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit Word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .disabled(word.english.isEmpty || word.turkish.isEmpty)
                }
                
                ToolbarItem(placement: .bottomBar) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Word", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .alert("Delete Word?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    modelContext.delete(word)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this word? This action cannot be undone.")
            }
            .onAppear {
                // Expand alternatives section if there are any alternative meanings
                if (word.englishAlt != nil && !word.englishAlt!.isEmpty) ||
                   (word.turkishAlt != nil && !word.turkishAlt!.isEmpty) {
                    showAlternatives = true
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Word.self, configurations: config)
    let word = Word(english: "book", turkish: "kitap", englishAlt: "reserve", turkishAlt: "rezerve etmek")
    container.mainContext.insert(word)
    
    return EditWordView(word: word)
        .modelContainer(container)
}
