//
//  SettingsView.swift
//  VocabularyPool
//
//  Created by Assistant on 08.01.2026.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomNotification.createdAt, order: .reverse) private var customNotifications: [CustomNotification]
    
    @ObservedObject private var notificationManager = NotificationManager.shared
    @State private var showingAddNotification = false
    @State private var notificationPermissionStatus: String = "Kontrol ediliyor..."
    // @AppStorage ile otomatik UserDefaults senkronizasyonu
    @AppStorage("isPracticeSoundEnabled") private var isPracticeSoundEnabled: Bool = true
    
    var body: some View {
        NavigationStack {
            List {
                // Sound Settings Section
                Section {
                    Toggle(isOn: $isPracticeSoundEnabled) {
                        HStack {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundStyle(.purple)
                            Text("Pratik Sesi")
                        }
                    }
                    // @AppStorage otomatik olarak UserDefaults'a kaydeder, onChange'e gerek yok
                } header: {
                    Text("Ses Ayarları")
                } footer: {
                    Text("Kapalı olduğunda English→Turkish ve Turkish→English pratiklerinde kelimeler sesli söylenmez. Listening Challenge alıştırmasında ses her zaman açıktır. Dinlediğiniz medyanın kesilmesini önler.")
                }
                
                // Permission Status Section
                Section {
                    HStack {
                        Image(systemName: "bell.badge")
                            .foregroundStyle(.blue)
                        Text("Bildirim İzni")
                        Spacer()
                        Text(notificationPermissionStatus)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button("İzin İste") {
                        requestPermission()
                    }
                } header: {
                    Text("Bildirim Durumu")
                }
                
                // Daily Reminder Section
                Section {
                    Toggle(isOn: $notificationManager.isDailyReminderEnabled) {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.orange)
                            Text("Günlük Hatırlatıcı")
                        }
                    }
                    
                    if notificationManager.isDailyReminderEnabled {
                        DatePicker(
                            "Hatırlatma Saati",
                            selection: $notificationManager.dailyReminderTime,
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Text("Günlük Hatırlatıcı")
                } footer: {
                    Text("Her gün belirlediğiniz saatte hatırlatma bildirimi alırsınız.")
                }
                
                // Custom Notifications Section
                Section {
                    ForEach(customNotifications) { notification in
                        CustomNotificationRow(notification: notification)
                    }
                    .onDelete(perform: deleteNotifications)
                    
                    Button {
                        showingAddNotification = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.green)
                            Text("Yeni Bildirim Ekle")
                        }
                    }
                } header: {
                    Text("Özel Bildirimler")
                } footer: {
                    if customNotifications.isEmpty {
                        Text("Kendi belirlediğiniz saatlerde bildirim almak için yeni bildirim ekleyin.")
                    }
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddNotification) {
                AddNotificationView()
            }
            .onAppear {
                checkPermissionStatus()
            }
        }
    }
    
    private func checkPermissionStatus() {
        notificationManager.checkPermissionStatus { status in
            switch status {
            case .authorized:
                notificationPermissionStatus = "İzin Verildi ✓"
            case .denied:
                notificationPermissionStatus = "Reddedildi ✗"
            case .notDetermined:
                notificationPermissionStatus = "Belirlenmedi"
            case .provisional:
                notificationPermissionStatus = "Geçici"
            case .ephemeral:
                notificationPermissionStatus = "Geçici"
            @unknown default:
                notificationPermissionStatus = "Bilinmiyor"
            }
        }
    }
    
    private func requestPermission() {
        notificationManager.requestPermission { granted in
            checkPermissionStatus()
        }
    }
    
    private func deleteNotifications(offsets: IndexSet) {
        for index in offsets {
            let notification = customNotifications[index]
            NotificationManager.shared.cancelCustomNotification(id: notification.id)
            modelContext.delete(notification)
        }
    }
}

struct CustomNotificationRow: View {
    @Bindable var notification: CustomNotification
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.title)
                    .font(.headline)
                Text(notification.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack {
                    Text(notification.formattedTime)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    Text(notification.weekdayNames)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $notification.isEnabled)
                .labelsHidden()
                .onChange(of: notification.isEnabled) { oldValue, newValue in
                    if newValue {
                        NotificationManager.shared.scheduleCustomNotification(
                            id: notification.id,
                            title: notification.title,
                            body: notification.body,
                            hour: notification.hour,
                            minute: notification.minute,
                            weekdays: notification.weekdays
                        )
                    } else {
                        NotificationManager.shared.cancelCustomNotification(id: notification.id)
                    }
                }
        }
        .padding(.vertical, 4)
    }
}

struct AddNotificationView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var title = ""
    @State private var messageBody = ""
    @State private var selectedTime = Date()
    @State private var selectedWeekdays: Set<Int> = []
    
    private let weekdays = [
        (1, "Paz"),
        (2, "Pzt"),
        (3, "Sal"),
        (4, "Çar"),
        (5, "Per"),
        (6, "Cum"),
        (7, "Cmt")
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Bildirim İçeriği") {
                    TextField("Başlık", text: $title)
                    TextField("Mesaj", text: $messageBody)
                }
                
                Section("Zaman") {
                    DatePicker(
                        "Bildirim Saati",
                        selection: $selectedTime,
                        displayedComponents: .hourAndMinute
                    )
                }
                
                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(weekdays, id: \.0) { day in
                            Button {
                                if selectedWeekdays.contains(day.0) {
                                    selectedWeekdays.remove(day.0)
                                } else {
                                    selectedWeekdays.insert(day.0)
                                }
                            } label: {
                                Text(day.1)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(selectedWeekdays.contains(day.0) ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundStyle(selectedWeekdays.contains(day.0) ? .white : .primary)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Tekrar Günleri")
                } footer: {
                    Text("Hiç gün seçmezseniz bildirim her gün tekrar eder.")
                }
            }
            .navigationTitle("Yeni Bildirim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        saveNotification()
                    }
                    .disabled(title.isEmpty || messageBody.isEmpty)
                }
            }
        }
    }
    
    private func saveNotification() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        let hour = components.hour ?? 9
        let minute = components.minute ?? 0
        
        let notification = CustomNotification(
            title: title,
            body: messageBody,
            hour: hour,
            minute: minute,
            weekdays: Array(selectedWeekdays).sorted()
        )
        
        modelContext.insert(notification)
        
        // Schedule the notification
        NotificationManager.shared.scheduleCustomNotification(
            id: notification.id,
            title: notification.title,
            body: notification.body,
            hour: notification.hour,
            minute: notification.minute,
            weekdays: notification.weekdays
        )
        
        dismiss()
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: CustomNotification.self, inMemory: true)
}
