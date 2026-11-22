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
    
    enum EntryType: String, CaseIterable, Identifiable {
        case word = "Standart Kelime"
        case verb = "Fiil Çekimi (V1, V2, V3)"
        case phrasalVerb = "Phrasal Verbs"
        
        var id: String { rawValue }
    }
    
    @State private var entryType: EntryType = .word
    
    // Core fields
    @State private var english = ""
    @State private var turkish = ""
    @State private var v2 = ""
    @State private var v3 = ""
    
    // Alternative fields (for standard words)
    @State private var englishAlt = ""
    @State private var turkishAlt = ""
    @State private var showAlternatives = false
    @State private var showSuccessSheet = false
    
    enum FormField: Hashable {
        case english
        case v2
        case v3
        case turkish
        case englishAlt
        case turkishAlt
    }
    
    @FocusState private var focusedField: FormField?

    var isFormValid: Bool {
        let trimmedEng = english.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTur = turkish.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if entryType == .verb {
            let trimmedV2 = v2.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedV3 = v3.trimmingCharacters(in: .whitespacesAndNewlines)
            return !trimmedEng.isEmpty && !trimmedV2.isEmpty && !trimmedV3.isEmpty && !trimmedTur.isEmpty
        } else {
            return !trimmedEng.isEmpty && !trimmedTur.isEmpty
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    
                    // MARK: - Entry Type Picker
                    Picker("Giriş Tipi", selection: $entryType) {
                        ForEach(EntryType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 4)
                    
                    if entryType == .word || entryType == .phrasalVerb {
                        // MARK: - 🇬🇧 & 🇹🇷 Standart Kelime & Phrasal Verb Anlamları
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            SectionHeaderView(
                                title: entryType == .phrasalVerb ? "Phrasal Verb Anlamları" : "Temel Anlamlar",
                                systemImage: entryType == .phrasalVerb ? "books.vertical.fill" : "character.book.closed.fill",
                                color: entryType == .phrasalVerb ? DS.Colors.purple : DS.Colors.primary
                            )

                            VStack(spacing: DS.Spacing.md) {
                                // İngilizce Kelime / Phrasal Verb Input
                                VStack(alignment: .leading, spacing: 6) {
                                    Label(
                                        entryType == .phrasalVerb ? "İngilizce Phrasal Verb" : "İngilizce Kelime",
                                        systemImage: entryType == .phrasalVerb ? "books.vertical.fill" : "text.book.closed.fill"
                                    )
                                    .font(.dsCaption)
                                    .foregroundStyle(entryType == .phrasalVerb ? DS.Colors.purple : DS.Colors.primary)
                                    
                                    HStack {
                                        TextField(
                                            entryType == .phrasalVerb ? "örn: give up, look after" : "örn: facilitate",
                                            text: $english
                                        )
                                        .font(.dsHeadline)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .english)
                                        .submitLabel(.next)
                                        .onSubmit {
                                            focusedField = .turkish
                                        }

                                        if !english.isEmpty {
                                            Button { english = "" } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    }
                                    .padding(DS.Spacing.md)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.md)
                                            .stroke(focusedField == .english ? (entryType == .phrasalVerb ? DS.Colors.purple : DS.Colors.primary) : Color.secondary.opacity(0.15), lineWidth: focusedField == .english ? 2 : 1)
                                    )
                                }

                                // Türkçe Anlamı Input
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("Türkçe Anlamı", systemImage: "globe")
                                        .font(.dsCaption)
                                        .foregroundStyle(DS.Colors.accent)

                                    HStack {
                                        TextField(
                                            entryType == .phrasalVerb ? "örn: vazgeçmek, ilgilenmek" : "örn: kolaylaştırmak",
                                            text: $turkish
                                        )
                                        .font(.dsHeadline)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .turkish)
                                        .submitLabel(showAlternatives ? .next : .done)
                                        .onSubmit {
                                            if showAlternatives {
                                                focusedField = .englishAlt
                                            } else if isFormValid {
                                                saveWord()
                                            }
                                        }

                                        if !turkish.isEmpty {
                                            Button { turkish = "" } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    }
                                    .padding(DS.Spacing.md)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.md)
                                            .stroke(focusedField == .turkish ? DS.Colors.accent : Color.secondary.opacity(0.15), lineWidth: focusedField == .turkish ? 2 : 1)
                                    )
                                }
                            }
                        }

                        // MARK: - ➕ Alternatif Anlamlar (İsteğe Bağlı)
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    showAlternatives.toggle()
                                    if showAlternatives && focusedField == .turkish {
                                        focusedField = .englishAlt
                                    }
                                }
                            } label: {
                                HStack {
                                    SectionHeaderView(title: "Alternatif Anlamlar (İsteğe Bağlı)", systemImage: "plus.circle.fill", color: DS.Colors.purple)
                                    Spacer()
                                    Image(systemName: showAlternatives ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)

                            if showAlternatives {
                                VStack(spacing: DS.Spacing.md) {
                                    // Alternatif İngilizce
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Alternatif İngilizce Karşılık")
                                            .font(.dsCaption)
                                            .foregroundStyle(.secondary)

                                        TextField("örn: make easy", text: $englishAlt)
                                            .font(.dsBody)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                            .focused($focusedField, equals: .englishAlt)
                                            .submitLabel(.next)
                                            .onSubmit {
                                                focusedField = .turkishAlt
                                            }
                                            .padding(DS.Spacing.md)
                                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                                    .stroke(focusedField == .englishAlt ? DS.Colors.purple : Color.secondary.opacity(0.15), lineWidth: focusedField == .englishAlt ? 2 : 1)
                                            )
                                    }

                                    // Alternatif Türkçe
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("Alternatif Türkçe Karşılık")
                                            .font(.dsCaption)
                                            .foregroundStyle(.secondary)

                                        TextField("örn: rahatlatmak", text: $turkishAlt)
                                            .font(.dsBody)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                            .focused($focusedField, equals: .turkishAlt)
                                            .submitLabel(.done)
                                            .onSubmit {
                                                if isFormValid {
                                                    saveWord()
                                                }
                                            }
                                            .padding(DS.Spacing.md)
                                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                                    .stroke(focusedField == .turkishAlt ? DS.Colors.purple : Color.secondary.opacity(0.15), lineWidth: focusedField == .turkishAlt ? 2 : 1)
                                            )
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                    } else {
                        // MARK: - 🔄 Fiil Çekimleri (V1, V2, V3)
                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            SectionHeaderView(title: "Düzensiz Fiil Çekimi", systemImage: "repeat.circle.fill", color: DS.Colors.purple)

                            VStack(spacing: DS.Spacing.md) {
                                // V1 (Yalın Hal)
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("V1 - Fiilin Yalın Hali (Base)", systemImage: "1.circle.fill")
                                        .font(.dsCaption)
                                        .foregroundStyle(DS.Colors.primary)
                                    
                                    HStack {
                                        TextField("örn: go", text: $english)
                                            .font(.dsHeadline)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                            .focused($focusedField, equals: .english)
                                            .submitLabel(.next)
                                            .onSubmit {
                                                focusedField = .v2
                                            }

                                        if !english.isEmpty {
                                            Button { english = "" } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    }
                                    .padding(DS.Spacing.md)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.md)
                                            .stroke(focusedField == .english ? DS.Colors.primary : Color.secondary.opacity(0.15), lineWidth: focusedField == .english ? 2 : 1)
                                    )
                                }

                                // V2 (Past Simple)
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("V2 - Geçmiş Zaman Hali (Past Simple)", systemImage: "2.circle.fill")
                                        .font(.dsCaption)
                                        .foregroundStyle(DS.Colors.purple)

                                    HStack {
                                        TextField("örn: went", text: $v2)
                                            .font(.dsHeadline)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                            .focused($focusedField, equals: .v2)
                                            .submitLabel(.next)
                                            .onSubmit {
                                                focusedField = .v3
                                            }

                                        if !v2.isEmpty {
                                            Button { v2 = "" } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    }
                                    .padding(DS.Spacing.md)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.md)
                                            .stroke(focusedField == .v2 ? DS.Colors.purple : Color.secondary.opacity(0.15), lineWidth: focusedField == .v2 ? 2 : 1)
                                    )
                                }

                                // V3 (Past Participle)
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("V3 - Ortaç Hali (Past Participle)", systemImage: "3.circle.fill")
                                        .font(.dsCaption)
                                        .foregroundStyle(DS.Colors.total)

                                    HStack {
                                        TextField("örn: gone", text: $v3)
                                            .font(.dsHeadline)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                            .focused($focusedField, equals: .v3)
                                            .submitLabel(.next)
                                            .onSubmit {
                                                focusedField = .turkish
                                            }

                                        if !v3.isEmpty {
                                            Button { v3 = "" } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    }
                                    .padding(DS.Spacing.md)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.md)
                                            .stroke(focusedField == .v3 ? DS.Colors.total : Color.secondary.opacity(0.15), lineWidth: focusedField == .v3 ? 2 : 1)
                                    )
                                }

                                // Türkçe Anlamı
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("Türkçe Anlamı", systemImage: "globe")
                                        .font(.dsCaption)
                                        .foregroundStyle(DS.Colors.accent)

                                    HStack {
                                        TextField("örn: gitmek", text: $turkish)
                                            .font(.dsHeadline)
                                            .textInputAutocapitalization(.never)
                                            .autocorrectionDisabled()
                                            .focused($focusedField, equals: .turkish)
                                            .submitLabel(.done)
                                            .onSubmit {
                                                if isFormValid {
                                                    saveWord()
                                                }
                                            }

                                        if !turkish.isEmpty {
                                            Button { turkish = "" } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }
                                    }
                                    .padding(DS.Spacing.md)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DS.Radius.md)
                                            .stroke(focusedField == .turkish ? DS.Colors.accent : Color.secondary.opacity(0.15), lineWidth: focusedField == .turkish ? 2 : 1)
                                    )
                                }
                            }
                        }
                    }

                    Spacer(minLength: DS.Spacing.xl)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.md)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(entryType == .word ? "Yeni Kelime Ekle" : (entryType == .verb ? "Yeni Fiil Çekimi Ekle" : "Yeni Phrasal Verb Ekle"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        saveWord()
                    }
                    .disabled(!isFormValid)
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    DSPrimaryButton(
                        title: entryType == .word ? "Kelimeyi Kaydet" : (entryType == .verb ? "Fiil Çekimini Kaydet" : "Phrasal Verb Kaydet"),
                        isDisabled: !isFormValid
                    ) {
                        saveWord()
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showSuccessSheet) {
                SuccessView(
                    entryType: entryType,
                    onAddAnother: {
                        showSuccessSheet = false
                        clearForm()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            focusedField = .english
                        }
                    },
                    onGoToVocabulary: {
                        showSuccessSheet = false
                        clearForm()
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToVocabularyTab"), object: nil)
                    }
                )
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    focusedField = .english
                }
            }
            .onDisappear {
                clearForm()
            }
        }
    }
    
    private func saveWord() {
        let trimmedEng = english.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTur = turkish.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEng.isEmpty, !trimmedTur.isEmpty else { return }

        if entryType == .verb {
            let trimmedV2 = v2.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedV3 = v3.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedV2.isEmpty, !trimmedV3.isEmpty else { return }

            let newVerb = Word(
                english: trimmedEng,
                turkish: trimmedTur,
                isVerb: true,
                isPhrasalVerb: false,
                v2: trimmedV2,
                v3: trimmedV3
            )
            modelContext.insert(newVerb)
        } else if entryType == .phrasalVerb {
            let newWord = Word(
                english: trimmedEng,
                turkish: trimmedTur,
                englishAlt: englishAlt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : englishAlt.trimmingCharacters(in: .whitespacesAndNewlines),
                turkishAlt: turkishAlt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : turkishAlt.trimmingCharacters(in: .whitespacesAndNewlines),
                isVerb: false,
                isPhrasalVerb: true
            )
            modelContext.insert(newWord)
        } else {
            let newWord = Word(
                english: trimmedEng,
                turkish: trimmedTur,
                englishAlt: englishAlt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : englishAlt.trimmingCharacters(in: .whitespacesAndNewlines),
                turkishAlt: turkishAlt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : turkishAlt.trimmingCharacters(in: .whitespacesAndNewlines),
                isVerb: false,
                isPhrasalVerb: false
            )
            modelContext.insert(newWord)
        }
        
        // Update word addition tracker
        updateWordTracker()
        
        showSuccessSheet = true
    }
    
    /// Update word addition tracker and manage notifications
    private func updateWordTracker() {
        let descriptor = FetchDescriptor<WordAdditionTracker>()
        guard let tracker = try? modelContext.fetch(descriptor).first else {
            return
        }
        
        tracker.addWord()
        
        if tracker.isCurrentPeriodCompleted {
            tracker.startNewPeriod()
            print("✅ 10 kelime hedefi tamamlandı! Yeni periyot başlatıldı.")
        }
        
        try? modelContext.save()
    }
    
    private func clearForm() {
        english = ""
        turkish = ""
        v2 = ""
        v3 = ""
        englishAlt = ""
        turkishAlt = ""
        showAlternatives = false
    }
}

