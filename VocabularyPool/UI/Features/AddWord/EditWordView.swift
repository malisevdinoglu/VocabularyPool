//
//  EditWordView.swift
//  VocabularyPool
//
//  Unified Edit Word view supporting unlimited Turkish meaning chips, Phrasal/Irregular flags, and mastery stats.
//

import SwiftUI
import SwiftData

struct EditWordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var word: Word

    @State private var turkishMeanings: [String] = []
    @State private var meaningDraft: String = ""
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Word") {
                    TextField("English word", text: $word.english)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("English synonym (optional)", text: Binding(
                        get: { word.englishAlt ?? "" },
                        set: { word.englishAlt = $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
                    ))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                }

                Section("Turkish Meanings") {
                    if !turkishMeanings.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(turkishMeanings, id: \.self) { meaning in
                                HStack(spacing: 6) {
                                    Text(meaning)
                                        .font(.dsCallout)
                                    if turkishMeanings.count > 1 {
                                        Button {
                                            Haptics.light()
                                            turkishMeanings.removeAll { $0 == meaning }
                                            word.setTurkishMeanings(turkishMeanings)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10, weight: .bold))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .foregroundStyle(DS.Colors.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(DS.Colors.primary.opacity(0.10))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    HStack {
                        TextField("Add another meaning...", text: $meaningDraft)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit { addDraftMeaning() }

                        if !meaningDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button("Add") { addDraftMeaning() }
                                .fontWeight(.semibold)
                        }
                    }
                }

                Section("Tags & Conjugations") {
                    Toggle("Phrasal Verb", isOn: $word.isPhrasalVerb)
                        .tint(DS.Colors.purple)

                    Toggle("Irregular Verb (V2 / V3)", isOn: $word.isVerb)
                        .tint(DS.Colors.accent)

                    if word.isVerb {
                        TextField("V2 (Past Simple)", text: Binding(
                            get: { word.v2 ?? "" },
                            set: { word.v2 = $0.isEmpty ? nil : $0 }
                        ))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                        TextField("V3 (Past Participle)", text: Binding(
                            get: { word.v3 ?? "" },
                            set: { word.v3 = $0.isEmpty ? nil : $0 }
                        ))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    }
                }

                Section("Progress") {
                    HStack {
                        Text("Mastery")
                        Spacer()
                        DSMasteryDots(level: word.masteryLevel, isWeak: word.isWeak)
                    }
                    HStack {
                        Text("Status")
                        Spacer()
                        DSBadge(
                            text: word.isWeak ? "Weak (\(word.consecutiveCorrect)/3)" : (word.isNew ? "New" : "Active"),
                            color: word.isWeak ? DS.Colors.danger : (word.isNew ? DS.Colors.accent : DS.Colors.success)
                        )
                    }
                    HStack {
                        Text("Correct / Wrong")
                        Spacer()
                        Text("\(word.correctCount) / \(word.wrongCount)")
                            .foregroundStyle(.secondary)
                    }
                    if let lastStudied = word.lastStudied {
                        HStack {
                            Text("Last Studied")
                            Spacer()
                            Text(lastStudied, style: .date)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Delete Word", systemImage: "trash")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        addDraftMeaning()
                        try? modelContext.save()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(word.english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || turkishMeanings.isEmpty)
                }
            }
            .alert("Delete Word?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    modelContext.delete(word)
                    dismiss()
                }
            } message: {
                Text("This action cannot be undone.")
            }
            .onAppear {
                turkishMeanings = word.allTurkishMeanings
            }
        }
    }

    private func addDraftMeaning() {
        let parts = meaningDraft
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else { return }
        for part in parts where !turkishMeanings.contains(where: { $0.caseInsensitiveCompare(part) == .orderedSame }) {
            turkishMeanings.append(part)
        }
        word.setTurkishMeanings(turkishMeanings)
        meaningDraft = ""
    }
}
