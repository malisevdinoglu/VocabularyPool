//
//  GoalsSettingsView.swift
//  VocabularyPool
//
//  Created by Assistant on 02.02.2026.
//

import SwiftUI

struct GoalsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var goals = PracticeGoals.shared
    
    @State private var tempEngToTr: Int = 0
    @State private var tempTrToEng: Int = 0
    @State private var tempListening: Int = 0
    @State private var weekOffset: Int = 0 // 0 = current week, -1 = last week, +1 = next week
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Week Selector Header
                HStack(spacing: DS.Spacing.md) {
                    Button {
                        weekOffset -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.Colors.primary)
                            .frame(width: 36, height: 36)
                            .background(DS.Colors.primary.opacity(0.10))
                            .clipShape(Circle())
                    }

                    Spacer()

                    VStack(spacing: 2) {
                        Text(weekRangeText)
                            .font(.dsHeadline)
                        if weekOffset == 0 {
                            Text("Bu Hafta")
                                .font(.dsCaption)
                                .foregroundStyle(DS.Colors.primary)
                        } else if weekOffset < 0 {
                            Text("\(-weekOffset) hafta önce")
                                .font(.dsCaption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("\(weekOffset) hafta sonra")
                                .font(.dsCaption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        weekOffset += 1
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.Colors.primary)
                            .frame(width: 36, height: 36)
                            .background(DS.Colors.primary.opacity(0.10))
                            .clipShape(Circle())
                    }
                }
                .padding(DS.Spacing.md)
                .background(Color(uiColor: .systemGroupedBackground))

                // Goals Form
                Form {
                    Section {
                        GoalStepperRow(
                            icon: "globe",
                            color: DS.Colors.trToEng,
                            label: "Turkish → English",
                            value: $tempTrToEng
                        )
                        GoalStepperRow(
                            icon: "text.book.closed.fill",
                            color: DS.Colors.engToTr,
                            label: "English → Turkish",
                            value: $tempEngToTr
                        )
                        GoalStepperRow(
                            icon: "headphones",
                            color: DS.Colors.listening,
                            label: "Listening",
                            value: $tempListening
                        )
                    } header: {
                        Text("Günlük Hedefler")
                    } footer: {
                        Text("Bu hedefler hafta boyunca (Pazartesi-Pazar) geçerli olacak.")
                            .font(.dsCaption)
                    }
                }
            }
            .navigationTitle("Hedefler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        saveGoals()
                        dismiss()
                    }
                    .disabled(weekOffset != 0) // Only allow saving for current week
                }
            }
            .onAppear {
                tempEngToTr = goals.englishToTurkishGoal
                tempTrToEng = goals.turkishToEnglishGoal
                tempListening = goals.listeningGoal
            }
        }
    }
    
    private func saveGoals() {
        goals.englishToTurkishGoal = tempEngToTr
        goals.turkishToEnglishGoal = tempTrToEng
        goals.listeningGoal = tempListening
        goals.saveGoals()
    }
    
    var weekRangeText: String {
        let calendar = Calendar.current
        let currentWeekStart = goals.getWeekStart()
        
        // Calculate week based on offset
        guard let offsetWeekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart) else {
            return ""
        }
        
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: offsetWeekStart) else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        formatter.locale = Locale(identifier: "tr_TR")
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MMMM"
        monthFormatter.locale = Locale(identifier: "tr_TR")
        
        let startDay = formatter.string(from: offsetWeekStart)
        let endDay = formatter.string(from: weekEnd)
        let month = monthFormatter.string(from: offsetWeekStart)
        
        // Check if same month
        if calendar.component(.month, from: offsetWeekStart) == calendar.component(.month, from: weekEnd) {
            return "\(startDay)-\(endDay) \(month)"
        } else {
            let endMonth = monthFormatter.string(from: weekEnd)
            return "\(startDay) \(month) - \(endDay) \(endMonth)"
        }
    }
}

// MARK: - Goal Stepper Row

struct GoalStepperRow: View {
    let icon: String
    let color: Color
    let label: String
    @Binding var value: Int

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            DSIconBadge(systemImage: icon, color: color)
            Stepper("\(label): \(value)", value: $value, in: 0...100, step: 5)
        }
    }
}

#Preview {
    GoalsSettingsView()
}
