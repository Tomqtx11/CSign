import SwiftUI
import NimbleViews
import IDeviceSwift

struct InstallPreviewView: View {
	@Environment(\.dismiss) private var dismiss
	@AppStorage("CSign.useShareSheetForArchiving") private var useShareSheet = false
	@State private var isWebviewPresenting = false
	@State private var workTask: Task<Void, Never>?
	@State private var progressTask: Task<Void, Never>?
	@State private var promptTask: Task<Void, Never>?
	@State private var fallbackInstaller: ServerInstaller?
	@State private var isPreparingFallback = false
	@State private var archiveHandler: ArchiveHandler?
	@State private var didStart = false
	@State private var sentCompletionNotice = false
	@State private var isVisible = false

	let app: AppSnapshot
	let isSharing: Bool
	private let installationMethod: Int
	@StateObject private var viewModel: InstallerStatusViewModel
	@StateObject private var installer: ServerInstaller

	init(app: AppInfoPresentable, isSharing: Bool = false) {
		let snapshot = AppSnapshot(app)
		self.app = snapshot
		self.isSharing = isSharing
		installationMethod = UserDefaults.standard.integer(forKey: "CSign.installationMethod")
		let model = InstallerStatusViewModel(isIdevice: installationMethod == 1)
		_viewModel = StateObject(wrappedValue: model)
		_installer = StateObject(wrappedValue: ServerInstaller(app: snapshot, viewModel: model))
	}

	var body: some View {
		VStack(spacing: 18) {
			HStack(spacing: 14) {
				FRAppIconView(app: app, size: 56)
				VStack(alignment: .leading, spacing: 4) {
					Text(app.name ?? "Ứng dụng").font(.headline).lineLimit(2)
					Text(isSharing ? "Xuất IPA" : "Cài đặt ứng dụng").font(.caption).foregroundStyle(.secondary)
				}
				Spacer(minLength: 0)
				CSignMascotView(isWorking: isBusy)
			}
			ProgressView(value: viewModel.overallProgress).tint(CSignTheme.cyan)
			Label(viewModel.statusLabel, systemImage: viewModel.statusImage).font(.subheadline)
			if case .none = viewModel.status {
				Text("Đóng gói: \(Int(viewModel.packageProgress * 100))%")
					.font(.caption).foregroundStyle(.secondary)
			}
			if case .broken(let error) = viewModel.status {
				Text(error.localizedDescription).font(.caption).foregroundStyle(.red)
			}
			if case .awaitingConfirmation = viewModel.status {
				Text("iOS chưa cung cấp kết quả cuối. Kiểm tra biểu tượng ứng dụng và thông báo trên màn hình chính.")
					.font(.caption).foregroundStyle(.secondary)
			}
			if case .ready = viewModel.status, activeInstaller.getServerMethod() == 1 {
				Text("Trong Safari, bấm Cài đặt để hiện thông báo xác nhận của iPhone.")
					.font(.caption).foregroundStyle(.secondary)
			}
			HStack {
				if viewModel.isCompleted || needsConfirmation {
					Button("Mở ứng dụng") { UIApplication.openApp(with: app.identifier ?? "") }
						.buttonStyle(.borderedProminent)
				}
				if canOpenInstaller {
					Button(isPreparingFallback ? "Đang mở…" : "Mở cài đặt", action: openInstaller)
						.buttonStyle(.borderedProminent).disabled(isPreparingFallback)
					if activeInstaller.getServerMethod() == 0 {
						Button("Qua Safari", action: useSafariFallback)
							.buttonStyle(.bordered).disabled(isPreparingFallback)
					}
				}
				Button("Đóng") { dismiss() }.buttonStyle(.bordered)
			}
		}
		.padding(24)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(CSignTheme.gradient.opacity(0.05))
		.sheet(isPresented: $isWebviewPresenting) {
			SafariRepresentableView(url: activeInstaller.pageEndpoint).ignoresSafeArea()
		}
		.onReceive(viewModel.$status, perform: handleStatus)
		.onAppear {
			isVisible = true
			guard !didStart else { return }
			didStart = true
			#if !targetEnvironment(macCatalyst)
			BackgroundAudioManager.shared.start()
			#endif
			startWork()
		}
		.onDisappear {
			// Presenting Safari can cover this sheet; iOS still needs its IPA server.
			guard !isWebviewPresenting else { return }
			isVisible = false
			workTask?.cancel()
			progressTask?.cancel()
			promptTask?.cancel()
			progressTask = nil
			let server = activeInstaller
			let handler = archiveHandler
			DispatchQueue.global(qos: .utility).async {
				server.shutdown()
				handler?.clean()
			}
			stopBackgroundAudio()
		}
	}

