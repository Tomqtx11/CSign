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

struct HistoryView: View {
    @StateObject var downloadManager = DownloadManager.shared
    @StateObject var updateManager = UpdateManager.shared
    
    @State private var _selectedInfoAppPresenting: AnyApp?
    @State private var _selectedSigningAppPresenting: AnyApp?
    @State private var _selectedInstallAppPresenting: AnyApp?
    @State private var _selectedAppUUIDs: Set<String> = []
    @State private var _editMode: EditMode = .inactive
    @State private var _searchText = ""
    @Namespace private var _namespace
    
    @FetchRequest(
        entity: Signed.entity(),
        sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
        animation: .snappy
    ) private var _signedApps: FetchedResults<Signed>
    
    private var _filteredSignedApps: [Signed] {
        _signedApps.filter {
            _searchText.isEmpty ||
                (($0.value(forKey: "name") as? String)?.localizedCaseInsensitiveContains(_searchText) ?? false)
        }
    }
    
    var body: some View {
        NBNavigationView(.localized("Lịch sử Ký")) {
            NBListAdaptable {
                if !_filteredSignedApps.isEmpty {
                    NBSection(
                        .localized("Signed"),
                        secondary: _filteredSignedApps.count.description
                    ) {
                        ForEach(_filteredSignedApps, id: \.uuid) { app in
                            LibraryCellView(
                                app: app,
                                selectedInfoAppPresenting: $_selectedInfoAppPresenting,
                                selectedSigningAppPresenting: $_selectedSigningAppPresenting,
                                selectedInstallAppPresenting: $_selectedInstallAppPresenting,
                                selectedAppUUIDs: $_selectedAppUUIDs
                            )
                            .compatMatchedTransitionSource(id: app.uuid ?? "", ns: _namespace)
                        }
                    }
                }
            }
            .searchable(text: $_searchText, placement: .platform())
            .scrollDismissesKeyboard(.interactively)
            .overlay {
                if _filteredSignedApps.isEmpty {
                    if #available(iOS 17, *) {
                        ContentUnavailableView {
                            Label(.localized("Chưa có lịch sử ký nào."), systemImage: "clock.badge.exclamationmark")
                        } description: {
                            Text(.localized("Khi bạn ký một ứng dụng, nó sẽ xuất hiện ở đây cùng với toàn bộ cấu hình đã chọn."))
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                
                if _editMode.isEditing {
                    NBToolbarButton(
                        .localized("Delete"),
                        systemImage: "trash",
                        isDisabled: _selectedAppUUIDs.isEmpty
                    ) {
                        _bulkDeleteSelectedApps()
                    }
                }
            }
            .environment(\.editMode, $_editMode)
            .sheet(item: $_selectedInfoAppPresenting) { app in
                LibraryInfoView(app: app.base)
            }
            .sheet(item: $_selectedInstallAppPresenting) { app in
                InstallPreviewView(app: app.base, isSharing: app.archive)
                    .presentationDetents([.height(200)])
                    .presentationDragIndicator(.visible)
            }
            .fullScreenCover(item: $_selectedSigningAppPresenting) { app in
                SigningView(app: app.base)
                    .compatNavigationTransition(id: app.base.uuid ?? "", ns: _namespace)
            }
            .onChange(of: _editMode) { mode in
                if mode == .inactive {
                    _selectedAppUUIDs.removeAll()
                }
            }
        }
    }
    
    private func _bulkDeleteSelectedApps() {
        let selectedApps = _filteredSignedApps.filter { app in
            guard let uuid = app.uuid else { return false }
            return _selectedAppUUIDs.contains(uuid)
        }
        for app in selectedApps {
            Storage.shared.deleteApp(for: app)
        }
        _selectedAppUUIDs.removeAll()
    }
}
