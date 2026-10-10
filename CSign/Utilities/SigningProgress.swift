import Foundation
import Combine

private final class SigningCancellation: @unchecked Sendable {
	let lock = NSLock()
	var requested = false
}
private let signingCancellation = SigningCancellation()

@MainActor
final class SigningProgress: ObservableObject {
	static let shared = SigningProgress()
	@Published private(set) var isRunning = false
	@Published private(set) var isCancelled = false
	@Published private(set) var progress = 0.0
	@Published private(set) var currentPhase: Phase = .preparing

	enum Phase: String {
		case preparing = "Chuẩn bị"
		case copying = "Sao chép ứng dụng"
		case modifying = "Áp dụng tuỳ chọn"
		case signing = "Ký ứng dụng"
		case saving = "Lưu vào thư viện"
		case done = "Hoàn tất"

		var range: ClosedRange<Double> {
			switch self {
			case .preparing: return 0...0.02
			case .copying: return 0.02...0.20
			case .modifying: return 0.20...0.35
			case .signing: return 0.35...0.90
			case .saving: return 0.90...1
			case .done: return 1...1
			}
		}
	}

	nonisolated static var cancellationRequested: Bool {
		signingCancellation.lock.lock()
		defer { signingCancellation.lock.unlock() }
		return signingCancellation.requested
	}

	func start() -> Bool {
		guard !isRunning else { return false }
		signingCancellation.lock.lock()
		signingCancellation.requested = false
		signingCancellation.lock.unlock()
		isCancelled = false
		progress = 0
		currentPhase = .preparing
		isRunning = true
		return true
	}

	func cancel() {
		guard isRunning else { return }
		signingCancellation.lock.lock()
		signingCancellation.requested = true
		signingCancellation.lock.unlock()
		isCancelled = true
		// The signer must finish its current native operation before cleanup.
	}

	nonisolated static func update(phase: Phase, subProgress: Double = 0) {
		Task { @MainActor in
			let state = shared
			guard state.isRunning, !state.isCancelled else { return }
			let range = phase.range
			let value = range.lowerBound + (range.upperBound - range.lowerBound) * min(max(subProgress, 0), 1)
			guard value >= state.progress else { return }
			state.currentPhase = phase
			state.progress = value
		}
	}

	func finish(error: Error?) {
		isRunning = false
		if error == nil {
			progress = 1
			currentPhase = .done
		}
	}
}
