//
//  PracticeSession.swift
//  VocabularyPool
//
//  Created by Assistant on 05.01.2026.
//
import Foundation
import SwiftData

/// PracticeSession, bir gün içindeki çalışma oturumunu temsil eden kalıcı bir modeldir.
///
/// Bu model; sözlük çalışma istatistiklerini (İngilizce->Türkçe, Türkçe->İngilizce, dinleme) ve
/// o güne ait hedeflerin anlık kopyasını (snapshot) saklar. SwiftData ile kalıcı olarak tutulur
/// ve tarih bazlı ilerleme/analiz için kullanılabilir.
///
/// Kullanım Senaryoları:
/// - Günlük çalışma sayacını artırma (ör. bir kelime testini tamamladıkça)
/// - O günün hedeflerini kullanıcı ayarlarından çekip snapshot olarak kaydetme
/// - Geçmiş günlere ait performansı görüntüleme

@Model
final class PracticeSession {
    
    /// Oturum tarihi. Genellikle `Date()` ile oluşturulur ve gün bazında benzersizdir.
    var date: Date
    /// İngilizce'den Türkçe'ye yapılan doğru cevap/alıştırma sayısı.
    ///
    var englishToTurkishCount: Int
    /// Türkçe'den İngilizce'ye yapılan doğru cevap/alıştırma sayısı.
    ///
    var turkishToEnglishCount: Int
    /// Dinleme alıştırması sayısı (ör. sesli örnek dinleme). Varsayılan: 0
    var listeningCount: Int = 0
    
    /// Hedef anlık görüntüsü (snapshot): O gün için geçerli hedef değerleri.
    /// Bu değerler, kullanıcının genel hedeflerinden bağımsız olarak o günün başlangıcında
    /// veya oturum oluşturulurken kaydedilir; böylece geçmiş günlerin hedefleri değişmez.
    /// O gün için İngilizce->Türkçe hedef sayısı (snapshot). Varsayılan: 0
    var dailyGoalEngToTr: Int = 0
    /// O gün için Türkçe->İngilizce hedef sayısı (snapshot). Varsayılan: 0
    var dailyGoalTrToEng: Int = 0
    /// O gün için dinleme hedef sayısı (snapshot). Varsayılan: 0
    var dailyGoalListening: Int = 0
    
    /// Yeni bir PracticeSession oluşturur.
    /// - Parameters:
    ///   - date: Oturum tarihi. Varsayılan `Date()`.
    ///   - englishToTurkishCount: Başlangıç İngilizce->Türkçe sayacı. Varsayılan `0`.
    ///   - turkishToEnglishCount: Başlangıç Türkçe->İngilizce sayacı. Varsayılan `0`.
    ///   - listeningCount: Başlangıç dinleme sayacı. Varsayılan `0`.
    ///   - dailyGoalEngToTr: O günün İngilizce->Türkçe hedef snapshot değeri. Varsayılan `0`.
    ///   - dailyGoalTrToEng: O günün Türkçe->İngilizce hedef snapshot değeri. Varsayılan `0`.
    ///   - dailyGoalListening: O günün dinleme hedef snapshot değeri. Varsayılan `0`.
    ///
    /// Not: Hedef snapshot değerleri, kullanıcının global hedefleri sonradan değişse bile
    /// bu oturum için sabit kalır; geçmiş analizlerin tutarlılığını sağlar.
    init(date: Date = Date(), englishToTurkishCount: Int = 0, turkishToEnglishCount: Int = 0, listeningCount: Int = 0, dailyGoalEngToTr: Int = 0, dailyGoalTrToEng: Int = 0, dailyGoalListening: Int = 0) {
        self.date = date
        self.englishToTurkishCount = englishToTurkishCount
        self.turkishToEnglishCount = turkishToEnglishCount
        self.listeningCount = listeningCount
        self.dailyGoalEngToTr = dailyGoalEngToTr
        self.dailyGoalTrToEng = dailyGoalTrToEng
        self.dailyGoalListening = dailyGoalListening
    }
}

