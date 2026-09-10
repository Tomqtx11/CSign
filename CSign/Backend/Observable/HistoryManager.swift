//
//  HistoryManager.swift
//  CSign
//
//  Created by AI on 10.09.2026.
//

import Foundation
import UIKit
import Combine

struct SignedHistoryItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var appName: String
    var appIdentifier: String
    var dateSigned: Date
    var options: Options
}

class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var history: [SignedHistoryItem] = []
    private let _key = "csign_signing_history"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: _key),
           let saved = try? JSONDecoder().decode([SignedHistoryItem].self, from: data) {
            self.history = saved
        }
    }
    
    func saveHistory() {
        if let encoded = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(encoded, forKey: _key)
        }
    }
    
    func addHistory(appName: String, appIdentifier: String, options: Options) {
        let item = SignedHistoryItem(appName: appName, appIdentifier: appIdentifier, dateSigned: Date(), options: options)
        DispatchQueue.main.async {
            self.history.insert(item, at: 0)
            self.saveHistory()
        }
    }
    
    func removeHistory(at offsets: IndexSet) {
        DispatchQueue.main.async {
            self.history.remove(atOffsets: offsets)
            self.saveHistory()
        }
    }
    
    func clearHistory() {
        DispatchQueue.main.async {
            self.history.removeAll()
            self.saveHistory()
        }
    }
}
