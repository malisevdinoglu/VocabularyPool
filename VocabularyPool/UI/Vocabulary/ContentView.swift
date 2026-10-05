//
//  ContentView.swift
//  VocabularyPool
//
//  Created by Mehmet Ali Sevdinoğlu on 27.12.2025.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Export/Import Models

/// Codable representation of Word for export/import
struct WordExport: Codable, Identifiable {
    var id: UUID
    var english: String
    var turkish: String
    var englishAlt: String?
    var turkishAlt: String?
    var correctCount: Int
    var wrongCount: Int
    var lastStudied: Date?
    var timestamp: Date
    
    init(from word: Word) {
        self.id = UUID()
        self.english = word.english
        self.turkish = word.turkish
        self.englishAlt = word.englishAlt
        self.turkishAlt = word.turkishAlt
        self.correctCount = word.correctCount
        self.wrongCount = word.wrongCount
        self.lastStudied = word.lastStudied
        self.timestamp = word.timestamp
    }
    
    func toWord() -> Word {
        let word = Word(
            english: english,
            turkish: turkish,
            englishAlt: englishAlt,
            turkishAlt: turkishAlt,
            timestamp: timestamp
        )
        // Restore statistics
        word.correctCount = correctCount
        word.wrongCount = wrongCount
        word.lastStudied = lastStudied
        return word
    }
}

struct VocabularyExport: Codable {
    var words: [WordExport]
    var exportDate: Date
    var version: String
    
    init(words: [Word]) {
        self.words = words.map { WordExport(from: $0) }
        self.exportDate = Date()
        self.version = "1.0"
    }
}

// MARK: - Main App View


struct ContentView: View {
    @State private var selectedTab = 0
    @Query(filter: #Predicate<Word> { $0.needsReview == true }) private var reviewWords: [Word]

    var body: some View {
        TabView(selection: $selectedTab) {
            VocabularyListView()
                .tabItem {
                    Label("Vocabulary", systemImage: "book.fill")
                }
                .tag(0)

            NavigationStack {
                AddWordView()
            }
            .tabItem {
                Label("Add Word", systemImage: "plus.circle.fill")
            }
            .tag(1)

            NavigationStack {
                PracticeConfigView()
            }
            .tabItem {
                Label("Practice", systemImage: "play.circle.fill")
            }
            .badge(reviewWords.isEmpty ? 0 : reviewWords.count)
            .tag(2)

            StatisticsView()
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar.fill")
                }
                .tag(3)
        }
        .tint(DS.Colors.primary)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToVocabularyTab"))) { _ in
            selectedTab = 0
        }
        .onAppear {
            // Check for new week
            if PracticeGoals.shared.isNewWeek() {
                PracticeGoals.shared.updateWeekStart()
            }
        }
    }
}

// MARK: - Sort Options & Section Model

enum SortOption: String, CaseIterable, Identifiable {
    case newest = "En Yeni"
    case oldest = "En Eski"
    case alphabeticalAZ = "A → Z (İngilizce)"
    case alphabeticalZA = "Z → A (İngilizce)"
    case lowestAccuracy = "En Düşük Başarı"
    case highestAccuracy = "En Yüksek Başarı"

    var id: String { self.rawValue }

    var shortName: String {
        switch self {
        case .newest: return "En Yeni"
        case .oldest: return "En Eski"
        case .alphabeticalAZ: return "A-Z"
        case .alphabeticalZA: return "Z-A"
        case .lowestAccuracy: return "Zayıf"
        case .highestAccuracy: return "Başarılı"
        }
    }

    var icon: String {
        switch self {
        case .newest: return "clock.arrow.circlepath"
        case .oldest: return "clock"
        case .alphabeticalAZ: return "textformat.abc"
        case .alphabeticalZA: return "textformat.abc"
        case .lowestAccuracy: return "exclamationmark.triangle.fill"
        case .highestAccuracy: return "checkmark.seal.fill"
        }
    }
}

struct WordSection: Identifiable {
    let letter: String
    let words: [Word]
    var id: String { letter }
}