	private var activeInstaller: ServerInstaller { fallbackInstaller ?? installer }

	private var canOpenInstaller: Bool {
		guard !isSharing, installationMethod == 0 else { return false }
		switch viewModel.status {
		case .ready, .sendingManifest: return true
		default: return false
		}
	}

	private var needsConfirmation: Bool {
		if case .awaitingConfirmation = viewModel.status { return true }
		return false
	}

	private var isBusy: Bool {
		switch viewModel.status {
		case .none, .ready, .sendingManifest, .sendingPayload, .installing: return true
		default: return false
		}
	}

	private func openInstaller() {
		guard isVisible, !isPreparingFallback else { return }
		if activeInstaller.getServerMethod() == 1 {
			isWebviewPresenting = true
		} else {
			do {
				let url = try activeInstaller.installationURL
				UIApplication.shared.open(url, options: [:]) { opened in
					Task { @MainActor in
						guard isVisible, case .ready = viewModel.status else { return }
						if !opened { useSafariFallback() }
					}
				}
				promptTask?.cancel()
				promptTask = Task {
					do { try await Task.sleep(nanoseconds: 8_000_000_000) }
					catch { return }
					// open() returning true does not mean iOS fetched the manifest.
					guard isVisible, case .ready = viewModel.status else { return }
					useSafariFallback()
				}
			} catch { viewModel.status = .broken(error) }
		}
	}

	private func useSafariFallback() {
		guard isVisible, !isPreparingFallback, activeInstaller.getServerMethod() == 0,
			let package = activeInstaller.packageUrl else { return }
		promptTask?.cancel()
		isPreparingFallback = true
		let original = activeInstaller
		let replacement = ServerInstaller(app: app, viewModel: viewModel, serverMethod: 1)
		fallbackInstaller = replacement
		workTask = Task.detached(priority: .userInitiated) {
			original.shutdown()
			do {
				try Task.checkCancellation()
				replacement.packageUrl = package
				try replacement.start()
				try Task.checkCancellation()
				try await MainActor.run {
					guard isVisible else { throw CancellationError() }
					isPreparingFallback = false
					viewModel.status = .ready
				}
			} catch {
				replacement.shutdown()
				if !Task.isCancelled {
					await MainActor.run {
						isPreparingFallback = false
						viewModel.status = .broken(error)
					}
				}
			}
		}
	}

