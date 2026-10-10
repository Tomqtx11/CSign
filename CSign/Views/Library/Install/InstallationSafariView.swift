import SwiftUI
import SafariServices

/// Present Safari as its own controller, rather than embedding it in SwiftUI's
/// controller hierarchy. Its first load starts after the presenter is visible.
struct InstallationSafariView: UIViewControllerRepresentable {
	let url: URL
	let onDismiss: () -> Void
	let onInitialLoad: (Bool) -> Void

	func makeUIViewController(context: Context) -> Presenter {
		Presenter(url: url, onDismiss: onDismiss, onInitialLoad: onInitialLoad)
	}

	func updateUIViewController(_ controller: Presenter, context: Context) {}

	final class Presenter: UIViewController, SFSafariViewControllerDelegate {
		private let url: URL
		private let onDismiss: () -> Void
		private let onInitialLoad: (Bool) -> Void
		private var didPresent = false

		init(url: URL, onDismiss: @escaping () -> Void, onInitialLoad: @escaping (Bool) -> Void) {
			self.url = url
			self.onDismiss = onDismiss
			self.onInitialLoad = onInitialLoad
			super.init(nibName: nil, bundle: nil)
		}

		required init?(coder: NSCoder) { return nil }

		override func viewDidLoad() {
			super.viewDidLoad()
			view.backgroundColor = .systemBackground
		}

		override func viewDidAppear(_ animated: Bool) {
			super.viewDidAppear(animated)
			guard !didPresent else { return }
			didPresent = true
			let browser = SFSafariViewController(url: url)
			browser.delegate = self
			browser.modalPresentationStyle = .fullScreen
			present(browser, animated: false)
		}

		func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
			controller.dismiss(animated: false) { self.onDismiss() }
		}

		func safariViewController(_ controller: SFSafariViewController, didCompleteInitialLoad didLoadSuccessfully: Bool) {
			onInitialLoad(didLoadSuccessfully)
		}
	}
}
