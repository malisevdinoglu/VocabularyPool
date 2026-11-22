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
                Section(header: Text("Kelime Türü")) {
                    Picker("Tür", selection: Binding(
                        get: {
                            if word.isVerb { return 1 }
                            if word.isPhrasalVerb { return 2 }
                            return 0
                        },
                        set: { newValue in
                            word.isVerb = (newValue == 1)
                            word.isPhrasalVerb = (newValue == 2)
                        }
                    )) {
                        Text("Standart").tag(0)
                        Text("Fiil").tag(1)
                        Text("Phrasal").tag(2)
                    }
                    .pickerStyle(.segmented)
                }

                if word.isVerb {
                    Section(header: Text("Fiil Çekimleri")) {
                        TextField("V1 (Base Form)", text: $word.english)
                            .textInputAutocapitalization(.never)
                        TextField("V2 (Past Simple)", text: Binding(
                            get: { word.v2 ?? "" },
                            set: { word.v2 = $0.isEmpty ? nil : $0 }
                        ))
                        .textInputAutocapitalization(.never)
                        TextField("V3 (Past Participle)", text: Binding(
                            get: { word.v3 ?? "" },
                            set: { word.v3 = $0.isEmpty ? nil : $0 }
                        ))
                        .textInputAutocapitalization(.never)
                        TextField("Türkçe Anlamı", text: $word.turkish)
                            .textInputAutocapitalization(.never)
                    }
                } else if word.isPhrasalVerb {
                    Section(header: Text("Phrasal Verb Anlamları")) {
                        TextField("İngilizce Phrasal Verb", text: $word.english)
                            .textInputAutocapitalization(.never)
                        TextField("Türkçe Anlamı", text: $word.turkish)
                            .textInputAutocapitalization(.never)
                    }
                    
                    Section {
                        DisclosureGroup("Alternatif Anlamlar (İsteğe Bağlı)", isExpanded: $showAlternatives) {
                            TextField("Alternatif İngilizce", text: Binding(
                                get: { word.englishAlt ?? "" },
                                set: { word.englishAlt = $0.isEmpty ? nil : $0 }
                            ))
                            .textInputAutocapitalization(.never)
                            
                            TextField("Alternatif Türkçe", text: Binding(
                                get: { word.turkishAlt ?? "" },
                                set: { word.turkishAlt = $0.isEmpty ? nil : $0 }
                            ))
                            .textInputAutocapitalization(.never)
                        }
                    }
                } else {
                    Section(header: Text("Temel Anlamlar")) {
                        TextField("İngilizce", text: $word.english)
                            .textInputAutocapitalization(.never)
                        TextField("Türkçe", text: $word.turkish)
                            .textInputAutocapitalization(.never)
                    }
                    
                    Section {
                        DisclosureGroup("Alternatif Anlamlar (İsteğe Bağlı)", isExpanded: $showAlternatives) {
                            TextField("Alternatif İngilizce", text: Binding(
                                get: { word.englishAlt ?? "" },
                                set: { word.englishAlt = $0.isEmpty ? nil : $0 }
                            ))
                            .textInputAutocapitalization(.never)
                            
                            TextField("Alternatif Türkçe", text: Binding(
                                get: { word.turkishAlt ?? "" },
                                set: { word.turkishAlt = $0.isEmpty ? nil : $0 }
                            ))
                            .textInputAutocapitalization(.never)
                        }
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
