//
//  ArchiveHandler.swift
//  CSign
//
//  Created by samara on 22.04.2025.
//

import Foundation
import UIKit.UIApplication
import Zip
import SwiftUI
import IDeviceSwift

final class ArchiveHandler: NSObject {
	let viewModel: InstallerStatusViewModel
	
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	
	private let _app: AppSnapshot
	private let _sourceURL: URL?
	private let _uniqueWorkDir: URL
	
	@MainActor
	init(app: AppInfoPresentable, viewModel: InstallerStatusViewModel) {
		self.viewModel = viewModel
		self._app = AppSnapshot(app)
		self._sourceURL = Storage.shared.getAppDirectory(for: app)
		self._uniqueWorkDir = _fileManager.temporaryDirectory
			.appendingPathComponent("CSignInstall_\(_uuid)", isDirectory: true)
		
		super.init()
	}
	
	func prepare() async throws {
		guard let appURL = _sourceURL, _fileManager.fileExists(atPath: appURL.path) else {
			throw SigningFileHandlerError.appNotFound
		}
		try _fileManager.createDirectoryIfNeeded(at: _uniqueWorkDir)
	}

	func archive(forceNoCompression: Bool = false) async throws -> URL {
		guard let appURL = _sourceURL else { throw SigningFileHandlerError.appNotFound }
		let output = _uniqueWorkDir.appendingPathComponent("Archive.ipa")
		let compression = forceNoCompression ? ZipCompression.NoCompression :
			(ZipCompression(rawValue: Self.getCompressionLevel()) ?? .DefaultCompression)
		let level: Int32
		switch compression {
		case .NoCompression: level = 0
		case .BestSpeed: level = 1
		case .BestCompression: level = 9
		default: level = -1
		}
		try IPAArchiveWriter.write(app: appURL, to: output, compressionLevel: level) { progress in
			Task { @MainActor in self.viewModel.packageProgress = progress }
		}
		return output
	}

	func moveToArchive(_ package: URL, shouldOpen: Bool = false) async throws -> URL? {
		let safeName = (_app.name ?? "App").replacingOccurrences(of: "/", with: "_")
		let safeVersion = (_app.version ?? "1.0").replacingOccurrences(of: "/", with: "_")
		let appendingString = "\(safeName)_\(safeVersion)_\(_uuid.prefix(8)).ipa"
		let dest = _fileManager.archives.appendingPathComponent(appendingString)
		
		try _fileManager.createDirectoryIfNeeded(at: _fileManager.archives)
		try _fileManager.moveItem(
			at: package,
			to: dest
		)
		
		if shouldOpen {
			await MainActor.run {
				UIApplication.open(FileManager.default.archives.toSharedDocumentsURL()!)
			}
		}
		
		return dest
	}
	
	func clean() {
		try? _fileManager.removeItem(at: _uniqueWorkDir)
	}

	static func getCompressionLevel() -> Int {
		if UserDefaults.standard.object(forKey: "CSign.compressionLevel") == nil {
			return 2 // Default to DefaultCompression instead of NoCompression
		}
		return UserDefaults.standard.integer(forKey: "CSign.compressionLevel")
	}
}