struct VocabularyListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Word.timestamp, order: .reverse) private var words: [Word]
    
    @AppStorage("vocabularySortOption") private var sortOption: SortOption = .newest

    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var exportFileURL: URL?
    @State private var showingImportAlert = false
    @State private var importAlertMessage = ""
    @State private var searchText = ""
    
    var sortedAndFilteredWords: [Word] {
        let filtered: [Word]
        if searchText.isEmpty {
            filtered = words
        } else {
            filtered = words.filter { word in
                word.english.localizedCaseInsensitiveContains(searchText) ||
                word.turkish.localizedCaseInsensitiveContains(searchText) ||
                (word.englishAlt?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (word.turkishAlt?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        switch sortOption {
        case .newest:
            return filtered.sorted { $0.timestamp > $1.timestamp }
        case .oldest:
            return filtered.sorted { $0.timestamp < $1.timestamp }
        case .alphabeticalAZ:
            return filtered.sorted { $0.english.localizedCaseInsensitiveCompare($1.english) == .orderedAscending }
        case .alphabeticalZA:
            return filtered.sorted { $0.english.localizedCaseInsensitiveCompare($1.english) == .orderedDescending }
        case .lowestAccuracy:
            return filtered.sorted { w1, w2 in
                let t1 = w1.correctCount + w1.wrongCount
                let r1 = t1 > 0 ? Double(w1.correctCount) / Double(t1) : 1.0
                let t2 = w2.correctCount + w2.wrongCount
                let r2 = t2 > 0 ? Double(w2.correctCount) / Double(t2) : 1.0
                return r1 < r2
            }
        case .highestAccuracy:
            return filtered.sorted { w1, w2 in
                let t1 = w1.correctCount + w1.wrongCount
                let r1 = t1 > 0 ? Double(w1.correctCount) / Double(t1) : 0.0
                let t2 = w2.correctCount + w2.wrongCount
                let r2 = t2 > 0 ? Double(w2.correctCount) / Double(t2) : 0.0
                return r1 > r2
            }
        }
    }

    var groupedSections: [WordSection] {
        let sorted = sortedAndFilteredWords
        guard sortOption == .alphabeticalAZ || sortOption == .alphabeticalZA else {
            return [WordSection(letter: "", words: sorted)]
        }

        let dictionary = Dictionary(grouping: sorted) { word -> String in
            guard let firstChar = word.english.first else { return "#" }
            let uppercase = String(firstChar).uppercased()
            return uppercase.rangeOfCharacter(from: CharacterSet.letters) != nil ? uppercase : "#"
        }

        let keys: [String]
        if sortOption == .alphabeticalZA {
            keys = dictionary.keys.sorted(by: >)
        } else {
            keys = dictionary.keys.sorted(by: <)
        }

        return keys.map { key in
            WordSection(letter: key, words: dictionary[key] ?? [])
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack(alignment: .trailing) {
                    List {
                        if words.isEmpty {
                            ContentUnavailableView(
                                "Henüz Kelime Yok",
                                systemImage: "text.book.closed",
                                description: Text("+ butonuna basarak ilk kelimenizi ekleyin.")
                            )
                        } else if sortedAndFilteredWords.isEmpty {
                            ContentUnavailableView.search
                        } else {
                            ForEach(groupedSections) { section in
                                Section {
                                    ForEach(section.words) { word in
                                        NavigationLink(destination: EditWordView(word: word)) {
                                            WordRowView(word: word)
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
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundStyle(DS.Colors.primary)
                                            .padding(.leading, 8)
                                            .id("section_\(section.letter)")
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)

                    // A-Z Harf İndeksi (Yalnızca alfabetik sıralamada ve 1'den fazla bölüm varsa görünür)
                    if (sortOption == .alphabeticalAZ || sortOption == .alphabeticalZA) && groupedSections.count > 1 {
                        AlphabetIndexBar(letters: groupedSections.map { $0.letter }) { selectedLetter in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                proxy.scrollTo("section_\(selectedLetter)", anchor: .top)
                            }
                        }
                        .padding(.trailing, 4)
                    }
                }
            }
            .navigationTitle("Kelime Havuzu")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Kelime ara...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Sıralama", selection: $sortOption) {
                            ForEach(SortOption.allCases) { option in
                                Label(option.rawValue, systemImage: option.icon)
                                    .tag(option)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(sortOption.shortName)
                                .font(.dsCaption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(DS.Colors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DS.Colors.primary.opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            exportWords()
                        } label: {
                            Label("Export as JSON", systemImage: "square.and.arrow.up")
                        }
                        .disabled(words.isEmpty)
                        
                        Button {
                            exportPDF()
                        } label: {
                            Label("Export as PDF", systemImage: "doc.text")
                        }
                        .disabled(words.isEmpty)
                        
                        Button {
                            showingImportPicker = true
                        } label: {
                            Label("Import Words", systemImage: "square.and.arrow.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingExportSheet, onDismiss: {
                exportFileURL = nil
            }) {
                if let url = exportFileURL {
                    DocumentPicker(url: url)
                }
            }
            .fileImporter(isPresented: $showingImportPicker, allowedContentTypes: [.json]) { result in
                handleImport(result: result)
            }
            .alert("Import Result", isPresented: $showingImportAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(importAlertMessage)
            }
        }
    }
    
    private func deleteWords(in section: WordSection, offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let wordToDelete = section.words[index]
                modelContext.delete(wordToDelete)
            }
        }
    }
    
    private func exportWords() {
        let export = VocabularyExport(words: words)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(export)
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: Date())
            let filename = "vocabulary_\(dateString).json"
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: tempURL)
            
            exportFileURL = tempURL
            showingExportSheet = true
        } catch {
            print("Export error: \(error)")
        }
    }
    
    private func exportPDF() {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792)) // US Letter size
        
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let dateString = dateFormatter.string(from: Date())
            let filename = "vocabulary_\(dateString).pdf"
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            
            try pdfRenderer.writePDF(to: tempURL) { context in
                context.beginPage()
                
                let titleFont = UIFont.boldSystemFont(ofSize: 24)
                let headerFont = UIFont.boldSystemFont(ofSize: 14)
                let bodyFont = UIFont.systemFont(ofSize: 12)
                
                var yPosition: CGFloat = 50
                
                // Title
                let title = "My Vocabulary List"
                let titleAttributes: [NSAttributedString.Key: Any] = [.font: titleFont]
                let titleSize = title.size(withAttributes: titleAttributes)
                title.draw(at: CGPoint(x: (612 - titleSize.width) / 2, y: yPosition), withAttributes: titleAttributes)
                yPosition += titleSize.height + 10
                
                // Date
                let dateText = "Exported: \(dateString)"
                let dateAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.gray]
                let dateSize = dateText.size(withAttributes: dateAttributes)
                dateText.draw(at: CGPoint(x: (612 - dateSize.width) / 2, y: yPosition), withAttributes: dateAttributes)
                yPosition += dateSize.height + 20
                
                // Total words
                let totalText = "Total Words: \(words.count)"
                let totalAttributes: [NSAttributedString.Key: Any] = [.font: headerFont]
                totalText.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: totalAttributes)
                yPosition += 30
                
                // Words list
                let sortedWords = words.sorted { $0.timestamp < $1.timestamp }
                
                for (index, word) in sortedWords.enumerated() {
                    // Check if we need a new page
                    if yPosition > 720 {
                        context.beginPage()
                        yPosition = 50
                    }
                    
                    // Format: "1. book : kitap , reserve"
                    var wordText = "\(index + 1). \(word.english) : \(word.turkish)"
                    
                    // Add alternatives if they exist
                    var alternatives: [String] = []
                    if let engAlt = word.englishAlt, !engAlt.isEmpty {
                        alternatives.append(engAlt)
                    }
                    if let turAlt = word.turkishAlt, !turAlt.isEmpty {
                        alternatives.append(turAlt)
                    }
                    
                    if !alternatives.isEmpty {
                        wordText += " , " + alternatives.joined(separator: " , ")
                    }
                    
                    let wordAttributes: [NSAttributedString.Key: Any] = [.font: bodyFont]
                    wordText.draw(at: CGPoint(x: 50, y: yPosition), withAttributes: wordAttributes)
                    yPosition += 20
                }
            }
            
            exportFileURL = tempURL
            showingExportSheet = true
        } catch {
            print("PDF export error: \(error)")
        }
    }
    
    private func handleImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            importWords(from: url)
        case .failure(let error):
            importAlertMessage = "Failed to select file: \(error.localizedDescription)"
            showingImportAlert = true
        }
    }
    
    private func importWords(from url: URL) {
        do {
            guard url.startAccessingSecurityScopedResource() else {
                importAlertMessage = "Cannot access file"
                showingImportAlert = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let export = try decoder.decode(VocabularyExport.self, from: data)
            
            // Import words
            for wordExport in export.words {
                let newWord = wordExport.toWord()
                modelContext.insert(newWord)
            }
            
            importAlertMessage = "Successfully imported \(export.words.count) words!"
            showingImportAlert = true
        } catch {
            importAlertMessage = "Import failed: \(error.localizedDescription)"
            showingImportAlert = true
        }
    }
}

