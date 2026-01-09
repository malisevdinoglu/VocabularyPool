//
//  CustomNotification.swift
//  VocabularyPool
//
//  Created by Assistant on 08.01.2026.
//

import Foundation
import SwiftData

@Model
final class CustomNotification {
    var id: UUID
    var title: String
    var body: String
    var hour: Int
    var minute: Int
    var weekdays: [Int] // 1=Sunday, 2=Monday, ..., 7=Saturday
    var isEnabled: Bool
    var createdAt: Date
    
    init(title: String, body: String, hour: Int, minute: Int, weekdays: [Int] = [], isEnabled: Bool = true) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.hour = hour
        self.minute = minute
        self.weekdays = weekdays
        self.isEnabled = isEnabled
        self.createdAt = Date()
    }
    
    var formattedTime: String {
        String(format: "%02d:%02d", hour, minute)
    }
    
    var weekdayNames: String {
        if weekdays.isEmpty {
            return "Her gün"
        }
        
        let dayNames = ["Paz", "Pzt", "Sal", "Çar", "Per", "Cum", "Cmt"]
        let selectedDays = weekdays.sorted().compactMap { day -> String? in
            guard day >= 1 && day <= 7 else { return nil }
            return dayNames[day - 1]
        }
        
        if selectedDays.count == 7 {
            return "Her gün"
        }
        
        return selectedDays.joined(separator: ", ")
    }
}
