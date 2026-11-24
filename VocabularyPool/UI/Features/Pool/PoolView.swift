//
//  PoolView.swift
//  VocabularyPool
//
//  Clean Vocabulary Pool list with dot-separated multi-meanings, 5-dot Mastery indicator,
//  category filters, sorting, A-Z index bar, and Bulk Import / JSON / PDF tools.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Sort & Filter Enums

enum PoolSortOption: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case oldest = "Oldest"
    case alphabeticalAZ = "A → Z"
    case alphabeticalZA = "Z → A"
    case lowestAccuracy = "Lowest Accuracy"
    case highestAccuracy = "Highest Accuracy"

    var id: String { rawValue }

    var shortName: String {
        switch self {
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        case .alphabeticalAZ: return "A-Z"
        case .alphabeticalZA: return "Z-A"
        case .lowestAccuracy: return "Weakest"
        case .highestAccuracy: return "Strongest"
        }
    }

    var icon: String {
        switch self {
        case .newest: return "clock.arrow.circlepath"
        case .oldest: return "clock"
        case .alphabeticalAZ, .alphabeticalZA: return "textformat.abc"
        case .lowestAccuracy: return "exclamationmark.triangle"
        case .highestAccuracy: return "checkmark.seal"
        }
    }
}

enum PoolFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case weak = "Weak"
    case phrasal = "Phrasal"
    case irregularVerbs = "Verbs"

    var id: String { rawValue }

    var accentColor: Color {
        switch self {
        case .all: return DS.Colors.primary
        case .weak: return DS.Colors.danger
        case .phrasal: return DS.Colors.purple
        case .irregularVerbs: return DS.Colors.accent
        }
    }
}

struct WordSection: Identifiable {
    let letter: String
    let words: [Word]
    var id: String { letter }
}

// MARK: - PoolView

struct PoolView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \Word.timestamp, order: .reverse) private var words: [Word]

    let onTapAddWord: () -> Void

    @AppStorage("appThemeMode") private var appThemeMode: String = "system"
    @AppStorage("poolSortOption") private var sortOption: PoolSortOption = .newest
    @State private var selectedFilter: PoolFilter = .all
    @State private var searchText = ""

    // Sheets & Alerts
    @State private var showingBulkImport = false
    @State private var showingExportSheet = false
    @State private var exportFileURL: URL?
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingAlert = false

    private func count(for filter: PoolFilter) -> Int {
        switch filter {
        case .all: return words.count
        case .weak: return words.filter { $0.isWeak }.count
        case .phrasal: return words.filter { $0.isPhrasalVerb }.count
        case .irregularVerbs: return words.filter { $0.hasConjugations }.count
        }
    }

    private var filteredWords: [Word] {
        let searched: [Word]
        if searchText.isEmpty {
            searched = words
        } else {
            searched = words.filter { word in
                word.english.localizedCaseInsensitiveContains(searchText) ||
                word.allTurkishMeanings.contains { $0.localizedCaseInsensitiveContains(searchText) } ||
                (word.englishAlt?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (word.v2?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (word.v3?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        let categoryFiltered: [Word]
        switch selectedFilter {
        case .all: categoryFiltered = searched
        case .weak: categoryFiltered = searched.filter { $0.isWeak }
        case .phrasal: categoryFiltered = searched.filter { $0.isPhrasalVerb }
        case .irregularVerbs: categoryFiltered = searched.filter { $0.hasConjugations }
        }

        switch sortOption {
        case .newest:
            return categoryFiltered.sorted { $0.timestamp > $1.timestamp }
        case .oldest:
            return categoryFiltered.sorted { $0.timestamp < $1.timestamp }
        case .alphabeticalAZ:
            return categoryFiltered.sorted { $0.english.localizedCaseInsensitiveCompare($1.english) == .orderedAscending }
        case .alphabeticalZA:
            return categoryFiltered.sorted { $0.english.localizedCaseInsensitiveCompare($1.english) == .orderedDescending }
        case .lowestAccuracy:
            return categoryFiltered.sorted { ($0.accuracyRate ?? 1.0) < ($1.accuracyRate ?? 1.0) }
        case .highestAccuracy:
            return categoryFiltered.sorted { ($0.accuracyRate ?? -1.0) > ($1.accuracyRate ?? -1.0) }
        }
    }

    private var groupedSections: [WordSection] {
        let sorted = filteredWords
        guard sortOption == .alphabeticalAZ || sortOption == .alphabeticalZA else {
            return [WordSection(letter: "", words: sorted)]
        }

        let dict = Dictionary(grouping: sorted) { word -> String in
            guard let first = word.english.first else { return "#" }
            let upper = String(first).uppercased()
            return upper.rangeOfCharacter(from: .letters) != nil ? upper : "#"
        }

        let keys = sortOption == .alphabeticalZA ? dict.keys.sorted(by: >) : dict.keys.sorted(by: <)
        return keys.map { WordSection(letter: $0, words: dict[$0] ?? []) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Horizontal Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(PoolFilter.allCases) { filter in
                        DSChip(
                            label: filter.rawValue,
                            count: count(for: filter),
                            isSelected: selectedFilter == filter,
                            accentColor: filter.accentColor
                        ) {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedFilter = filter
                            }
                        }
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
            }
            .background(DS.Surfaces.canvas)

            ScrollViewReader { proxy in
                ZStack(alignment: .trailing) {
                    List {
                        if words.isEmpty {
                            ContentUnavailableView(
                                "Your Pool Is Empty",
                                systemImage: "text.book.closed",
                                description: Text("Tap + to add your first word or use Bulk Import from the menu.")
                            )
                            .listRowBackground(Color.clear)
                        } else if filteredWords.isEmpty {
                            ContentUnavailableView.search
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(groupedSections) { section in
                                Section {
                                    ForEach(section.words) { word in
                                        ZStack {
                                            WordRowView(word: word)
                                            NavigationLink(destination: EditWordView(word: word)) {
                                                EmptyView()
                                            }
                                            .opacity(0)
                                        }
                                        .listRowBackground(Color.clear)
                                        .listRowSeparator(.hidden)
                                        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                                    }
                                    .onDelete { offsets in
                                        deleteWords(in: section, offsets: offsets)
                                    }
                                } header: {
                                    if !section.letter.isEmpty {
                                        Text(section.letter)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundStyle(DS.Colors.primary)
                                            .padding(.leading, 4)
                                            .id("section_\(section.letter)")
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(DS.Surfaces.canvas)

                    if (sortOption == .alphabeticalAZ || sortOption == .alphabeticalZA) && groupedSections.count > 1 {
                        AlphabetIndexBar(letters: groupedSections.map { $0.letter }) { letter in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo("section_\(letter)", anchor: .top)
                            }
                        }
                        .padding(.trailing, 4)
                    }
                }
            }
        }
        .background(DS.Surfaces.canvas.ignoresSafeArea())
        .navigationTitle("Pool")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search words or meanings...")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(PoolSortOption.allCases) { option in
                            Label(option.rawValue, systemImage: option.icon).tag(option)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12, weight: .semibold))
                        Text(sortOption.shortName)
                            .font(.dsCaption)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(DS.Colors.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(DS.Colors.primary.opacity(0.10))
                    .clipShape(Capsule())
                }
            }

            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingBulkImport = true
                    } label: {
                        Label("Bulk Import (Paste / CSV)", systemImage: "doc.on.clipboard")
                    }

                    Button {
                        runExportPDF()
                    } label: {
                        Label("Export List (PDF)", systemImage: "doc.text")
                    }
                    .disabled(words.isEmpty)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.primary)
                }

                Button {
                    Haptics.light()
                    onTapAddWord()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DS.Colors.primary)
                        .frame(width: 34, height: 34)
                        .background(DS.Colors.primary.opacity(0.11))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Add Word")

                Button {
                    Haptics.selection()
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appThemeMode = (colorScheme == .dark) ? "light" : "dark"
                    }
                } label: {
                    Image(systemName: colorScheme == .dark ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DS.Colors.primary)
                }
                .accessibilityLabel(colorScheme == .dark ? "Switch to Light Mode" : "Switch to Dark Mode")
            }
        }
        .sheet(isPresented: $showingBulkImport) {
            BulkImportSheetView()
        }
        .sheet(isPresented: $showingExportSheet, onDismiss: { exportFileURL = nil }) {
            if let url = exportFileURL {
                DocumentPicker(url: url)
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }

    // MARK: - Actions

    private func deleteWords(in section: WordSection, offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(section.words[index])
            }
        }
    }

    private func runExportPDF() {
        do {
            exportFileURL = try ExportImportService.exportPDF(words: words)
            showingExportSheet = true
        } catch {
            alertTitle = "PDF Export Failed"
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }
}

