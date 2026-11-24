//
//  BulkImportParser.swift
//  VocabularyPool
//
//  Unlimited bulk parser for Paste Word Lists and CSV files with live duplicate detection.
//

import Foundation

struct ParsedWordEntry: Identifiable, Hashable {
    let id = UUID()
    let english: String
    let turkishMeanings: [String]
    let v2: String?
    let v3: String?

    var formattedTurkish: String {
        turkishMeanings.joined(separator: " • ")
    }
}

struct BulkImportPreview {
    let newEntries: [ParsedWordEntry]
    let duplicateEntries: [ParsedWordEntry]
    let invalidLines: [String]

    var totalParsed: Int {
        newEntries.count + duplicateEntries.count
    }
}

enum BulkImportParser {

    /// Parses unlimited plain-text lines (supports `-`, `:`, `=`, `Tab` separators and comma-separated meanings).
    static func parsePlainText(_ text: String, existingWords: [Word]) -> BulkImportPreview {
        let existingSet = Set(existingWords.map { normalizeKey($0.english) })
        var seenInBatch = Set<String>()

        var newEntries: [ParsedWordEntry] = []
        var duplicates: [ParsedWordEntry] = []
        var invalidLines: [String] = []

        let lines = text.components(separatedBy: .newlines)

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            // Strip optional leading list bullets or numbering like "1. ", "- ", "• "
            let cleanedLine = stripLeadingListPrefix(line)

            guard let (rawEnglish, rawTurkish) = splitPair(cleanedLine) else {
                invalidLines.append(line)
                continue
            }

            let english = rawEnglish.trimmingCharacters(in: .whitespacesAndNewlines)
            let meanings = splitMeanings(rawTurkish)

            guard !english.isEmpty, !meanings.isEmpty else {
                invalidLines.append(line)
                continue
            }

            let key = normalizeKey(english)
            let entry = ParsedWordEntry(english: english, turkishMeanings: meanings, v2: nil, v3: nil)

            if existingSet.contains(key) || !seenInBatch.insert(key).inserted {
                duplicates.append(entry)
            } else {
                newEntries.append(entry)
            }
        }

        return BulkImportPreview(
            newEntries: newEntries,
            duplicateEntries: duplicates,
            invalidLines: invalidLines
        )
    }

    /// Parses unlimited CSV rows (`english,turkish` or `english;turkish`, optional `v2,v3` columns).
    static func parseCSV(_ csvText: String, existingWords: [Word]) -> BulkImportPreview {
        let existingSet = Set(existingWords.map { normalizeKey($0.english) })
        var seenInBatch = Set<String>()

        var newEntries: [ParsedWordEntry] = []
        var duplicates: [ParsedWordEntry] = []
        var invalidLines: [String] = []

        let lines = csvText.components(separatedBy: .newlines)
        let delimiter: Character = detectCSVDelimiter(in: lines)

        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            let columns = parseCSVRow(line, delimiter: delimiter)
            guard columns.count >= 2 else {
                invalidLines.append(line)
                continue
            }

            let english = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let turkishRaw = columns[1].trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip common header rows
            if index == 0 && isHeaderRow(english: english, turkish: turkishRaw) {
                continue
            }

            let meanings = splitMeanings(turkishRaw)
            guard !english.isEmpty, !meanings.isEmpty else {
                invalidLines.append(line)
                continue
            }

            let v2 = columns.count > 2 ? nonEmpty(columns[2]) : nil
            let v3 = columns.count > 3 ? nonEmpty(columns[3]) : nil

            let key = normalizeKey(english)
            let entry = ParsedWordEntry(english: english, turkishMeanings: meanings, v2: v2, v3: v3)

            if existingSet.contains(key) || !seenInBatch.insert(key).inserted {
                duplicates.append(entry)
            } else {
                newEntries.append(entry)
            }
        }

        return BulkImportPreview(
            newEntries: newEntries,
            duplicateEntries: duplicates,
            invalidLines: invalidLines
        )
    }

    // MARK: - Private Helpers

    private static func normalizeKey(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func stripLeadingListPrefix(_ line: String) -> String {
        var result = line
        // Strip leading bullets: "• ", "* "
        for prefix in ["• ", "* ", "– ", "— "] {
            if result.hasPrefix(prefix) {
                result = String(result.dropFirst(prefix.count))
                break
            }
        }
        // Strip leading numbering like "1. ", "12) ", "3 - "
        if let regex = try? NSRegularExpression(pattern: #"^\d+[\.\)\-]\s+"#) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func splitPair(_ line: String) -> (String, String)? {
        // Priority order: Tab, " - ", " – ", " — ", ":", "="
        let separators = ["\t", " - ", " – ", " — ", ":", "=", "-"]
        for sep in separators {
            if let range = line.range(of: sep) {
                let left = String(line[..<range.lowerBound])
                let right = String(line[range.upperBound...])
                if !left.trimmingCharacters(in: .whitespaces).isEmpty,
                   !right.trimmingCharacters(in: .whitespaces).isEmpty {
                    return (left, right)
                }
            }
        }
        return nil
    }

    private static func splitMeanings(_ raw: String) -> [String] {
        // Split on comma or slash or semicolon
        let parts = raw.components(separatedBy: CharacterSet(charactersIn: ",;/"))
        var result: [String] = []
        var seen = Set<String>()
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed.lowercased()).inserted {
                result.append(trimmed)
            }
        }
        return result
    }

    private static func detectCSVDelimiter(in lines: [String]) -> Character {
        let sample = lines.prefix(5).joined(separator: "\n")
        let semicolons = sample.filter { $0 == ";" }.count
        let commas = sample.filter { $0 == "," }.count
        return semicolons > commas ? ";" : ","
    }

    private static func parseCSVRow(_ row: String, delimiter: Character) -> [String] {
        var columns: [String] = []
        var current = ""
        var inQuotes = false

        for char in row {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == delimiter && !inQuotes {
                columns.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        columns.append(current)
        return columns
    }

    private static func isHeaderRow(english: String, turkish: String) -> Bool {
        let e = english.lowercased()
        let t = turkish.lowercased()
        return (e == "english" || e == "word" || e == "ingilizce")
            && (t == "turkish" || t == "meaning" || t == "turkce" || t == "türkçe" || t == "meanings")
    }
}