	private func handleStatus(_ status: InstallerStatusViewModel.InstallerStatus) {
		guard isVisible else { return }
		switch status {
		case .ready:
			if !isSharing && installationMethod == 0 { openInstaller() }
		case .sendingPayload:
			promptTask?.cancel()
			isWebviewPresenting = false
		case .sendingManifest:
			promptTask?.cancel()
		case .installing:
			if installationMethod == 0, progressTask == nil, let identifier = app.identifier {
				AppNotifications.post(title: "Đã gửi gói cài đặt", body: "iOS đang xử lý \(app.name ?? identifier).")
				progressTask = pollInstallation(identifier)
			}
		case .completed(let result):
			promptTask?.cancel()
			progressTask?.cancel()
			progressTask = nil
			stopBackgroundAudio()
			if !sentCompletionNotice {
				sentCompletionNotice = true
				switch result {
				case .success:
					viewModel.installProgress = 1
					AppNotifications.post(title: "Cài đặt hoàn tất", body: "\(app.name ?? "Ứng dụng") đã được cài đặt.")
				case .failure(let error): viewModel.status = .broken(error)
				}
			}
		case .broken(let error):
			promptTask?.cancel()
			progressTask?.cancel()
			progressTask = nil
			stopBackgroundAudio()
			if !sentCompletionNotice {
				sentCompletionNotice = true
				AppNotifications.post(title: isSharing ? "Không thể xuất IPA" : "Không thể cài đặt", body: error.localizedDescription)
			}
		case .awaitingConfirmation:
			stopBackgroundAudio()
		default: break
		}
	}

	private func startWork() {
		guard isSharing || app.identifier != Bundle.main.bundleIdentifier || installationMethod == 1 else {
			viewModel.status = .broken(InstallationError.couldNotOpenInstaller)
			return
		}
		let app = self.app
		let method = installationMethod
		let server = installer
		let model = viewModel
		let sharing = isSharing
		let shareSheet = useShareSheet
		workTask = Task.detached(priority: .userInitiated) {
			let handler = await ArchiveHandler(app: app, viewModel: model)
			do {
				try Task.checkCancellation()
				try await handler.prepare()
				try Task.checkCancellation()
				// Installing needs a fast container, not a second compression pass.
				let package = try await handler.archive(forceNoCompression: !sharing)
				try Task.checkCancellation()
				if sharing {
					let share = shareSheet
					let exported = try await handler.moveToArchive(package, shouldOpen: !share)
					handler.clean()
					await MainActor.run {
						dismiss()
						if share, let exported { UIActivityViewController.show(activityItems: [exported]) }
					}
				} else if method == 0 {
					server.packageUrl = package
					var startedServer = server
					do { try server.start() }
					catch {
						guard server.getServerMethod() == 0 else { throw error }
						server.shutdown()
						// Expired/missing local TLS must not strand a signed package.
						startedServer = await MainActor.run {
							ServerInstaller(app: app, viewModel: model, serverMethod: 1)
						}
						startedServer.packageUrl = package
						try startedServer.start()
					}
					try Task.checkCancellation()
					let preparedServer = startedServer
					try await MainActor.run {
						try Task.checkCancellation()
						guard isVisible else { throw CancellationError() }
						archiveHandler = handler
						if preparedServer !== server { fallbackInstaller = preparedServer }
						viewModel.status = .ready
					}
				} else if method == 1 {
					let proxy = InstallationProxy(viewModel: model)
					try await proxy.install(at: package, suspend: app.identifier == Bundle.main.bundleIdentifier)
					handler.clean()
				} else { throw InstallationError.invalidServerMethod }
			} catch {
				server.shutdown()
				handler.clean()
				if !Task.isCancelled {
					await MainActor.run { viewModel.status = .broken(error) }
				}
			}
		}
	}

	private func pollInstallation(_ identifier: String) -> Task<Void, Never> {
		Task {
			var tracker = InstallProgressTracker()
			while !Task.isCancelled {
				let update = tracker.update(UIApplication.installProgress(for: identifier, makeSynchronous: false))
				switch update {
				case .waiting: break
				case .progress(let value): viewModel.installProgress = value
				case .completed:
					viewModel.status = .completed(.success(()))
					return
				case .needsConfirmation:
					viewModel.status = .awaitingConfirmation
					return
				}
				do { try await Task.sleep(nanoseconds: 500_000_000) }
				catch { return }
			}
		}
	}

	private func stopBackgroundAudio() {
		#if !targetEnvironment(macCatalyst)
		BackgroundAudioManager.shared.stop()
		#endif
	}
}
