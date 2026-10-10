import Foundation

/// A missing private-API progress object does not prove installation succeeded.
struct InstallProgressTracker {
	enum Update: Equatable {
		case waiting
		case progress(Double)
		case completed
		case needsConfirmation
	}
	private var started = false
	private let deadline: Date

	init(start: Date = Date(), timeout: TimeInterval = 120) {
		deadline = start.addingTimeInterval(timeout)
	}

	mutating func update(_ raw: Double?, now: Date = Date()) -> Update {
		if let raw, raw.isFinite, raw >= 1 { return .completed }
		if now >= deadline { return .needsConfirmation }
		guard let raw, raw.isFinite, raw > 0 else {
			return started ? .needsConfirmation : .waiting
		}
		started = true
		return .progress(min(raw, 1))
	}
}