struct SuccessView: View {
    var entryType: AddWordView.EntryType = .word
    let onAddAnother: () -> Void
    let onGoToVocabulary: () -> Void

    @State private var appear = false

    private var successTitle: String {
        switch entryType {
        case .word: return "Kelime Eklendi!"
        case .verb: return "Fiil Çekimi Eklendi!"
        case .phrasalVerb: return "Phrasal Verb Eklendi!"
        }
    }

    private var addAnotherTitle: String {
        switch entryType {
        case .word: return "Yeni Kelime Ekle"
        case .verb: return "Yeni Fiil Ekle"
        case .phrasalVerb: return "Yeni Phrasal Verb Ekle"
        }
    }

    private var accentColor: Color {
        entryType == .phrasalVerb ? DS.Colors.purple : DS.Colors.primary
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(accentColor)
                .scaleEffect(appear ? 1.0 : 0.5)
                .opacity(appear ? 1.0 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: appear)

            VStack(spacing: DS.Spacing.xs) {
                Text(successTitle)
                    .font(.dsTitle)
                Text("Harika! Çalışmaya devam et.")
                    .font(.dsCallout)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: DS.Spacing.sm) {
                Button(action: onAddAnother) {
                    Text(addAnotherTitle)
                        .font(.dsHeadline)
                        .frame(maxWidth: .infinity)
                        .padding(DS.Spacing.md)
                        .background(accentColor)
                        .foregroundStyle(DS.Colors.onColor)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)

                Button(action: onGoToVocabulary) {
                    Text("Kelimelerime Git")
                        .font(.dsHeadline)
                        .frame(maxWidth: .infinity)
                        .padding(DS.Spacing.md)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, DS.Spacing.xs)
        }
        .padding(DS.Spacing.lg)
        .presentationDetents([.height(300)])
        .onAppear { appear = true }
    }
}

#Preview {
    AddWordView()
        .modelContainer(for: Word.self, inMemory: true)
}
