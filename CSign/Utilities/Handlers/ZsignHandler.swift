//
//  ZsignHandler.swift
//  Feather
//
//  Created by samara on 17.04.2025.
//

import Foundation
import ZsignSwift
import ZsignC
import UIKit

final class ZsignHandler {
	private var _appUrl: URL
	private var _options: Options
	private let _identity: SigningIdentity?
	
	init(
		appUrl: URL,
		options: Options = OptionsManager.shared.options,
		identity: SigningIdentity? = nil
	) {
		self._appUrl = appUrl
		self._options = options
		self._identity = identity
	}
	
	func disinject() async throws {
		guard !_options.disInjectionFiles.isEmpty else {
			return
		}
		
		let bundle = Bundle(url: _appUrl)
		let execPath = _appUrl.appendingPathComponent(bundle?.exec ?? "").relativePath
		
		return try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: .userInitiated).async {
				if !Zsign.removeDylibs(appExecutable: execPath, using: self._options.disInjectionFiles) {
					continuation.resume(throwing: SigningFileHandlerError.disinjectFailed)
				} else {
					continuation.resume(returning: ())
				}
			}
		}
	}
	
	func sign() async throws {
		guard let identity = _identity else {
			throw SigningFileHandlerError.missingCertifcate
		}

		guard let provision = identity.provisionURL, let certificate = identity.certificateURL,
			FileManager.default.fileExists(atPath: provision.path),
			FileManager.default.fileExists(atPath: certificate.path)
		else { throw SigningFileHandlerError.certificateFilesMissing }
		if let expiration = identity.expiration, expiration <= Date() {
			throw SigningFileHandlerError.certificateExpired
		}
		return try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: .userInitiated).async {
				guard p12_password_check(certificate.path, identity.password) else {
					continuation.resume(throwing: SigningFileHandlerError.invalidCertificatePassword)
					return
				}
				let success = Zsign.sign(
					appPath: self._appUrl.relativePath,
					provisionPath: identity.provisionURL?.path ?? "",
					p12Path: identity.certificateURL?.path ?? "",
					p12Password: identity.password,
					entitlementsPath: self._options.appEntitlementsFile?.path ?? "",
					removeProvision: self._options.removeProvisioning,
					completion: { _ in }
				)
				if !success {
					continuation.resume(throwing: SigningFileHandlerError.signFailed)
				} else {
					continuation.resume(returning: ())
				}
			}
		}
	}
	
	func adhocSign() async throws {
		return try await withCheckedThrowingContinuation { continuation in
			DispatchQueue.global(qos: .userInitiated).async {
				let success = Zsign.sign(
					appPath: self._appUrl.relativePath,
					entitlementsPath: self._options.appEntitlementsFile?.path ?? "",
					adhoc: true,
					removeProvision: self._options.removeProvisioning,
					completion: { _ in }
				)
				if !success {
					continuation.resume(throwing: SigningFileHandlerError.signFailed)
				} else {
					continuation.resume(returning: ())
				}
			}
		}
	}
}