// MARK: - Word Row Card

struct WordRowView: View {
    let word: Word

    private var accuracy: Double {
        let total = word.correctCount + word.wrongCount
        guard total > 0 else { return -1 }
        return Double(word.correctCount) / Double(total)
    }

    private var accentColor: Color {
        if accuracy < 0    { return DS.Colors.primary.opacity(0.3) }
        if accuracy >= 0.7 { return DS.Colors.success }
        if accuracy >= 0.4 { return DS.Colors.warning }
        return DS.Colors.danger
    }

    private var accuracyText: String {
        guard accuracy >= 0 else { return "" }
        return "\(Int(accuracy * 100))%"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left performance accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 4)
                .padding(.vertical, DS.Spacing.sm)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    if let alt = word.englishAlt, !alt.isEmpty {
                        Text("\(word.english) (\(alt))")
                            .font(.dsHeadline)
                    } else {
                        Text(word.english)
                            .font(.dsHeadline)
                    }

                    if let alt = word.turkishAlt, !alt.isEmpty {
                        Text("\(word.turkish) (\(alt))")
                            .font(.dsCallout)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(word.turkish)
                            .font(.dsCallout)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if accuracy >= 0 {
                    Text(accuracyText)
                        .font(.dsCaption)
                        .fontWeight(.semibold)
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(accentColor.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm + DS.Spacing.xs)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// Helper for sharing files
struct DocumentPicker: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [url])
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Alphabet Index Bar Component

struct AlphabetIndexBar: View {
    let letters: [String]
    let onSelectLetter: (String) -> Void
    @State private var activeLetter: String? = nil

    var body: some View {
        VStack(spacing: 2) {
            ForEach(letters, id: \.self) { letter in
                Text(letter)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(activeLetter == letter ? DS.Colors.primary : Color.secondary)
                    .frame(width: 18, height: 16)
                    .onTapGesture {
                        activeLetter = letter
                        onSelectLetter(letter)
                    }
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 2)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Word.self, inMemory: true)
}
