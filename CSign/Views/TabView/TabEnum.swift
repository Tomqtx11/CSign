//
//  TabEnum.swift
//  csign
//
//  Created by samara on 22.03.2025.
//

import SwiftUI
import NimbleViews
import Combine

enum TabEnum: String, CaseIterable, Hashable {
	case sources
	case library
	case history
	case settings
	case certificates
	case guide
	
	var title: String {
		switch self {
		case .sources:     	return "IPA Mod"
		case .library: 		return .localized("Library")
		case .history:      return .localized("Lịch sử")
		case .settings: 	return .localized("Settings")
		case .certificates:	return .localized("Certificates")
		case .guide:		return "Hướng Dẫn"
		}
	}
	
	var icon: String {
		switch self {
		case .sources: 		return "globe.desk"
		case .library: 		return "square.grid.2x2"
		case .history:      return "clock.arrow.circlepath"
		case .settings: 	return "gearshape.2"
		case .certificates: return "person.text.rectangle"
		case .guide:		return "book.closed"
		}
	}
	
	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
		case .sources: SourcesView()
		case .library: LibraryView()
		case .history: HistoryView()
		case .settings: SettingsView()
		case .certificates: NBNavigationView(.localized("Certificates")) { CertificatesView() }
		case .guide: GuideView()
		}
	}
	
	static var defaultTabs: [TabEnum] {
		return [
			.library,
			.sources,
			.history,
			.guide,
			.settings
		]
	}
	
	static var customizableTabs: [TabEnum] {
		return [
			.certificates
		]
	}
}

// MARK: - History Feature

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

struct HistoryView: View {
    @StateObject private var historyManager = HistoryManager.shared
    @State private var showingApplyAlert = false
    
    var body: some View {
        NBNavigationView(.localized("Lịch sử Ký")) {
            if historyManager.history.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    Text(.localized("Chưa có lịch sử ký nào."))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(historyManager.history) { item in
                        Button {
                            OptionsManager.shared.options = item.options
                            OptionsManager.shared.saveOptions()
                            showingApplyAlert = true
                            
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.appName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(item.appIdentifier)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(item.dateSigned.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: historyManager.removeHistory)
                }
            }
        }
        .alert(.localized("Đã áp dụng cấu hình"), isPresented: $showingApplyAlert) {
            Button(.localized("OK"), role: .cancel) { }
        } message: {
            Text(.localized("Cấu hình ký của ứng dụng này đã được khôi phục. Bạn có thể chọn một file IPA mới để tiếp tục với các tuỳ chỉnh này."))
        }
    }
}
