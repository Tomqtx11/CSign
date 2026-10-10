import Foundation

/// Counts unique byte ranges written to iOS, including resumed/overlapping requests.
final class PayloadTransferTracker: @unchecked Sendable {
	struct Progress: Sendable {
		let bytes: Int64
		let total: Int64
		var fraction: Double { total > 0 ? Double(bytes) / Double(total) : 0 }
		var isComplete: Bool { total > 0 && bytes == total }
	}

	let size: Int64
	private let lock = NSLock()
	private var ranges: [Range<Int64>] = []

	init(size: Int64) { self.size = size }

	static func requestedRange(_ header: String?, size: Int64) -> Range<Int64>? {
		guard size > 0 else { return nil }
		guard let header else { return 0..<size }
		let parts = header.trimmingCharacters(in: .whitespaces).split(separator: "=", maxSplits: 1)
		guard parts.count == 2, parts[0].lowercased() == "bytes", !parts[1].contains(",") else { return nil }
		let bounds = parts[1].split(separator: "-", omittingEmptySubsequences: false)
		guard bounds.count == 2 else { return nil }
		if bounds[0].isEmpty {
			guard let suffix = Int64(bounds[1]), suffix > 0 else { return nil }
			return max(0, size - min(suffix, size))..<size
		}
		guard let start = Int64(bounds[0]), start >= 0, start < size else { return nil }
		if bounds[1].isEmpty { return start..<size }
		guard let end = Int64(bounds[1]), end >= start else { return nil }
		return start..<(min(end, size - 1) + 1)
	}

	@discardableResult
	func record(_ range: Range<Int64>) -> Progress {
		lock.lock()
		defer { lock.unlock() }
		if range.lowerBound >= 0, range.upperBound <= size, !range.isEmpty {
			var merged: [Range<Int64>] = []
			for next in (ranges + [range]).sorted(by: { $0.lowerBound < $1.lowerBound }) {
				if let last = merged.last, next.lowerBound <= last.upperBound {
					merged[merged.count - 1] = last.lowerBound..<max(last.upperBound, next.upperBound)
				} else { merged.append(next) }
			}
			ranges = merged
		}
		return progress()
	}

	var snapshot: Progress {
		lock.lock()
		defer { lock.unlock() }
		return progress()
	}

	private func progress() -> Progress {
		Progress(bytes: ranges.reduce(0) { $0 + ($1.upperBound - $1.lowerBound) }, total: size)
	}
}
