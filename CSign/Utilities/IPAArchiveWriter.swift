import Foundation
@_implementationOnly import Minizip

/// Stream an app directly into Payload/, preserving Unix modes and symbolic links.
/// Uses the minizip code already linked by Zip; no extra runtime dependency.
enum IPAArchiveWriter {
	static func write(app source: URL, to output: URL, compressionLevel: Int32,
					  progress: (Double) -> Void = { _ in }) throws {
		// iOS and macOS may expose /var through /private/var during enumeration.
		// Resolve the bundle root once; do not resolve symbolic links inside it.
		let app = source.resolvingSymlinksInPath().standardizedFileURL
		let manager = FileManager.default
		let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .fileSizeKey]
		var enumerationError: Error?
		guard let enumerator = manager.enumerator(at: app, includingPropertiesForKeys: Array(keys), options: [], errorHandler: { _, error in
			enumerationError = error
			return false
		}) else { throw CocoaError(.fileReadNoSuchFile) }
		let files = [app] + enumerator.allObjects.compactMap { $0 as? URL }
		if let enumerationError { throw enumerationError }
		let rootComponents = app.pathComponents.map { $0.precomposedStringWithCanonicalMapping }
		let root = "Payload/" + app.lastPathComponent.precomposedStringWithCanonicalMapping
		var total: Int64 = 0
		for file in files {
			let values = try file.resourceValues(forKeys: keys)
			if values.isDirectory != true { total += Int64(values.fileSize ?? 0) }
		}
		guard let zip = output.path.withCString({ zipOpen64($0, APPEND_STATUS_CREATE) }) else { throw CocoaError(.fileWriteUnknown) }
		var succeeded = false
		var closed = false
		defer {
			if !closed { zipClose(zip, nil) }
			if !succeeded { try? manager.removeItem(at: output) }
		}
		var written: Int64 = 0
		var lastUpdate = Date.distantPast
		progress(0)
		for file in files {
			try Task.checkCancellation()
			let values = try file.resourceValues(forKeys: keys)
			let symbolicLink = values.isSymbolicLink == true
			let directory = values.isDirectory == true && !symbolicLink
			let attributes = try manager.attributesOfItem(atPath: file.path)
			var entry = root
			if file != app {
				let components = file.standardizedFileURL.pathComponents
				guard components.prefix(rootComponents.count).map({ $0.precomposedStringWithCanonicalMapping }) == rootComponents else {
					throw CocoaError(.fileReadInvalidFileName, userInfo: [NSFilePathErrorKey: file.path, "BundleRoot": app.path])
				}
				entry += "/" + components.dropFirst(rootComponents.count).joined(separator: "/")
			}
			if directory { entry += "/" }
			var info = zip_fileinfo()
			let permission = (attributes[.posixPermissions] as? NSNumber)?.uint32Value ?? (directory ? 0o755 : 0o644)
			let kind: UInt32 = symbolicLink ? 0o120000 : (directory ? 0o040000 : 0o100000)
			info.external_fa = uLong((kind | permission) << 16) | (directory ? 0x10 : 0)
			let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: attributes[.modificationDate] as? Date ?? Date())
			info.tmz_date = tm_zip(tm_sec: UInt32(components.second ?? 0), tm_min: UInt32(components.minute ?? 0),
				tm_hour: UInt32(components.hour ?? 0), tm_mday: UInt32(components.day ?? 1),
				tm_mon: UInt32((components.month ?? 1) - 1), tm_year: UInt32(max(1980, components.year ?? 1980)))
			let method = compressionLevel == 0 || directory || symbolicLink ? 0 : Z_DEFLATED
			let result = zipOpenNewFileInZip4_64(zip, entry, &info, nil, 0, nil, 0, nil,
				method, compressionLevel, 0, -MAX_WBITS, DEF_MEM_LEVEL, Z_DEFAULT_STRATEGY,
				nil, 0, uLong((3 << 8) | 20), uLong(1 << 11), (values.fileSize ?? 0) >= 0xFFFFFFFF ? 1 : 0)
			guard result == ZIP_OK else { throw CocoaError(.fileWriteUnknown) }
			do {
				if symbolicLink {
					let data = Data(try manager.destinationOfSymbolicLink(atPath: file.path).utf8)
					try data.withUnsafeBytes { buffer in
						guard zipWriteInFileInZip(zip, buffer.baseAddress, UInt32(data.count)) == ZIP_OK else { throw CocoaError(.fileWriteUnknown) }
					}
					written += Int64(data.count)
				} else if !directory {
					let input = try FileHandle(forReadingFrom: file)
					defer { try? input.close() }
					while let data = try input.read(upToCount: 256 * 1024), !data.isEmpty {
						try Task.checkCancellation()
						try data.withUnsafeBytes { buffer in
							guard zipWriteInFileInZip(zip, buffer.baseAddress, UInt32(data.count)) == ZIP_OK else { throw CocoaError(.fileWriteUnknown) }
						}
						written += Int64(data.count)
						if Date().timeIntervalSince(lastUpdate) >= 0.1 {
							lastUpdate = Date()
							progress(total > 0 ? min(Double(written) / Double(total), 0.99) : 0)
						}
					}
				}
			} catch {
				zipCloseFileInZip(zip)
				throw error
			}
			guard zipCloseFileInZip(zip) == ZIP_OK else { throw CocoaError(.fileWriteUnknown) }
		}
		let result = zipClose(zip, nil)
		closed = true
		guard result == ZIP_OK else { throw CocoaError(.fileWriteUnknown) }
		succeeded = true
		progress(1)
	}
}
