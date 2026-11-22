//
//  SettingsView.swift
//  VocabularyPool
//
//  Created by Assistant on 08.01.2026.
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject private var notificationManager = NotificationManager.shared
    @State private var notificationPermissionStatus: String = "Kontrol ediliyor..."
    @AppStorage("isPracticeSoundEnabled") private var isPracticeSoundEnabled: Bool = true
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Ses Ayarları
                Section("Ses Ayarları") {
                    Toggle(isOn: $isPracticeSoundEnabled) {
                        HStack(spacing: DS.Spacing.sm) {
                            DSIconBadge(systemImage: "speaker.wave.2.fill", color: .purple)
                            Text("Pratik Sesi")
                                .font(.dsHeadline)
                        }
                    }
                }

                // MARK: - Bildirim Durumu
                Section("Bildirim Durumu") {
                    HStack(spacing: DS.Spacing.sm) {
                        DSIconBadge(systemImage: "bell.badge.fill", color: DS.Colors.primary)
                        Text("Bildirim İzni")
                            .font(.dsHeadline)
                        Spacer()
                        Text(notificationPermissionStatus)
                            .font(.dsCallout)
                            .foregroundStyle(.secondary)
                    }

                    Button("İzin İste") {
                        requestPermission()
                    }
                    .font(.dsHeadline)
                    .foregroundStyle(DS.Colors.primary)
                }
            }
            .navigationTitle("Ayarlar")
            .navigationBarTitleDisplayMode(.inline)
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
            case .provisional, .ephemeral:
                notificationPermissionStatus = "Geçici"
            @unknown default:
                notificationPermissionStatus = "Bilinmiyor"
            }
        }
    }
    
    private func requestPermission() {
        notificationManager.requestPermission { _ in
            checkPermissionStatus()
        }
    }
}

#Preview {
    SettingsView()
}
