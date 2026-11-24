//
//  ExportImportService.swift
//  VocabularyPool
//
//  Backward-compatible JSON Backup/Restore (duplicate-safe) and PDF export service.
//

import Foundation
import SwiftData
import UIKit

// MARK: - Codable Export Models

struct WordExport: Codable, Identifiable {
    var id: UUID
    var english: String
    var turkish: String
    var englishAlt: String?
    var turkishAlt: String?
    var additionalTurkish: [String]?
    var isVerb: Bool?
    var isPhrasalVerb: Bool?
    var v2: String?
    var v3: String?
    var correctCount: Int
    var wrongCount: Int
    var consecutiveCorrect: Int?
    var masteryLevel: Int?
    var intervalDays: Int?
    var nextReviewDate: Date?
    var needsReview: Bool?
    var lastStudied: Date?
    var timestamp: Date

    init(from word: Word) {
        self.id = UUID()
        self.english = word.english
        self.turkish = word.turkish
        self.englishAlt = word.englishAlt
        self.turkishAlt = word.turkishAlt
        let extras = Array(word.allTurkishMeanings.dropFirst(2))
        self.additionalTurkish = extras.isEmpty ? nil : extras
        self.isVerb = word.isVerb
        self.isPhrasalVerb = word.isPhrasalVerb
        self.v2 = word.v2
        self.v3 = word.v3
        self.correctCount = word.correctCount
        self.wrongCount = word.wrongCount
        self.consecutiveCorrect = word.consecutiveCorrect
        self.masteryLevel = word.masteryLevel
        self.intervalDays = word.intervalDays
        self.nextReviewDate = word.nextReviewDate
        self.needsReview = word.needsReview
        self.lastStudied = word.lastStudied
        self.timestamp = word.timestamp
    }

    func toWord() -> Word {
        let word = Word(
            english: english,
            turkish: turkish,
            englishAlt: englishAlt,
            turkishAlt: turkishAlt,
            additionalTurkish: additionalTurkish ?? [],
            isVerb: isVerb ?? false,
            isPhrasalVerb: isPhrasalVerb ?? false,
            v2: v2,
            v3: v3,
            timestamp: timestamp
        )
        word.correctCount = correctCount
        word.wrongCount = wrongCount
        word.consecutiveCorrect = consecutiveCorrect ?? 0
        word.masteryLevel = masteryLevel ?? 0
        word.intervalDays = intervalDays ?? 0
        word.nextReviewDate = nextReviewDate
        word.needsReview = needsReview ?? (wrongCount > 0 && Double(correctCount) / Double(max(1, correctCount + wrongCount)) < 0.70)
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
        self.version = "2.0"
    }
}

struct JSONImportResult {
    let importedCount: Int
    let skippedDuplicates: Int
}

// MARK: - Service

enum ExportImportService {

    static func exportJSON(words: [Word]) throws -> URL {
        let export = VocabularyExport(words: words)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(export)

        let filename = "vocabulary_\(dateStamp()).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: tempURL)
        return tempURL
    }

    @MainActor
    static func importJSON(from url: URL, existingWords: [Word], into modelContext: ModelContext) throws -> JSONImportResult {
        guard url.startAccessingSecurityScopedResource() else {
            throw NSError(domain: "ExportImportService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cannot access selected file."])
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let export = try decoder.decode(VocabularyExport.self, from: data)

        var existingKeys = Set(existingWords.map { $0.english.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
        var importedCount = 0
        var skippedDuplicates = 0

        for wordExport in export.words {
            let key = wordExport.english.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { continue }

            if existingKeys.insert(key).inserted {
                modelContext.insert(wordExport.toWord())
                importedCount += 1
            } else {
                skippedDuplicates += 1
            }
        }

        try? modelContext.save()
        return JSONImportResult(importedCount: importedCount, skippedDuplicates: skippedDuplicates)
    }

    static func exportPDF(words: [Word]) throws -> URL {
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let filename = "vocabulary_\(dateStamp()).pdf"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        try pdfRenderer.writePDF(to: tempURL) { context in
            context.beginPage()

            let titleFont = UIFont.boldSystemFont(ofSize: 22)
            let headerFont = UIFont.boldSystemFont(ofSize: 13)
            let bodyFont = UIFont.systemFont(ofSize: 11.5)

            var yPosition: CGFloat = 50

            let title = "VocabularyPool — Word List"
            let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont]
            let titleSize = title.size(withAttributes: titleAttrs)
            title.draw(at: CGPoint(x: (612 - titleSize.width) / 2, y: yPosition), withAttributes: titleAttrs)
            yPosition += titleSize.height + 8

            let subtitle = "Exported \(dateStamp()) • \(words.count) words"
            let subAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: UIColor.gray]
            let subSize = subtitle.size(withAttributes: subAttrs)
            subtitle.draw(at: CGPoint(x: (612 - subSize.width) / 2, y: yPosition), withAttributes: subAttrs)
            yPosition += subSize.height + 24

            let sortedWords = words.sorted { $0.timestamp < $1.timestamp }
            let bodyAttrs: [NSAttributedString.Key: Any] = [.font: bodyFont]
            let boldAttrs: [NSAttributedString.Key: Any] = [.font: headerFont]

            for (index, word) in sortedWords.enumerated() {
                if yPosition > 730 {
                    context.beginPage()
                    yPosition = 50
                }

                var line = "\(index + 1). \(word.english)"
                if word.hasConjugations, let v2 = word.v2, let v3 = word.v3 {
                    line += " (\(v2), \(v3))"
                }
                line += " — \(word.formattedTurkishMeanings)"

                let attrs = index == 0 ? bodyAttrs : bodyAttrs
                _ = boldAttrs
                line.draw(at: CGPoint(x: 48, y: yPosition), withAttributes: attrs)
                yPosition += 19
            }
        }

        return tempURL
    }

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