// MARK: - Editorial Word Row View

struct WordRowView: View {
    let word: Word

    private var accuracyColor: Color {
        guard let rate = word.accuracyRate else { return .secondary }
        if rate >= 0.75 { return DS.Colors.success }
        if rate >= 0.45 { return DS.Colors.warning }
        return DS.Colors.danger
    }

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(word.english)
                        .font(.dsHeadline)
                        .foregroundStyle(.primary)

                    if word.isPhrasalVerb {
                        DSBadge(text: "Phrasal", color: DS.Colors.purple)
                    }

                    if word.hasConjugations {
                        DSBadge(text: "V2/V3", color: DS.Colors.accent)
                    }
                }

                // Dot-separated multi-meanings: "koşmak • işletmek • çalışmak"
                Text(word.formattedTurkishMeanings)
                    .font(.dsCallout)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if word.hasConjugations, let v2 = word.v2, let v3 = word.v3 {
                    Text("\(v2) → \(v3)")
                        .font(.dsCaption)
                        .foregroundStyle(DS.Colors.accent)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 6) {
                DSMasteryDots(level: word.masteryLevel, isWeak: word.isWeak)

                HStack(spacing: 4) {
                    if word.isWeak {
                        DSBadge(text: "Weak", color: DS.Colors.danger)
                    } else if let rate = word.accuracyRate {
                        Text("\(Int(rate * 100))%")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(accuracyColor)
                    }
                }
            }
        }
        .dsCard(padding: 14, cornerRadius: DS.Radius.md)
    }
}

// MARK: - Document Picker & Alphabet Index

struct DocumentPicker: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        UIDocumentPickerViewController(forExporting: [url])
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

struct AlphabetIndexBar: View {
    let letters: [String]
    let onSelectLetter: (String) -> Void
    @State private var activeLetter: String? = nil

    var body: some View {
        VStack(spacing: 2) {
            ForEach(letters, id: \.self) { letter in
                Text(letter)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(activeLetter == letter ? DS.Colors.primary : .secondary)
                    .frame(width: 18, height: 15)
                    .onTapGesture {
                        Haptics.selection()
                        activeLetter = letter
                        onSelectLetter(letter)
                    }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
        .background(DS.Surfaces.card.opacity(0.92))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(DS.Surfaces.border, lineWidth: 1))
    }
}
