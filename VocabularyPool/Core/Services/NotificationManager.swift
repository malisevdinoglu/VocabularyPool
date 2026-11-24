//
//  NotificationManager.swift
//  VocabularyPool
//
//  Automatic hourly weak-word notification scheduler powered by the dynamic Weak / SRS state.
//

import Foundation
import UserNotifications
import Combine

class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    private let hourlyPrefix = "hourlyWeakWord_"

    private init() {}

    // MARK: - Permission

    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if let error {
                    print("Notification permission error: \(error)")
                }
                completion(granted)
            }
        }
    }

    func checkPermissionStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    // MARK: - Hourly Weak Word Notifications

    func scheduleHourlyWeakWordNotifications(words: [Word]) {
        cancelHourlyNotifications { [weak self] in
            guard let self else { return }

            let weakWords = words.filter { $0.isDueForReview }
            let poolToUse = weakWords.isEmpty ? words : weakWords
            guard !poolToUse.isEmpty else { return }

            let shuffled = poolToUse.shuffled()
            let calendar = Calendar.current
            let now = Date()

            for hourOffset in 1...24 {
                guard let targetDate = calendar.date(byAdding: .hour, value: hourOffset, to: now) else { continue }

                var dateComponents = calendar.dateComponents([.year, .month, .day, .hour], from: targetDate)
                dateComponents.minute = 0
                dateComponents.second = 0

                let word = shuffled[(hourOffset - 1) % shuffled.count]

                let content = UNMutableNotificationContent()
                content.title = "\(word.english) → \(word.formattedTurkishMeanings)"
                content.body = "Quick vocabulary reminder — open Today to reinforce your weak words."
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
                let identifier = "\(self.hourlyPrefix)\(hourOffset)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                UNUserNotificationCenter.current().add(request) { error in
                    if let error {
                        print("Failed to schedule hourly notification \(hourOffset): \(error)")
                    }
                }
            }
        }
    }

    func cancelHourlyNotifications(completion: (() -> Void)? = nil) {
        let identifiers = (1...24).map { "\(hourlyPrefix)\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            completion?()
        }
    }

    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}
