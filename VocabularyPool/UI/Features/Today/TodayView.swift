//
//  TodayView.swift
//  VocabularyPool
//
//  Action-First daily learning hub: Goal Ring + Streak + One-Tap Smart Mix + Weak Words + Daily History.
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \Word.timestamp, order: .reverse) private var words: [Word]
    @Query(sort: \PracticeSession.date, order: .reverse) private var sessions: [PracticeSession]

    @AppStorage("dailyPracticeGoal") private var dailyGoal: Int = 20

    let onTapAddWord: () -> Void

    @State private var showingDailySession = false
    @State private var showingWeakSession = false
    @State private var showingHistorySheet = false
    @State private var showingGoalSheet = false

    // MARK: - Derived Metrics

    private var todayCount: Int {
        let calendar = Calendar.current
        return sessions
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.totalCount }
    }

    private var goalProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(1.0, Double(todayCount) / Double(dailyGoal))
    }

    private var isGoalCompleted: Bool {
        dailyGoal > 0 && todayCount >= dailyGoal
    }

    private var streakDays: Int {
        LearningEngine.calculateStreak(from: sessions)
    }

    private var weakWords: [Word] {
        words.filter { $0.isWeak }
    }

    private var dueCount: Int {
        words.filter { $0.isDueForReview }.count
    }

    private var masteredCount: Int {
        words.filter { $0.masteryLevel >= 4 && !$0.isWeak }.count
    }

    private var newCount: Int {
        words.filter { $0.isNew }.count
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {

                // Subtitle Date & Greeting
                VStack(alignment: .leading, spacing: 2) {
                    Text(Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.dsCaption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                    Text(greeting)
                        .font(.dsTitle)
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 2)

                // MARK: - Action-First Hero Card
                dailySessionHeroCard

                // MARK: - Secondary Summary Row (Weak Words + Today's Activity)
                HStack(spacing: DS.Spacing.md) {
                    weakWordsCard
                    todayActivityCard
                }

                // MARK: - Pool Snapshot
                if !words.isEmpty {
                    poolSnapshotCard
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
        }
        .background(DS.Surfaces.canvas.ignoresSafeArea())
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
            }
        }
        .sheet(isPresented: $showingHistorySheet) {
            DailyHistorySheet(sessions: sessions)
        }
        .sheet(isPresented: $showingGoalSheet) {
            GoalEditorSheet(dailyGoal: $dailyGoal)
        }
        .navigationDestination(isPresented: $showingDailySession) {
            SmartMixSessionView(weakOnly: false, targetCount: min(15, max(5, words.count)))
        }
        .navigationDestination(isPresented: $showingWeakSession) {
            SmartMixSessionView(weakOnly: true, targetCount: min(15, max(1, weakWords.count)))
        }
    }

    // MARK: - Hero Card

    private var dailySessionHeroCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            HStack(spacing: DS.Spacing.md) {
                // Tappable Goal Ring
                Button {
                    Haptics.light()
                    showingGoalSheet = true
                } label: {
                    ZStack {
                        DSProgressRing(
                            progress: goalProgress,
                            lineWidth: 7,
                            size: 72,
                            tint: isGoalCompleted ? DS.Colors.success : DS.Colors.primary
                        )

                        VStack(spacing: 0) {
                            if isGoalCompleted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(DS.Colors.success)
                            } else {
                                Text("\(todayCount)")
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                                Text("/\(dailyGoal)")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .buttonStyle(DSSpringButtonStyle())
                .accessibilityLabel("Daily Goal \(todayCount) of \(dailyGoal). Tap to edit.")

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: DS.Spacing.sm) {
                        Text(isGoalCompleted ? "Daily Goal Reached" : "Daily Smart Session")
                            .font(.dsHeadline)
                            .foregroundStyle(.primary)

                        Spacer(minLength: 0)

                        // Streak Pill
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("\(streakDays)")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(streakDays > 0 ? DS.Colors.warning : .secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background((streakDays > 0 ? DS.Colors.warning : Color.secondary).opacity(0.11))
                        .clipShape(Capsule())
                    }

                    Text(heroSubtitle)
                        .font(.dsCallout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        Haptics.light()
                        showingGoalSheet = true
                    } label: {
                        Text("Goal: \(dailyGoal) / day • Edit")
                            .font(.dsCaption)
                            .foregroundStyle(DS.Colors.primary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if words.isEmpty {
                DSPrimaryButton(
                    title: "Add Your First Word",
                    systemImage: "plus.circle.fill"
                ) {
                    onTapAddWord()
                }
            } else {
                DSPrimaryButton(
                    title: isGoalCompleted ? "Practice Extra Round" : "Start Daily Session",
                    systemImage: "play.fill",
                    color: isGoalCompleted ? DS.Colors.success : DS.Colors.primary
                ) {
                    showingDailySession = true
                }
            }
        }
        .dsCard(padding: DS.Spacing.lg, cornerRadius: DS.Radius.xl)
    }

    private var heroSubtitle: String {
        if words.isEmpty {
            return "Build your pool to unlock adaptive daily practice."
        }
        if isGoalCompleted {
            return "Great consistency today. Keep sharpening your pool with another mix."
        }
        if dueCount > 0 {
            return "\(dueCount) words ready for review, blended with new & general words."
        }
        return "A dynamic blend of Multiple Choice, Typing, and Listening."
    }

    // MARK: - Weak Words Card

    private var weakWordsCard: some View {
        Button {
            Haptics.light()
            if !weakWords.isEmpty {
                showingWeakSession = true
            }
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    DSIconBadge(
                        systemImage: "exclamationmark.triangle.fill",
                        color: weakWords.isEmpty ? DS.Colors.success : DS.Colors.danger
                    )
                    Spacer()
                    if !weakWords.isEmpty {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 4)

                Text("\(weakWords.count)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(weakWords.isEmpty ? "No Weak Words" : "Weak Words")
                    .font(.dsCallout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
            .dsCard()
        }
        .buttonStyle(DSSpringButtonStyle())
        .disabled(weakWords.isEmpty)
    }

    // MARK: - Today's Activity Card (Opens Daily History Sheet)

    private var todayActivityCard: some View {
        Button {
            Haptics.light()
            showingHistorySheet = true
        } label: {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    DSIconBadge(systemImage: "calendar", color: DS.Colors.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                Text("\(todayCount)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text("Today's History")
                    .font(.dsCallout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
            .dsCard()
        }
        .buttonStyle(DSSpringButtonStyle())
    }

    // MARK: - Pool Snapshot Strip

    private var poolSnapshotCard: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            DSSectionHeader(title: "Pool Overview")

            HStack(spacing: 0) {
                snapshotMetric(value: words.count, label: "Total", color: DS.Colors.primary)
                Divider().frame(height: 32)
                snapshotMetric(value: masteredCount, label: "Mastered", color: DS.Colors.success)
                Divider().frame(height: 32)
                snapshotMetric(value: newCount, label: "New", color: DS.Colors.accent)
            }
            .dsCard(padding: DS.Spacing.md)
        }
    }

    private func snapshotMetric(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(label)
                .font(.dsCaption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Inline Daily Goal Editor Sheet

struct GoalEditorSheet: View {
    @Binding var dailyGoal: Int
    @Environment(\.dismiss) private var dismiss

    private let presets = [10, 15, 20, 30, 40, 50]

    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.lg) {
                VStack(spacing: DS.Spacing.xs) {
                    Text("\(dailyGoal)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(DS.Colors.primary)
                    Text("questions & cards per day")
                        .font(.dsCallout)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, DS.Spacing.md)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.sm), count: 3), spacing: DS.Spacing.sm) {
                    ForEach(presets, id: \.self) { value in
                        Button {
                            Haptics.selection()
                            dailyGoal = value
                        } label: {
                            Text("\(value)")
                                .font(.dsHeadline)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(dailyGoal == value ? DS.Colors.primary : DS.Surfaces.card)
                                .foregroundStyle(dailyGoal == value ? DS.Colors.onColor : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                        .strokeBorder(dailyGoal == value ? Color.clear : DS.Surfaces.border, lineWidth: 1)
                                )
                        }
                        .buttonStyle(DSSpringButtonStyle())
                    }
                }
                .padding(.horizontal, DS.Spacing.md)

                Spacer()

                DSPrimaryButton(title: "Save Goal") {
                    dismiss()
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.bottom, DS.Spacing.md)
            }
            .background(DS.Surfaces.canvas.ignoresSafeArea())
            .navigationTitle("Daily Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
    }
}
