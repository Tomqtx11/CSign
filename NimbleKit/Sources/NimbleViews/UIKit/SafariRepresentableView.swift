//
//  SafariWebView.swift
//  NimbleKit
//
//  Created by samara on 30.04.2025.
//

import SwiftUI
import SafariServices

public struct SafariRepresentableView: UIViewControllerRepresentable {
	public let url: URL
	private let onDismiss: (() -> Void)?
	
	public init(url: URL, onDismiss: (() -> Void)? = nil) {
		self.url = url
		self.onDismiss = onDismiss
	}
	
	public func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }
	public func makeUIViewController(context: Context) -> SFSafariViewController {
		let controller = SFSafariViewController(url: url)
		controller.delegate = context.coordinator
		return controller
	}
	public func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}

	public final class Coordinator: NSObject, SFSafariViewControllerDelegate {
		private let onDismiss: (() -> Void)?
		init(onDismiss: (() -> Void)?) { self.onDismiss = onDismiss }
		public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
			onDismiss?()
		}
	}
}
