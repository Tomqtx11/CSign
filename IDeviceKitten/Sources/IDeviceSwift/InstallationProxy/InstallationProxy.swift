//
//  ConduitInstaller.swift
//  Feather
//
//  Created by samara on 23.04.2025.
//

import Foundation
import SwiftUI
import IDevice
import UIKit.UIApplication

public class InstallationProxy: Identifiable, ObservableObject {
	private let _heartbeat = HeartbeatManager.shared
	private let _uuid = UUID().uuidString
	
	typealias AfcClientHandle = OpaquePointer
	typealias AfcFileHandle = OpaquePointer
	typealias InstallationProxyClientHandle = OpaquePointer
	
	@ObservedObject
	public var viewModel: InstallerStatusViewModel
	
	public init(viewModel: InstallerStatusViewModel) {
		self.viewModel = viewModel
	}
	
	public func install(at url: URL, suspend: Bool = false) async throws {
		var afcClient: AfcClientHandle?
		var fileHandle: AfcFileHandle?
		var installproxy: InstallationProxyClientHandle?
		
		let work = Task.detached(priority: .utility) {
			guard FileManager.default.fileExists(atPath: HeartbeatManager.pairingFile()) else {
				throw IDeviceSwiftError(message: "Missing Pairing")
			}
			
			if await self._heartbeat.isRsd {
				guard await self._heartbeat.ensureRSDTunnel() else {
					throw IDeviceSwiftError(message: "Missing Pairing")
				}
			} else {
				guard await self._heartbeat.checkSocketConnection().isConnected else {
					throw IDeviceSwiftError(message: "Missing Pairing")
				}
			}
			
			var fileClosed = false
			defer {
				if !fileClosed, let fileHandle { _ = afc_file_close(fileHandle) }
				afc_client_free(afcClient)
				installation_proxy_client_free(installproxy)
			}
			
			let heartbeat = await self._heartbeat
			
			if heartbeat.isRsd {
				guard let adapter = heartbeat.adapter else {
					throw IDeviceSwiftError(message: "Cannot find RSD adapter")
				}
				
				guard let handshake = heartbeat.handshake else {
					throw IDeviceSwiftError(message: "Cannot find RSD handshake")
				}
	
				guard afc_client_connect_rsd(adapter, handshake, &afcClient) == nil else {
					throw IDeviceSwiftError(message: "Cannot connect to AFC")
				}
			} else {
				guard let provider = heartbeat.provider else {
					throw IDeviceSwiftError(message: "Cannot find TCP provider")
				}
				
				guard afc_client_connect(provider, &afcClient) == nil else {
					throw IDeviceSwiftError(message: "Cannot connect to AFC")
				}
			}
			
			let stagingDir = "PublicStaging"
			
			let afc_make_directory_result =  afc_make_directory(afcClient, stagingDir)
			guard afc_make_directory_result == nil else {
				throw IDeviceSwiftError(afc_make_directory_result)
			}
			
			let remoteDir = "/\(stagingDir)/\(self._uuid).ipa"
			
			let afc_file_open_result = afc_file_open(afcClient, remoteDir, AfcWrOnly, &fileHandle)
			guard afc_file_open_result == nil else {
				throw IDeviceSwiftError(afc_file_open_result)
			}
			
			try await self._updateStatus(with: .sendingPayload)
			
			guard let fileHandle = fileHandle else {
				throw IDeviceSwiftError(message: "Missing File Handle")
			}
			
			let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
			let totalSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
			guard totalSize > 0 else { throw IDeviceSwiftError(message: "Empty IPA") }
			let input = try FileHandle(forReadingFrom: url)
			defer { try? input.close() }
			var totalBytesWritten: Int64 = 0
			// Keep memory bounded and use the pointer only inside withUnsafeBytes.
			while let chunk = try input.read(upToCount: 1024 * 1024), !chunk.isEmpty {
				try Task.checkCancellation()
				let writeError = chunk.withUnsafeBytes { buffer in
					afc_file_write(fileHandle, buffer.baseAddress!.assumingMemoryBound(to: UInt8.self), chunk.count)
				}
				if let writeError { throw IDeviceSwiftError(writeError) }
				totalBytesWritten += Int64(chunk.count)
				try await self._updateUploadProgress(with: Double(totalBytesWritten) / Double(totalSize))
			}
			guard totalBytesWritten == totalSize else { throw IDeviceSwiftError(message: "Incomplete IPA upload") }

			
			let afc_file_close_result = afc_file_close(fileHandle)
			guard afc_file_close_result == nil else {
				throw IDeviceSwiftError(afc_file_close_result)
			}
			
			fileClosed = true
			try await self._updateStatus(with: .installing)
			
			if heartbeat.isRsd {
				guard let adapter = heartbeat.adapter else {
					throw IDeviceSwiftError(message: "Cannot find RSD adapter")
				}
				
				guard let handshake = heartbeat.handshake else {
					throw IDeviceSwiftError(message: "Cannot find RSD handshake")
				}
				
				
				let installation_proxy_connect_rsd_result = installation_proxy_connect_rsd(adapter, handshake, &installproxy)
				guard installation_proxy_connect_rsd_result == nil else {
					throw IDeviceSwiftError(installation_proxy_connect_rsd_result)
				}
			} else {
				guard let provider = heartbeat.provider else {
					throw IDeviceSwiftError(message: "Cannot find TCP provider")
				}
				let installation_proxy_connect_result = installation_proxy_connect(provider, &installproxy)
				guard installation_proxy_connect_result == nil else {
					throw IDeviceSwiftError(installation_proxy_connect_result)
				}
			}
			
			let installError: UnsafeMutablePointer<IdeviceFfiError>? = remoteDir.withCString { cString in
				let context = Unmanaged.passUnretained(self).toOpaque()
				
				if suspend {
					DispatchQueue.main.async {
						UIApplication.shared.perform(#selector(NSXPCConnection.suspend))
					}
				}
				
				return installation_proxy_install_with_callback(
					installproxy,
					cString,
					nil, // options
					Self._installationProgressCallback,
					context
				)
			}
			
			guard installError == nil else {
				throw IDeviceSwiftError(installError)
			}
			
			try await Task.sleep(nanoseconds: 350_000_000)
			try await self._updateStatus(with: .completed(.success(())))
		}
		try await withTaskCancellationHandler {
			try await work.value
		} onCancel: {
			work.cancel()
		}
	}
	
	private func _updateStatus(with status: InstallerStatusViewModel.InstallerStatus) async throws {
		await MainActor.run {
			self.viewModel.status = status
		}
	}
	
	private func _updateUploadProgress(with status: Double) async throws {
		await MainActor.run {
			self.viewModel.uploadProgress = status
		}
	}
	
	nonisolated static private let _installationProgressCallback: @convention(c) (
		UInt64,
		UnsafeMutableRawPointer?
	) -> Void = { progress, context in
		guard let context = context else { return }
		let installer = Unmanaged<InstallationProxy>.fromOpaque(context).takeUnretainedValue()
		Task {
			try? await installer._updateInstallProgress(with: Double(progress) / 100.0)
		}
	}
	
	private func _updateInstallProgress(with status: Double) async throws {
		await MainActor.run {
			self.viewModel.installProgress = status
		}
	}
}
