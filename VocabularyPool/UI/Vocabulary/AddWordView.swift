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
    
    enum FormField: Hashable {
        case english
        case turkish
        case englishAlt
        case turkishAlt
    }
    
    @FocusState private var focusedField: FormField?

    var isFormValid: Bool {
        !english.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !turkish.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.lg) {
                    
                    // MARK: - 🇬🇧 & 🇹🇷 Temel Anlamlar
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        SectionHeaderView(title: "Temel Anlamlar", systemImage: "character.book.closed.fill", color: DS.Colors.primary)

                        VStack(spacing: DS.Spacing.md) {
                            // İngilizce Kelime Input
                            VStack(alignment: .leading, spacing: 6) {
                                Label("İngilizce Kelime", systemImage: "text.book.closed.fill")
                                    .font(.dsCaption)
                                    .foregroundStyle(DS.Colors.primary)
                                
                                HStack {
                                    TextField("örn: facilitate", text: $english)
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
                                        .stroke(focusedField == .english ? DS.Colors.primary : Color.secondary.opacity(0.15), lineWidth: focusedField == .english ? 2 : 1)
                                )
                            }

                            // Türkçe Anlamı Input
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Türkçe Anlamı", systemImage: "globe")
                                    .font(.dsCaption)
                                    .foregroundStyle(DS.Colors.accent)

                                HStack {
                                    TextField("örn: kolaylaştırmak", text: $turkish)
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

                    Spacer(minLength: DS.Spacing.xl)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.md)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Yeni Kelime Ekle")
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
                        title: "Kelimeyi Kaydet",
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

        let newWord = Word(
            english: trimmedEng,
            turkish: trimmedTur,
            englishAlt: englishAlt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : englishAlt.trimmingCharacters(in: .whitespacesAndNewlines),
            turkishAlt: turkishAlt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : turkishAlt.trimmingCharacters(in: .whitespacesAndNewlines)
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

    @State private var appear = false

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(DS.Colors.primary)
                .scaleEffect(appear ? 1.0 : 0.5)
                .opacity(appear ? 1.0 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: appear)

            VStack(spacing: DS.Spacing.xs) {
                Text("Kelime Eklendi!")
                    .font(.dsTitle)
                Text("Harika! Çalışmaya devam et.")
                    .font(.dsCallout)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: DS.Spacing.sm) {
                Button(action: onAddAnother) {
                    Text("Yeni Kelime Ekle")
                        .font(.dsHeadline)
                        .frame(maxWidth: .infinity)
                        .padding(DS.Spacing.md)
                        .background(DS.Colors.primary)
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
