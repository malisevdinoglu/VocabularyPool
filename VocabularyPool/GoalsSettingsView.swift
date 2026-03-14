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
                HStack {
                    Button {
                        weekOffset -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                    
                    Spacer()
                    
                    Text(weekRangeText)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Button {
                        weekOffset += 1
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                }
                .padding()
                .background(Color(uiColor: .systemGroupedBackground))
                
                // Goals Form
                Form {
                    Section {
                        Stepper("Turkish → English: \(tempTrToEng)", 
                               value: $tempTrToEng, in: 0...100, step: 5)
                        
                        Stepper("English → Turkish: \(tempEngToTr)", 
                               value: $tempEngToTr, in: 0...100, step: 5)
                        
                        Stepper("Listening: \(tempListening)", 
                               value: $tempListening, in: 0...100, step: 5)
                    } header: {
                        Text("Günlük Hedefler")
                    } footer: {
                        Text("Bu hedefler hafta boyunca (Pazartesi-Pazar) geçerli olacak.")
                            .font(.caption)
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

#Preview {
    GoalsSettingsView()
}
