//
//  LibraryAppIconView.swift
//  CSign
//
//  Created by samara on 11.04.2025.
//

import SwiftUI
import NimbleExtensions
import NimbleViews

// MARK: - View
struct LibraryCellView: View {
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	@Environment(\.editMode) private var editMode
	@ObservedObject private var updateManager = UpdateManager.shared
	@State private var _signedUpdateConfirmation: AppUpdate?
	@State private var _isSignedUpdateConfirmationPresented = false

	var app: AppInfoPresentable
	@Binding var selectedInfoAppPresenting: AnyApp?
	@Binding var selectedSigningAppPresenting: AnyApp?
	@Binding var selectedInstallAppPresenting: AnyApp?
	var isSelected: Bool
	var toggleSelection: () -> Void
	
	// MARK: Body
	var body: some View {
		let isRegular = horizontalSizeClass != .compact
		let isEditing = editMode?.wrappedValue == .active
		
		HStack(spacing: 18) {
			if isEditing {
				Button {
					toggleSelection()
				} label: {
					Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
						.foregroundColor(isSelected ? .accentColor : .secondary)
						.font(.title3)
				}
				.buttonStyle(.borderless)
			}
			
			_appIcon(for: app)
			
			NBTitleWithSubtitleView(
				title: app.name ?? .localized("Unknown"),
				subtitle: _desc,
				linelimit: 0
			)
			
			if !isEditing {
				_buttonActions(for: app)
			}
		}
		.padding(.horizontal, isRegular ? 12 : 10)
		.padding(.vertical, isRegular ? 8 : 6)
		.background(
			RoundedRectangle(cornerRadius: 18, style: .continuous)
				.fill(isSelected && isEditing ? Color.accentColor.opacity(0.1) : CSignTheme.cyan.opacity(0.035))
		)
		.overlay {
			RoundedRectangle(cornerRadius: 18, style: .continuous)
				.strokeBorder(CSignTheme.gradient, lineWidth: isSelected && isEditing ? 1.5 : 1)
				.opacity(isSelected && isEditing ? 0.8 : 0.35)
				.allowsHitTesting(false)
		}
		.listRowSeparator(.hidden)
		.listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
		.contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
		.onTapGesture {
			if isEditing {
				toggleSelection()
			} else if app.isSigned {
                var loadedOptions: Options? = nil
				if let uuid = app.uuid,
				   let data = UserDefaults.standard.data(forKey: "csign_options_\(uuid)"),
				   let savedOptions = try? JSONDecoder().decode(Options.self, from: data) {
					loadedOptions = savedOptions
				}
				selectedSigningAppPresenting = AnyApp(base: app, restoredOptions: loadedOptions)
			}
		}
		.contextMenu {
			if !isEditing {
				_contextActions(for: app)
				Divider()
				_contextActionsExtra(for: app)
				Divider()
				_actions(for: app)
			}
		}
		.swipeActions(edge: .trailing, allowsFullSwipe: true) {
			if !isEditing {
				Button(role: .destructive) {
					Storage.shared.deleteApp(for: app)
				} label: {
					Label(.localized("Delete"), systemImage: "trash")
				}
			}
		}
		.confirmationDialog(
			.localized("Update Available"),
			isPresented: $_isSignedUpdateConfirmationPresented,
			titleVisibility: .visible
		) {
			Button(.localized("Install Current Version"), systemImage: "square.and.arrow.down") {
				selectedInstallAppPresenting = AnyApp(base: app)
			}
			if let update = _signedUpdateConfirmation {
				Button(.localized("Download Update"), systemImage: "arrow.down.circle") {
					_startUpdateDownload(update)
				}
			}
			Button(.localized("Cancel"), role: .cancel) {}
		} message: {
			if let update = _signedUpdateConfirmation {
				Text("\(update.appName) \(update.remoteVersion)")
			}
		}
	}
	
	private var _desc: String {
		if let version = app.version, let id = app.identifier {
			return "\(version) • \(id)"
		} else {
			return .localized("Unknown")
		}
	}
}


