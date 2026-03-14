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
            .tag(2)
            
            StatisticsView()
                .tabItem {
                    Label("Statistics", systemImage: "chart.bar.fill")
                }
                .tag(3)
        }
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

struct VocabularyListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Word.timestamp, order: .reverse) private var words: [Word]
    
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var exportFileURL: URL?
    @State private var showingImportAlert = false
    @State private var importAlertMessage = ""
    @State private var searchText = ""
    
    var filteredWords: [Word] {
        if searchText.isEmpty {
            return words
        } else {
            return words.filter { word in
                word.english.localizedCaseInsensitiveContains(searchText) ||
                word.turkish.localizedCaseInsensitiveContains(searchText) ||
                (word.englishAlt?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (word.turkishAlt?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if words.isEmpty {
                    ContentUnavailableView("No Words Yet", systemImage: "text.book.closed", description: Text("Tap + to add your first word."))
                } else if filteredWords.isEmpty {
                    ContentUnavailableView.search
                } else {
                    ForEach(filteredWords) { word in
                        NavigationLink(destination: EditWordView(word: word)) {
                            HStack {
                                VStack(alignment: .leading) {
                                    // English with alternative
                                    if let englishAlt = word.englishAlt, !englishAlt.isEmpty {
                                        Text("\(word.english) (\(englishAlt))")
                                            .font(.headline)
                                    } else {
                                        Text(word.english)
                                            .font(.headline)
                                    }
                                    
                                    // Turkish with alternative
                                    if let turkishAlt = word.turkishAlt, !turkishAlt.isEmpty {
                                        Text("\(word.turkish) (\(turkishAlt))")
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text(word.turkish)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                // Simple stats
                                if word.correctCount > 0 || word.wrongCount > 0 {
                                    VStack(alignment: .trailing) {
                                        HStack(spacing: 4) {
                                            Text("\(word.correctCount)").foregroundStyle(.green)
                                            Text("/").foregroundStyle(.secondary)
                                            Text("\(word.wrongCount)").foregroundStyle(.red)
                                        }
                                        .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteWords)
                }
            }
            .navigationTitle("Vocabulary")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search words")
            .toolbar {
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
    
    private func deleteWords(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let wordToDelete = filteredWords[index]
                if let originalIndex = words.firstIndex(where: { $0.id == wordToDelete.id }) {
                    modelContext.delete(words[originalIndex])
                }
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

#Preview {
    ContentView()
        .modelContainer(for: Word.self, inMemory: true)
}
