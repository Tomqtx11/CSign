//
//  Server.swift
//  csign
//
//  Created by samara on 22.08.2024.
//  Copyright © 2024 Lakr Aream. All Rights Reserved.
//  ORIGINALLY LICENSED UNDER GPL-3.0, MODIFIED FOR USE FOR FEATHER
//

import Foundation
import Vapor
import NIOSSL
import NIOTLS
import SwiftUI
import IDeviceSwift

// MARK: - Class
class ServerInstaller: Identifiable, ObservableObject {
	let id = UUID()
	let port = Int.random(in: 4000...8000)
	private var _needsShutdown = false
	private let _lifecycleLock = NSLock()
	
	var packageUrl: URL?
	let app: AppSnapshot
	private let _serverMethod: Int
	private let _ipFix: Bool
	@ObservedObject var viewModel: InstallerStatusViewModel
	private var _server: Application?

	init(app: AppInfoPresentable, viewModel: InstallerStatusViewModel) {
		self.app = AppSnapshot(app)
		self._serverMethod = UserDefaults.standard.integer(forKey: "CSign.serverMethod")
		self._ipFix = UserDefaults.standard.bool(forKey: "CSign.ipFix")
		self.viewModel = viewModel
	}

	func start() throws {
		_lifecycleLock.lock()
		defer { _lifecycleLock.unlock() }
		guard app.identifier?.isEmpty == false else { throw InstallationError.invalidMetadata }
		guard (0...1).contains(_serverMethod) else { throw InstallationError.invalidServerMethod }
		try _setup()
		_needsShutdown = true
		try _configureRoutes()
		try _server?.server.start()
	}
	
	deinit {
		_shutdownServer()
	}
	
	private func _setup() throws {
		self._server = try setupApp(port: port)
	}
		
	private func _configureRoutes() throws {
		_server?.get("*") { [weak self] req in
			guard let self else { return Response(status: .badGateway) }
			switch req.url.path {
			case plistEndpoint.path:
				self._updateStatus(.sendingManifest)
				return Response(status: .ok, version: req.version, headers: [
					"Content-Type": "text/xml",
				], body: .init(data: installManifestData))
			case displayImageSmallEndpoint.path:
				return Response(status: .ok, version: req.version, headers: [
					"Content-Type": "image/png",
				], body: .init(data: displayImageSmallData))
			case displayImageLargeEndpoint.path:
				return Response(status: .ok, version: req.version, headers: [
					"Content-Type": "image/png",
				], body: .init(data: displayImageLargeData))
			case payloadEndpoint.path:
				guard let packageUrl = packageUrl else {
					return Response(status: .notFound)
				}
				
				self._updateStatus(.sendingPayload)
				
				return req.fileio.streamFile(
					at: packageUrl.path
				) { result in
					switch result {
					case .success:
						self._updateStatus(.installing)
					case .failure(let error):
						self._updateStatus(.broken(error))
					}

				}
			case "/install":
				var headers = HTTPHeaders()
				headers.add(name: .contentType, value: "text/html")
				return Response(status: .ok, headers: headers, body: .init(string: self.html))
			default:
				return Response(status: .notFound)
			}
		}
	}
	
	func shutdown() {
		_shutdownServer()
	}

	private func _shutdownServer() {
		_lifecycleLock.lock()
		defer { _lifecycleLock.unlock() }
		guard _needsShutdown else { return }
		
		_needsShutdown = false
		_server?.server.shutdown()
		_server?.shutdown()
	}
	
	private func _updateStatus(_ newStatus: InstallerStatusViewModel.InstallerStatus) {
		DispatchQueue.main.async {
			switch self.viewModel.status {
			case .completed, .broken: return
			default: break
			}
			self.viewModel.status = newStatus
		}
	}
		
	func getServerMethod() -> Int {
		_serverMethod
	}
	
	func getIPFix() -> Bool {
		_ipFix
	}
}
