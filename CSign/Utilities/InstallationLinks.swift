import Foundation

enum InstallationError: Error, LocalizedError {
	case invalidMetadata
	case missingTLS
	case couldNotOpenInstaller
	case invalidServerMethod

	var errorDescription: String? {
		switch self {
		case .invalidMetadata: return "Ứng dụng thiếu Bundle ID hoặc thông tin cài đặt hợp lệ. Hãy nhập và ký lại IPA."
		case .missingTLS: return "Thiếu chứng chỉ HTTPS cài đặt. Hãy cập nhật SSL trong Cài đặt hoặc chọn phương thức máy chủ ngoài."
		case .couldNotOpenInstaller: return "iOS không mở được trình cài đặt. Hãy kiểm tra phương thức cài trong Cài đặt."
		case .invalidServerMethod: return "Phương thức cài đặt không hợp lệ. Hãy chọn lại trong Cài đặt."
		}
	}
}

enum InstallationLinks {
	static func externalManifest(payload: URL, identifier: String?, name: String?, version: String?) throws -> URL {
		guard let identifier, !identifier.isEmpty else { throw InstallationError.invalidMetadata }
		var components = URLComponents(string: "https://api.palera.in/genPlist")!
		components.queryItems = [
			URLQueryItem(name: "bundleid", value: identifier),
			URLQueryItem(name: "name", value: name ?? identifier),
			URLQueryItem(name: "version", value: version ?? "1.0"),
			URLQueryItem(name: "fetchurl", value: payload.absoluteString)
		]
		// Query decoders may treat '+' as a space; preserve literal plus signs.
		components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
		guard let url = components.url else { throw InstallationError.invalidMetadata }
		return url
	}

	static func installer(manifest: URL) -> URL {
		var components = URLComponents()
		components.scheme = "itms-services"
		components.queryItems = [
			URLQueryItem(name: "action", value: "download-manifest"),
			URLQueryItem(name: "url", value: manifest.absoluteString)
		]
		components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
		return components.url!
	}
}