// MARK: - Extension: View
extension LibraryCellView {
	private func _appIcon(for app: AppInfoPresentable) -> some View {
		FRAppIconView(app: app, size: 57)
			.overlay(alignment: .topTrailing) {
				if updateManager.update(for: app) != nil {
					Image(systemName: "arrow.down.circle.fill")
						.font(.system(size: 18, weight: .semibold))
						.symbolRenderingMode(.palette)
						.foregroundStyle(.white, Color.accentColor)
						.background(
							Circle()
								.fill(Color(.systemBackground))
								.frame(width: 20, height: 20)
						)
						.offset(x: 5, y: -5)
						.accessibilityLabel(.localized("Update Available"))
				}
			}
	}
	
	@ViewBuilder
	private func _actions(for app: AppInfoPresentable) -> some View {
		Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteApp(for: app)
		}
	}
	
	@ViewBuilder
	private func _contextActions(for app: AppInfoPresentable) -> some View {
		Button(.localized("Get Info"), systemImage: "info.circle") {
			selectedInfoAppPresenting = AnyApp(base: app)
		}
	}
	
	@ViewBuilder
	private func _contextActionsExtra(for app: AppInfoPresentable) -> some View {
		if let update = updateManager.update(for: app) {
			Button(.localized("Update"), systemImage: "arrow.down.circle") {
				if app.isSigned {
					_signedUpdateConfirmation = update
					_isSignedUpdateConfirmationPresented = true
				} else {
					_startUpdateDownload(update)
				}
			}
		}
		
		if app.isSigned {
			if let id = app.identifier {
				Button(.localized("Open"), systemImage: "app.badge.checkmark") {
					UIApplication.openApp(with: id)
				}
			}
			Button(.localized("Install"), systemImage: "square.and.arrow.down") {
				selectedInstallAppPresenting = AnyApp(base: app)
			}
			Button(.localized("Re-sign"), systemImage: "signature") {
                var loadedOptions: Options? = nil
				if let uuid = app.uuid,
				   let data = UserDefaults.standard.data(forKey: "csign_options_\(uuid)"),
				   let savedOptions = try? JSONDecoder().decode(Options.self, from: data) {
					loadedOptions = savedOptions
				}
				selectedSigningAppPresenting = AnyApp(base: app, restoredOptions: loadedOptions)
			}
			Button(.localized("Export"), systemImage: "square.and.arrow.up") {
				selectedInstallAppPresenting = AnyApp(base: app, archive: true)
			}
		} else {
			Button(.localized("Install"), systemImage: "square.and.arrow.down") {
				selectedInstallAppPresenting = AnyApp(base: app)
			}
			Button(.localized("Sign"), systemImage: "signature") {
				selectedSigningAppPresenting = AnyApp(base: app)
			}
		}
	}
	
	@ViewBuilder
	private func _buttonActions(for app: AppInfoPresentable) -> some View {
		Group {
			if app.isSigned {
				Button {
					selectedInstallAppPresenting = AnyApp(base: app)
				} label: {
					FRExpirationPillView(
						title: .localized("Install"),
						revoked: false,
						expiration: nil
					)
				}
			} else if let update = updateManager.update(for: app) {
				Button {
					_startUpdateDownload(update)
				} label: {
					FRExpirationPillView(
						title: .localized("Update"),
						revoked: false,
						expiration: nil
					)
				}
			} else {
				Button {
					selectedSigningAppPresenting = AnyApp(base: app)
				} label: {
					FRExpirationPillView(
						title: .localized("Sign"),
						revoked: false,
						expiration: nil
					)
				}
			}
		}
		.buttonStyle(.borderless)
	}
	
	private func _startUpdateDownload(_ update: AppUpdate) {
		_ = DownloadManager.shared.startDownload(
			from: update.downloadURL,
			id: "CSignManualDownload_Update_\(update.localUUID)",
			sourceProvenance: update.sourceProvenance
		)
	}
}
