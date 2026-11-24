//
//  SessionRecorder.swift
//  VocabularyPool
//
//  Centralized daily PracticeSession persistence so practice views stay clean and DRY.
//

import Foundation
import SwiftData

enum SessionCategory {
    case englishToTurkish
    case turkishToEnglish
    case listening
    case audioListening
    case flashcards
    case matching
    case verbConjugations
    case phrasalVerbs
    case multipleChoice
    case smartMix
}

@MainActor
enum SessionRecorder {

    static func record(
        count: Int,
        category: SessionCategory,
        in modelContext: ModelContext,
        date: Date = Date()
    ) {
        guard count > 0 else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else { return }

        let descriptor = FetchDescriptor<PracticeSession>(
            predicate: #Predicate { session in
                session.date >= today && session.date < tomorrow
            }
        )

        do {
            let existing = try modelContext.fetch(descriptor)
            let session: PracticeSession
            if let found = existing.first {
                session = found
            } else {
                session = PracticeSession(date: today)
                modelContext.insert(session)
            }

            switch category {
            case .englishToTurkish:  session.englishToTurkishCount += count
            case .turkishToEnglish:  session.turkishToEnglishCount += count
            case .listening:         session.listeningCount += count
            case .audioListening:    session.audioListeningCount += count
            case .flashcards:        session.flashcardsCount += count
            case .matching:          session.matchingCount += count
            case .verbConjugations:  session.verbConjugationsCount += count
            case .phrasalVerbs:      session.phrasalVerbsCount += count
            case .multipleChoice:    session.multipleChoiceCount += count
            case .smartMix:          session.smartMixCount += count
            }

            try modelContext.save()
        } catch {
            print("SessionRecorder failed: \(error)")
        }
    }
}
