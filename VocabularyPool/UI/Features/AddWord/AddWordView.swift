//
//  AddWordView.swift
//  VocabularyPool
//
//  Unified Quick-Add Sheet with chip/tag multi-meaning entry, live duplicate detection,
//  and optional Phrasal Verb / Irregular Verb (V2, V3) toggles.
//

import SwiftUI
import SwiftData

struct AddWordView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingWords: [Word]

    // Core Fields
    @State private var english = ""
    @State private var meaningDraft = ""
    @State private var turkishMeanings: [String] = []
    @State private var englishAlt = ""

    // Optional Tags & Conjugations
    @State private var isPhrasalVerb = false
    @State private var hasIrregularForms = false
    @State private var v2 = ""
    @State private var v3 = ""

    // Feedback & Duplicate Handling
    @State private var savedToastText: String? = nil
    @State private var wordToEdit: Word? = nil

    enum Field: Hashable { case english, meaning, englishAlt, v2, v3 }
    @FocusState private var focusedField: Field?

    private var trimmedEnglish: String {
        english.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Live duplicate check against existing pool
    private var duplicateWord: Word? {
        let key = trimmedEnglish.lowercased()
        guard !key.isEmpty else { return nil }
        return existingWords.first {
            $0.english.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == key
        }
    }

    /// All meanings that would be saved (chips + any uncommitted draft text)
    private var effectiveMeanings: [String] {
        var list = turkishMeanings
        let draftParts = meaningDraft
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for part in draftParts where !list.contains(where: { $0.caseInsensitiveCompare(part) == .orderedSame }) {
            list.append(part)
        }
        return list
    }

    private var isFormValid: Bool {
        guard !trimmedEnglish.isEmpty, !effectiveMeanings.isEmpty else { return false }
        if hasIrregularForms {
            let tV2 = v2.trimmingCharacters(in: .whitespacesAndNewlines)
            let tV3 = v3.trimmingCharacters(in: .whitespacesAndNewlines)
            return !tV2.isEmpty && !tV3.isEmpty
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                    if let toast = savedToastText {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(DS.Colors.success)
                            Text(toast)
                                .font(.dsCallout)
                                .foregroundStyle(DS.Colors.success)
                            Spacer()
                        }
                        .padding(DS.Spacing.sm + 4)
                        .background(DS.Colors.success.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // MARK: - English Word
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader(title: "English Word")

                        HStack {
                            TextField("e.g. facilitate, run, give up", text: $english)
                                .font(.dsHeadline)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .english)
                                .submitLabel(.next)
                                .onSubmit { focusedField = .meaning }

                            if !english.isEmpty {
                                Button { english = "" } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .padding(DS.Spacing.md)
                        .background(DS.Surfaces.card)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                .strokeBorder(focusedField == .english ? DS.Colors.primary : DS.Surfaces.border, lineWidth: focusedField == .english ? 1.5 : 1)
                        )

                        // Live Duplicate Warning Banner
                        if let existing = duplicateWord {
                            duplicateBanner(for: existing)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }

                    // MARK: - Turkish Meanings (Chip / Tag Input)
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader(title: "Turkish Meanings", trailingText: "Comma or Return to add")

                        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                            if !turkishMeanings.isEmpty {
                                FlowLayout(spacing: 8) {
                                    ForEach(turkishMeanings, id: \.self) { meaning in
                                        HStack(spacing: 6) {
                                            Text(meaning)
                                                .font(.dsCallout)
                                            Button {
                                                Haptics.light()
                                                withAnimation(.easeInOut(duration: 0.15)) {
                                                    turkishMeanings.removeAll { $0 == meaning }
                                                }
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.system(size: 10, weight: .bold))
                                            }
                                        }
                                        .foregroundStyle(DS.Colors.primary)
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 6)
                                        .background(DS.Colors.primary.opacity(0.10))
                                        .clipShape(Capsule())
                                    }
                                }
                            }

                            HStack(spacing: DS.Spacing.sm) {
                                TextField(
                                    turkishMeanings.isEmpty ? "e.g. koşmak, işletmek" : "Add another meaning...",
                                    text: $meaningDraft
                                )
                                .font(.dsBody)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .meaning)
                                .submitLabel(.done)
                                .onChange(of: meaningDraft) { _, newValue in
                                    if newValue.contains(",") {
                                        commitDraftMeanings()
                                    }
                                }
                                .onSubmit {
                                    if !meaningDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        commitDraftMeanings()
                                        focusedField = .meaning
                                    }
                                }

                                if !meaningDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Button {
                                        commitDraftMeanings()
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundStyle(DS.Colors.primary)
                                    }
                                }
                            }
                            .padding(DS.Spacing.md)
                            .background(DS.Surfaces.card)
                            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                    .strokeBorder(focusedField == .meaning ? DS.Colors.primary : DS.Surfaces.border, lineWidth: focusedField == .meaning ? 1.5 : 1)
                            )
                        }
                    }

                    // MARK: - Optional Properties
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        DSSectionHeader(title: "Options")

                        VStack(spacing: 0) {
                            Toggle(isOn: $isPhrasalVerb) {
                                HStack(spacing: DS.Spacing.sm) {
                                    DSIconBadge(systemImage: "books.vertical.fill", color: DS.Colors.purple, size: 30)
                                    Text("Phrasal Verb")
                                        .font(.dsBody)
                                }
                            }
                            .tint(DS.Colors.purple)
                            .padding(.vertical, 6)

                            Divider()

                            Toggle(isOn: $hasIrregularForms.animation(.easeInOut(duration: 0.2))) {
                                HStack(spacing: DS.Spacing.sm) {
                                    DSIconBadge(systemImage: "repeat", color: DS.Colors.accent, size: 30)
                                    Text("Irregular Verb (V2 / V3)")
                                        .font(.dsBody)
                                }
                            }
                            .tint(DS.Colors.accent)
                            .padding(.vertical, 6)

                            if hasIrregularForms {
                                HStack(spacing: DS.Spacing.sm) {
                                    TextField("V2 (e.g. went)", text: $v2)
                                        .font(.dsBody)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .v2)
                                        .padding(10)
                                        .background(DS.Surfaces.muted)
                                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

                                    TextField("V3 (e.g. gone)", text: $v3)
                                        .font(.dsBody)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .focused($focusedField, equals: .v3)
                                        .padding(10)
                                        .background(DS.Surfaces.muted)
                                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))
                                }
                                .padding(.top, DS.Spacing.sm)
                                .padding(.bottom, 4)
                            }

                            Divider().padding(.top, hasIrregularForms ? 4 : 0)

                            TextField("Optional English synonym (e.g. make easy)", text: $englishAlt)
                                .font(.dsCallout)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($focusedField, equals: .englishAlt)
                                .padding(.top, 10)
                        }
                        .dsCard()
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.top, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.xl)
            }
            .background(DS.Surfaces.canvas.ignoresSafeArea())
            .navigationTitle("Add Word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWord(closeAfter: true)
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid || duplicateWord != nil)
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: DS.Spacing.sm) {
                    Divider()
                    HStack(spacing: DS.Spacing.sm) {
                        DSSecondaryButton(title: "Save & Next") {
                            saveWord(closeAfter: false)
                        }
                        .disabled(!isFormValid || duplicateWord != nil)

                        DSPrimaryButton(
                            title: "Save Word",
                            isDisabled: !isFormValid || duplicateWord != nil
                        ) {
                            saveWord(closeAfter: true)
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.bottom, DS.Spacing.sm)
                }
                .background(DS.Surfaces.canvas)
            }
            .sheet(item: $wordToEdit) { existing in
                EditWordView(word: existing)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    focusedField = .english
                }
            }
        }
    }

    // MARK: - Duplicate Banner

    private func duplicateBanner(for existing: Word) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(DS.Colors.warning)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Already in your pool")
                        .font(.dsCallout)
                        .fontWeight(.semibold)
                    Text(existing.formattedTurkishMeanings)
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }

            HStack(spacing: DS.Spacing.sm) {
                if !effectiveMeanings.isEmpty {
                    Button {
                        existing.appendTurkishMeanings(effectiveMeanings)
                        if isPhrasalVerb { existing.isPhrasalVerb = true }
                        if hasIrregularForms {
                            existing.isVerb = true
                            existing.v2 = v2.trimmingCharacters(in: .whitespacesAndNewlines)
                            existing.v3 = v3.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        try? modelContext.save()
                        Haptics.success()
                        withAnimation {
                            savedToastText = "Merged new meaning(s) into \"\(existing.english)\""
                        }
                        resetForm()
                    } label: {
                        Text("Merge Meanings")
                            .font(.dsCaption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(DS.Colors.warning)
                            .clipShape(Capsule())
                    }
                }

                Button {
                    wordToEdit = existing
                } label: {
                    Text("Edit Existing")
                        .font(.dsCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Colors.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(DS.Colors.primary.opacity(0.11))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(DS.Spacing.sm + 4)
        .background(DS.Colors.warning.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .strokeBorder(DS.Colors.warning.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func commitDraftMeanings() {
        let parts = meaningDraft
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !parts.isEmpty else {
            meaningDraft = ""
            return
        }
        Haptics.selection()
        withAnimation(.easeInOut(duration: 0.15)) {
            for part in parts where !turkishMeanings.contains(where: { $0.caseInsensitiveCompare(part) == .orderedSame }) {
                turkishMeanings.append(part)
            }
            meaningDraft = ""
        }
    }

    private func saveWord(closeAfter: Bool) {
        let meanings = effectiveMeanings
        guard !trimmedEnglish.isEmpty, !meanings.isEmpty else { return }

        let trimmedAlt = englishAlt.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedV2 = v2.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedV3 = v3.trimmingCharacters(in: .whitespacesAndNewlines)

        let word = Word(
            english: trimmedEnglish,
            turkish: meanings[0],
            englishAlt: trimmedAlt.isEmpty ? nil : trimmedAlt,
            turkishAlt: meanings.count > 1 ? meanings[1] : nil,
            additionalTurkish: meanings.count > 2 ? Array(meanings.dropFirst(2)) : [],
            isVerb: hasIrregularForms,
            isPhrasalVerb: isPhrasalVerb,
            v2: hasIrregularForms ? trimmedV2 : nil,
            v3: hasIrregularForms ? trimmedV3 : nil
        )
        modelContext.insert(word)
        updateWordTracker()
        try? modelContext.save()

        Haptics.success()

        if closeAfter {
            dismiss()
        } else {
            withAnimation {
                savedToastText = "Saved \"\(word.english)\""
            }
            resetForm()
            focusedField = .english
        }
    }

    private func resetForm() {
        english = ""
        meaningDraft = ""
        turkishMeanings = []
        englishAlt = ""
        isPhrasalVerb = false
        hasIrregularForms = false
        v2 = ""
        v3 = ""
    }

    private func updateWordTracker() {
        let descriptor = FetchDescriptor<WordAdditionTracker>()
        guard let tracker = try? modelContext.fetch(descriptor).first else { return }
        tracker.addWord()
        if tracker.isCurrentPeriodCompleted {
            tracker.startNewPeriod()
        }
    }
}

// MARK: - Wrapping Flow Layout for Meaning Chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX && currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            view.place(at: CGPoint(x: currentX, y: currentY), proposal: ProposedViewSize(size))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
