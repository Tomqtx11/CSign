import Foundation
import Combine

@MainActor
final class LogCapture: ObservableObject {
	static let shared = LogCapture()
	
	@Published var logs: String = ""
	@Published var isCapturing = false
	
	private var pipe: Pipe?
	private var oldStdout: Int32 = -1
	
	func start() {
		guard !isCapturing else { return }
		isCapturing = true
		logs = ""
		
		pipe = Pipe()
		oldStdout = dup(STDOUT_FILENO)
		dup2(pipe!.fileHandleForWriting.fileDescriptor, STDOUT_FILENO)
		
		pipe!.fileHandleForReading.readabilityHandler = { [weak self] handle in
			let data = handle.availableData
			if !data.isEmpty, let string = String(data: data, encoding: .utf8) {
				Task { @MainActor in
					self?.logs += string
				}
			}
		}
	}
	
	func stop() {
		guard isCapturing else { return }
		isCapturing = false
		
		fflush(stdout)
		if oldStdout != -1 {
			dup2(oldStdout, STDOUT_FILENO)
			close(oldStdout)
			oldStdout = -1
		}
		
		pipe?.fileHandleForReading.readabilityHandler = nil
		pipe = nil
	}
}
