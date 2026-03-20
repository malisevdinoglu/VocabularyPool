//
//  AppMigrationPlan.swift
//  VocabularyPool
//
//  Defines the SwiftData schema versions and lightweight migration plan.
//  Add a new VersionedSchema + MigrationStage whenever the data model changes.
//

import SwiftData
import Foundation

// MARK: - Schema V1 (original — Word without needsReview)

enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [SchemaV1.Word.self, PracticeSession.self, CustomNotification.self, WordAdditionTracker.self]
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
}

// MARK: - Schema V2 (current — Word with needsReview)

enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Word.self, PracticeSession.self, CustomNotification.self, WordAdditionTracker.self]
    }
}

// MARK: - Migration Plan

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [VersionedSchema.Type] { [SchemaV1.self, SchemaV2.self] }
    static var stages: [MigrationStage] { [migrateV1toV2] }

    /// Lightweight migration: adds the needsReview column with default false.
    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self
    )
}
