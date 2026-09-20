//
//  SourcesCellView.swift
//  CSign
//
//  Created by samara on 1.05.2025.
//

import SwiftUI
import NimbleViews
import NukeUI

// MARK: - View
struct SourcesCellView: View {
	@Environment(\.horizontalSizeClass) private var horizontalSizeClass
	
	var source: AltSource
	
	// MARK: Body
	var body: some View {
		let isRegular = horizontalSizeClass != .compact
		
		VStack(alignment: .leading, spacing: 0) {
			// Banner image if available
			if let bannerURL = source.bannerURL {
				LazyImage(url: bannerURL) { state in
					if let image = state.image {
						image
							.resizable()
							.aspectRatio(contentMode: .fill)
							.frame(maxWidth: .infinity)
							.frame(height: 120)
							.clipped()
							.cornerRadius(isRegular ? 14 : 10, corners: [.topLeft, .topRight])
					} else if state.isLoading {
						Rectangle()
							.fill(Color(.systemFill))
							.frame(maxWidth: .infinity)
							.frame(height: 120)
							.cornerRadius(isRegular ? 14 : 10, corners: [.topLeft, .topRight])
							.overlay(ProgressView())
					} else {
						// Failed or nil: show placeholder
						Rectangle()
							.fill(Color(.systemFill))
							.frame(maxWidth: .infinity)
							.frame(height: 80)
							.cornerRadius(isRegular ? 14 : 10, corners: [.topLeft, .topRight])
					}
				}
				.transition(.opacity)
			}
			
			FRIconCellView(
				title: source.name ?? .localized("Unknown"),
				subtitle: source.sourceURL?.absoluteString ?? .localized("Unknown"),
				iconUrl: source.iconURL
			)
			.padding(isRegular ? 12 : 8)
		}
		.background(
			isRegular
				? RoundedRectangle(cornerRadius: 18, style: .continuous)
				.fill(Color(.quaternarySystemFill))
				: nil
		)
		.clipShape(RoundedRectangle(cornerRadius: isRegular ? 18 : 10, style: .continuous))
		.swipeActions {
			_actions(for: source)
			_contextActions(for: source)
		}
		.contextMenu {
			_contextActions(for: source)
			Divider()
			_actions(for: source)
		}
	}
}

// MARK: - Extension: View
extension SourcesCellView {
	@ViewBuilder
	private func _actions(for source: AltSource) -> some View {
		Button(.localized("Delete"), systemImage: "trash", role: .destructive) {
			Storage.shared.deleteSource(for: source)
		}
	}
	
	@ViewBuilder
	private func _contextActions(for source: AltSource) -> some View {
		Button(.localized("Edit Banner"), systemImage: "photo") {
			// Banner editing is handled via SourcesEditBannerView
			NotificationCenter.default.post(
				name: Notification.Name("CSign.editSourceBanner"),
				object: source
			)
		}
	}
}

// MARK: - RoundedCorner helper
extension View {
	func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
		clipShape(RoundedCornerShape(radius: radius, corners: corners))
	}
}

struct RoundedCornerShape: Shape {
	var radius: CGFloat = .infinity
	var corners: UIRectCorner = .allCorners
	
	func path(in rect: CGRect) -> Path {
		let path = UIBezierPath(
			roundedRect: rect,
			byRoundingCorners: corners,
			cornerRadii: CGSize(width: radius, height: radius)
		)
		return Path(path.cgPath)
	}
}
