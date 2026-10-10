import Foundation
import Vapor
import NIOCore
import NIOPosix
import NIOConcurrencyHelpers

/// A bounded-memory IPA endpoint with explicit HEAD and resumable byte-range support.
enum InstallationPayload {
	static func response(
		to request: Request, file: URL, tracker: PayloadTransferTracker,
		onStarted: @Sendable @escaping () -> Void,
		onProgress: @Sendable @escaping (PayloadTransferTracker.Progress) -> Void,
		onCompleted: @Sendable @escaping (PayloadTransferTracker.Progress) -> Void
	) -> Response {
		guard FileManager.default.fileExists(atPath: file.path), tracker.size > 0 else {
			return Response(status: .notFound)
		}
		var headers: HTTPHeaders = [
			"Content-Type": "application/octet-stream",
			"Accept-Ranges": "bytes",
			"Cache-Control": "no-store"
		]
		if request.method == .HEAD {
			headers.replaceOrAdd(name: .contentLength, value: String(tracker.size))
			return Response(status: .ok, version: request.version, headersNoUpdate: headers, body: .empty)
		}
		guard let range = PayloadTransferTracker.requestedRange(request.headers.first(name: .range), size: tracker.size) else {
			headers.replaceOrAdd(name: .contentRange, value: "bytes */\(tracker.size)")
			return Response(status: .requestedRangeNotSatisfiable, headers: headers)
		}
		let partial = request.headers.contains(name: .range)
		if partial {
			headers.replaceOrAdd(name: .contentRange, value: "bytes \(range.lowerBound)-\(range.upperBound - 1)/\(tracker.size)")
		}
		let response = Response(status: partial ? .partialContent : .ok, headers: headers)
		response.body = .init(stream: { stream in
			onStarted()
			let cursor = NIOLockedValueBox<Int64>(range.lowerBound)
			let lastNotice = NIOLockedValueBox<TimeInterval>(0)
			request.eventLoop.flatSubmit {
				do {
					let handle = try NIOFileHandle(path: file.path)
					let io = request.application.fileio
					let reading = io.readChunked(
						fileHandle: handle, fromOffset: range.lowerBound,
						byteCount: Int(range.upperBound - range.lowerBound), chunkSize: 256 * 1024,
						allocator: request.byteBufferAllocator, eventLoop: request.eventLoop
					) { chunk in
						let count = Int64(chunk.readableBytes)
						return stream.write(.buffer(chunk)).map {
							let sent = cursor.withLockedValue { offset -> Range<Int64> in
								let sent = offset..<(offset + count)
								offset += count
								return sent
							}
							let progress = tracker.record(sent)
							let now = Date.timeIntervalSinceReferenceDate
							let notify = lastNotice.withLockedValue { last -> Bool in
								guard progress.isComplete || now - last >= 0.2 else { return false }
								last = now
								return true
							}
							if notify { onProgress(progress) }
						}
						}
					return reading.flatMap { stream.write(.end) }.always { _ in try? handle.close() }
				} catch { return request.eventLoop.makeFailedFuture(error) }
			}.whenComplete { result in
				switch result {
				case .success: onCompleted(tracker.snapshot)
				case .failure(let error):
					// iOS may abort a probe and resume it; keep the endpoint available.
					request.logger.debug("IPA transfer interrupted: \(error)")
					stream.write(.error(error), promise: nil)
				}
			}
		}, count: Int(range.upperBound - range.lowerBound), byteBufferAllocator: request.byteBufferAllocator)
		return response
	}
}
