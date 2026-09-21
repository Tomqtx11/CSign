//
//  ZsignHandler.swift
//  CSign
//
//  Created by samara on 17.04.2025.
//

import Foundation
import ZsignSwift
import UIKit

final class ZsignHandler {
	var hadError: Error?
	
	private var _appUrl: URL
	private var _options: Options
	private var _certificate: CertificatePair?
	
	init(
		appUrl: URL,
		options: Options = OptionsManager.shared.options,
		cert: CertificatePair? = nil
	) {
		self._appUrl = appUrl
		self._options = options
		self._certificate = cert
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
		guard let cert = _certificate else {
			throw SigningFileHandlerError.missingCertifcate
		}

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                LogCapture.shared.updateProgress(phase: .signing, subProgress: 0.1)
                LogCapture.shared.printLog("   ↳ Khởi tạo chứng chỉ ký...")
                
                var localErr: Error? = nil
                LogCapture.shared.updateProgress(phase: .signing, subProgress: 0.15)
                LogCapture.shared.printLog("   ↳ Đang ký tất cả Mach-O binaries...")
                
                let startTime = CFAbsoluteTimeGetCurrent()
                
                let success = Zsign.sign(
                    appPath: self._appUrl.relativePath,
                    provisionPath: Storage.shared.getFile(.provision, from: cert)?.path ?? "",
                    p12Path: Storage.shared.getFile(.certificate, from: cert)?.path ?? "",
                    p12Password: cert.password ?? "",
                    entitlementsPath: self._options.appEntitlementsFile?.path ?? "",
                    customIdentifier: self._options.appIdentifier ?? "",
                    customName: self._options.appName ?? "",
                    customVersion: self._options.appVersion ?? "",
                    removeProvision: self._options.removeProvisioning,
                    completion: { _, error in
                        localErr = error
                    }
                )
                
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                LogCapture.shared.printLog("   ↳ Thời gian ký: \(String(format: "%.1f", elapsed))s")
                LogCapture.shared.updateProgress(phase: .signing, subProgress: 0.95)
                
                if !success {
                    continuation.resume(throwing: localErr ?? SigningFileHandlerError.signFailed)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
	}
	
	func adhocSign() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var localErr: Error? = nil
                let success = Zsign.sign(
                    appPath: self._appUrl.relativePath,
                    entitlementsPath: self._options.appEntitlementsFile?.path ?? "",
                    customIdentifier: self._options.appIdentifier ?? "",
                    customName: self._options.appName ?? "",
                    customVersion: self._options.appVersion ?? "",
                    adhoc: true,
                    removeProvision: self._options.removeProvisioning,
                    completion: { _, error in
                        localErr = error
                    }
                )
                if !success {
                    continuation.resume(throwing: localErr ?? SigningFileHandlerError.signFailed)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
	}
}
