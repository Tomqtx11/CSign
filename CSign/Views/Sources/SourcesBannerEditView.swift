//
//  SourcesBannerEditView.swift
//  CSign
//
//  Created for CSign banner feature.
//

import SwiftUI
import NimbleViews
import NukeUI

// MARK: - View
struct SourcesBannerEditView: View {
	@Environment(\.dismiss) var dismiss
	
	var source: AltSource
	
	@State private var _bannerURLString: String = ""
	@State private var _isPreviewLoading = false
	@State private var _previewError = false
	
	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Edit Banner"), displayMode: .inline) {
			Form {
				NBSection(.localized("Banner Image URL")) {
					TextField("https://example.com/banner.jpg", text: $_bannerURLString)
						.keyboardType(.URL)
						.textInputAutocapitalization(.never)
						.autocorrectionDisabled()
				} footer: {
					Text(.localized("Enter a URL for the banner image shown at the top of this repository. Recommended size: 1200×400px."))
				}
				
				if !_bannerURLString.isEmpty, let url = URL(string: _bannerURLString) {
					NBSection(.localized("Preview")) {
						LazyImage(url: url) { state in
							if let image = state.image {
								image
									.resizable()
									.aspectRatio(contentMode: .fill)
									.frame(maxWidth: .infinity)
									.frame(height: 120)
									.clipped()
									.cornerRadius(10)
							} else if state.isLoading {
								RoundedRectangle(cornerRadius: 10)
									.fill(Color(.systemFill))
									.frame(maxWidth: .infinity)
									.frame(height: 120)
									.overlay(ProgressView())
							} else {
								RoundedRectangle(cornerRadius: 10)
									.fill(Color(.systemFill))
									.frame(maxWidth: .infinity)
									.frame(height: 80)
									.overlay {
										Label(.localized("Failed to load image"), systemImage: "exclamationmark.triangle")
											.foregroundColor(.secondary)
											.font(.caption)
									}
							}
						}
						.listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
					}
				}
				
				if source.bannerURL != nil {
					Section {
						Button(.localized("Remove Banner"), role: .destructive) {
							_bannerURLString = ""
							_saveBanner()
						}
					}
				}
			}
			.toolbar {
				NBToolbarButton(role: .cancel)
				NBToolbarButton(
					.localized("Save"),
					style: .text,
					placement: .confirmationAction,
					isDisabled: false
				) {
					_saveBanner()
					dismiss()
				}
			}
			.onAppear {
				_bannerURLString = source.bannerURL?.absoluteString ?? ""
			}
		}
	}
	
	private func _saveBanner() {
		if _bannerURLString.isEmpty {
			source.bannerURL = nil
		} else if let url = URL(string: _bannerURLString) {
			source.bannerURL = url
		}
		Storage.shared.saveContext()
	}
}
