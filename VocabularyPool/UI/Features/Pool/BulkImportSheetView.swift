//
//  BulkImportSheetView.swift
//  VocabularyPool
//
//  Unlimited Bulk Word Import via Paste Text List or CSV File, with live preview & duplicate detection.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct BulkImportSheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var existingWords: [Word]

    enum ImportTab: String, CaseIterable, Identifiable {
        case paste = "Paste List"
        case csv = "CSV File"
        var id: String { rawValue }
    }

    @State private var selectedTab: ImportTab = .paste
    @State private var rawText: String = ""
    @State private var csvFileName: String? = nil
    @State private var markAsPhrasal = false
    @State private var showingCSVPicker = false
    @State private var errorMessage: String? = nil

    private var preview: BulkImportPreview {
        switch selectedTab {
        case .paste:
            return BulkImportParser.parsePlainText(rawText, existingWords: existingWords)
        case .csv:
            return BulkImportParser.parseCSV(rawText, existingWords: existingWords)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                    Picker("Method", selection: $selectedTab) {
                        ForEach(ImportTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedTab) { _, _ in
                        rawText = ""
                        csvFileName = nil
                        errorMessage = nil
                    }

                    if selectedTab == .paste {
                        pasteInputSection
                    } else {
                        csvInputSection
                    }

                    // Tag Option
                    Toggle(isOn: $markAsPhrasal) {
                        HStack(spacing: DS.Spacing.sm) {
                            DSIconBadge(systemImage: "books.vertical.fill", color: DS.Colors.purple, size: 30)
                            Text("Tag imported words as Phrasal Verbs")
                                .font(.dsCallout)
                        }
                    }
                    .tint(DS.Colors.purple)
                    .dsCard(padding: DS.Spacing.sm + 4)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.dsCaption)
                            .foregroundStyle(DS.Colors.danger)
                    }

                    // Live Preview Card
                    if !rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        previewSection
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
            }
            .background(DS.Surfaces.canvas.ignoresSafeArea())
            .navigationTitle("Bulk Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    Divider()
                    DSPrimaryButton(
                        title: preview.newEntries.isEmpty
                            ? "No New Words to Import"
                            : "Import \(preview.newEntries.count) New Words",
                        systemImage: "square.and.arrow.down.fill",
                        isDisabled: preview.newEntries.isEmpty
                    ) {
                        commitImport()
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                }
                .background(DS.Surfaces.canvas)
            }
            .fileImporter(
                isPresented: $showingCSVPicker,
                allowedContentTypes: [.commaSeparatedText, .plainText]
            ) { result in
                handleCSVSelection(result)
            }
        }
    }

    // MARK: - Paste Section

    private var pasteInputSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionHeader(title: "One Word Per Line", trailingText: "Supports -, :, =, Tab")

            ZStack(alignment: .topLeading) {
                TextEditor(text: $rawText)
                    .font(.system(size: 14, design: .monospaced))
                    .frame(minHeight: 170)
                    .scrollContentBackground(.hidden)
                    .padding(DS.Spacing.sm)

                if rawText.isEmpty {
                    Text("facilitate - kolaylaştırmak, rahatlatmak\nrun - koşmak, işletmek, çalışmak\ngive up - vazgeçmek, pes etmek")
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(DS.Spacing.md)
                        .allowsHitTesting(false)
                }
            }
            .background(DS.Surfaces.card)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(DS.Surfaces.border, lineWidth: 1)
            )
        }
    }

    // MARK: - CSV Section

    private var csvInputSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionHeader(title: "CSV File", trailingText: "english,turkish")

            VStack(spacing: DS.Spacing.md) {
                DSIconBadge(systemImage: "tablecells.fill", color: DS.Colors.primary, size: 46)

                Text(csvFileName ?? "Select a .csv file from Files")
                    .font(.dsHeadline)
                    .foregroundStyle(.primary)

                Text("Format: english,turkish (optional v2,v3 columns). Commas or semicolons supported.")
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                DSSecondaryButton(title: csvFileName == nil ? "Choose CSV File" : "Change File", systemImage: "folder") {
                    showingCSVPicker = true
                }
            }
            .frame(maxWidth: .infinity)
            .dsCard(padding: DS.Spacing.lg)
        }
    }

    // MARK: - Live Preview

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionHeader(title: "Preview")

            HStack(spacing: DS.Spacing.sm) {
                statPill(count: preview.newEntries.count, label: "New", color: DS.Colors.success)
                statPill(count: preview.duplicateEntries.count, label: "Duplicates", color: DS.Colors.warning)
                if !preview.invalidLines.isEmpty {
                    statPill(count: preview.invalidLines.count, label: "Skipped", color: DS.Colors.danger)
                }
            }

            if !preview.newEntries.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(preview.newEntries.prefix(12).enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Divider() }
                        HStack {
                            Text(entry.english)
                                .font(.dsCallout)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(entry.formattedTurkish)
                                .font(.dsCaption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 8)
                    }
                    if preview.newEntries.count > 12 {
                        Divider()
                        Text("+ \(preview.newEntries.count - 12) more words ready to import")
                            .font(.dsCaption)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }
                .dsCard(padding: DS.Spacing.md)
            }
        }
    }

    private func statPill(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(label)
                .font(.dsCaption)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.11))
        .clipShape(Capsule())
    }

    // MARK: - Actions

    private func handleCSVSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not access selected file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                rawText = try String(contentsOf: url, encoding: .utf8)
                csvFileName = url.lastPathComponent
                errorMessage = nil
            } catch {
                errorMessage = "Failed to read file: \(error.localizedDescription)"
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func commitImport() {
        let entries = preview.newEntries
        guard !entries.isEmpty else { return }

        for entry in entries {
            let hasVerb = entry.v2 != nil && entry.v3 != nil
            let word = Word(
                english: entry.english,
                turkish: entry.turkishMeanings[0],
                turkishAlt: entry.turkishMeanings.count > 1 ? entry.turkishMeanings[1] : nil,
                additionalTurkish: entry.turkishMeanings.count > 2 ? Array(entry.turkishMeanings.dropFirst(2)) : [],
                isVerb: hasVerb,
                isPhrasalVerb: markAsPhrasal,
                v2: entry.v2,
                v3: entry.v3
            )
            modelContext.insert(word)
        }

        try? modelContext.save()
        Haptics.success()
        dismiss()
    }
}
