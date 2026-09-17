import Foundation
import Combine

@MainActor
final class LogCapture: ObservableObject {
	static let shared = LogCapture()
	
	@Published var logs: String = ""
	@Published var isCapturing = false
	
	func start() {
		isCapturing = true
		logs = ""
	}
	
	nonisolated func printLog(_ message: String) {
		Task { @MainActor in
			if !logs.isEmpty {
				logs += "\n"
			}
			logs += "[\(Date().formatted(date: .omitted, time: .standard))] \(message)"
		}
	}
	
	func stop() {
		isCapturing = false
	}
}
