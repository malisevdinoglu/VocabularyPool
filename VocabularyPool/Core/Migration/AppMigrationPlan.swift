//
//  AppMigrationPlan.swift
//  VocabularyPool
//
//  Defines the SwiftData schema versions and lightweight migration plan.
//  Add a new VersionedSchema + MigrationStage whenever the data model changes.
//

import SwiftData
import Foundation

// MARK: - Schema V1 (original — Word without needsReview & PracticeSession without verbConjugationsCount)

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [SchemaV1.Word.self, SchemaV1.PracticeSession.self, CustomNotification.self, WordAdditionTracker.self]
    }

    @Model
    final class Word {
        var english: String = ""
        var turkish: String = ""
        var englishAlt: String?
        var turkishAlt: String?
        var correctCount: Int = 0
        var wrongCount: Int = 0
        var lastStudied: Date?
        var timestamp: Date = Date()

        init() {}
    }

    @Model
    final class PracticeSession {
        var date: Date = Date()
        var englishToTurkishCount: Int = 0
        var turkishToEnglishCount: Int = 0
        var listeningCount: Int = 0
        var audioListeningCount: Int = 0
        var flashcardsCount: Int = 0
        var matchingCount: Int = 0
        var dailyGoalEngToTr: Int = 0
        var dailyGoalTrToEng: Int = 0
        var dailyGoalListening: Int = 0

        init() {}
    }
}

// MARK: - Schema V2 (Word with needsReview)

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [SchemaV2.Word.self, SchemaV2.PracticeSession.self, CustomNotification.self, WordAdditionTracker.self]
    }

    @Model
    final class Word {
        var english: String = ""
        var turkish: String = ""
        var englishAlt: String?
        var turkishAlt: String?
        var correctCount: Int = 0
        var wrongCount: Int = 0
        var lastStudied: Date?
        var timestamp: Date = Date()
        var needsReview: Bool = false

        init() {}
    }

    @Model
    final class PracticeSession {
        var date: Date = Date()
        var englishToTurkishCount: Int = 0
        var turkishToEnglishCount: Int = 0
        var listeningCount: Int = 0
        var audioListeningCount: Int = 0
        var flashcardsCount: Int = 0
        var matchingCount: Int = 0
        var dailyGoalEngToTr: Int = 0
        var dailyGoalTrToEng: Int = 0
        var dailyGoalListening: Int = 0

        init() {}
    }
}

// MARK: - Schema V3 (Word with isVerb, v2, v3 & PracticeSession with verbConjugationsCount)

enum SchemaV3: VersionedSchema {
    static var versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [SchemaV3.Word.self, SchemaV4.PracticeSession.self, CustomNotification.self, WordAdditionTracker.self]
    }

    @Model
    final class Word {
        var english: String = ""
        var turkish: String = ""
        var englishAlt: String?
        var turkishAlt: String?
        var correctCount: Int = 0
        var wrongCount: Int = 0
        var lastStudied: Date?
        var timestamp: Date = Date()
        var needsReview: Bool = false
        var isVerb: Bool = false
        var v2: String?
        var v3: String?

        init() {}
    }
}

// MARK: - Schema V4 (Word with isPhrasalVerb)

enum SchemaV4: VersionedSchema {
    static var versionIdentifier = Schema.Version(4, 0, 0)

    static var models: [any PersistentModel.Type] {
        [SchemaV5.Word.self, SchemaV4.PracticeSession.self, CustomNotification.self, WordAdditionTracker.self]
    }

    @Model
    final class PracticeSession {
        var date: Date = Date()
        var englishToTurkishCount: Int = 0
        var turkishToEnglishCount: Int = 0
        var listeningCount: Int = 0
        var audioListeningCount: Int = 0
        var flashcardsCount: Int = 0
        var matchingCount: Int = 0
        var verbConjugationsCount: Int = 0
        var dailyGoalEngToTr: Int = 0
        var dailyGoalTrToEng: Int = 0
        var dailyGoalListening: Int = 0

        init() {}
    }
}

// MARK: - Schema V5 (Frozen — PracticeSession with phrasalVerbsCount)

enum SchemaV5: VersionedSchema {
    static var versionIdentifier = Schema.Version(5, 0, 0)

    static var models: [any PersistentModel.Type] {
        [SchemaV5.Word.self, SchemaV5.PracticeSession.self, CustomNotification.self, WordAdditionTracker.self]
    }

    @Model
    final class Word {
        var english: String = ""
        var turkish: String = ""
        var englishAlt: String?
        var turkishAlt: String?
        var correctCount: Int = 0
        var wrongCount: Int = 0
        var lastStudied: Date?
        var timestamp: Date = Date()
        var needsReview: Bool = false
        var isVerb: Bool = false
        var v2: String?
        var v3: String?
        var isPhrasalVerb: Bool = false

        init() {}
    }

    @Model
    final class PracticeSession {
        var date: Date = Date()
        var englishToTurkishCount: Int = 0
        var turkishToEnglishCount: Int = 0
        var listeningCount: Int = 0
        var audioListeningCount: Int = 0
        var flashcardsCount: Int = 0
        var matchingCount: Int = 0
        var verbConjugationsCount: Int = 0
        var phrasalVerbsCount: Int = 0
        var dailyGoalEngToTr: Int = 0
        var dailyGoalTrToEng: Int = 0
        var dailyGoalListening: Int = 0

        init() {}
    }
}

// MARK: - Schema V6 (Current — Multi-meaning, SRS/Mastery fields & MultipleChoice/SmartMix counts)

enum SchemaV6: VersionedSchema {
    static var versionIdentifier = Schema.Version(6, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Word.self, PracticeSession.self, CustomNotification.self, WordAdditionTracker.self]
    }
}

// MARK: - Migration Plan

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self, SchemaV4.self, SchemaV5.self, SchemaV6.self]
    }

    static var stages: [MigrationStage] {
        [migrateV1toV2, migrateV2toV3, migrateV3toV4, migrateV4toV5, migrateV5toV6]
    }

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )

    static let migrateV2toV3 = MigrationStage.lightweight(
        fromVersion: SchemaV2.self,
        toVersion: SchemaV3.self
    )

    static let migrateV3toV4 = MigrationStage.lightweight(
        fromVersion: SchemaV3.self,
        toVersion: SchemaV4.self
    )

    static let migrateV4toV5 = MigrationStage.lightweight(
        fromVersion: SchemaV4.self,
        toVersion: SchemaV5.self
    )

    static let migrateV5toV6 = MigrationStage.lightweight(
        fromVersion: SchemaV5.self,
        toVersion: SchemaV6.self
    )
}
