import Foundation

enum InstallationError: Error, LocalizedError {
	case invalidMetadata
	case missingTLS
	case couldNotOpenInstaller
	case couldNotLoadInstallPage
	case invalidServerMethod

	var errorDescription: String? {
		switch self {
		case .invalidMetadata: return "Ứng dụng thiếu Bundle ID hoặc thông tin cài đặt hợp lệ. Hãy nhập và ký lại IPA."
		case .missingTLS: return "Thiếu chứng chỉ HTTPS cài đặt. Hãy cập nhật SSL trong Cài đặt hoặc chọn phương thức máy chủ ngoài."
		case .couldNotOpenInstaller: return "iOS không mở được trình cài đặt. Hãy kiểm tra phương thức cài trong Cài đặt."
		case .couldNotLoadInstallPage: return "Safari không tải được trang cài đặt trên iPhone. Hãy thử mở lại Safari; gói đã ký vẫn được giữ để cài lại."
		case .invalidServerMethod: return "Phương thức cài đặt không hợp lệ. Hãy chọn lại trong Cài đặt."
		}
	}
}

enum InstallationLinks {
	static func safariPage(port: Int) -> URL {
		var components = URLComponents()
		components.scheme = "http"
		components.host = "127.0.0.1"
		components.port = port
		components.path = "/install"
		return components.url!
	}

	static func externalManifest(payload: URL, identifier: String?, name: String?, version: String?) throws -> URL {
		guard let identifier, !identifier.isEmpty else { throw InstallationError.invalidMetadata }
		var components = URLComponents(string: "https://api.palera.in/genPlist")!
		components.queryItems = [
			// The plist service inserts query values directly into XML text nodes.
			URLQueryItem(name: "bundleid", value: xmlText(identifier)),
			URLQueryItem(name: "name", value: xmlText(name ?? identifier)),
			URLQueryItem(name: "version", value: xmlText(version ?? "1.0")),
			URLQueryItem(name: "fetchurl", value: xmlText(payload.absoluteString))
		]
		// Query decoders may treat '+' as a space; preserve literal plus signs.
		components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
		guard let url = components.url else { throw InstallationError.invalidMetadata }
		return url
	}

	private static func xmlText(_ value: String) -> String {
		value.replacingOccurrences(of: "&", with: "&amp;")
			.replacingOccurrences(of: "<", with: "&lt;")
			.replacingOccurrences(of: ">", with: "&gt;")
	}

	static func installer(manifest: URL) -> URL {
		var components = URLComponents()
		components.scheme = "itms-services"
		// An empty authority preserves Apple's required itms-services://? form.
		components.host = ""
		components.queryItems = [
			URLQueryItem(name: "action", value: "download-manifest"),
			URLQueryItem(name: "url", value: manifest.absoluteString)
		]
		components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
		return components.url!
	}

	static func installPage(installer: URL) -> String {
		let href = installer.absoluteString
			.replacingOccurrences(of: "&", with: "&amp;")
			.replacingOccurrences(of: "\"", with: "&quot;")
			.replacingOccurrences(of: "<", with: "&lt;")
			.replacingOccurrences(of: ">", with: "&gt;")
		return """
		<!doctype html><html lang="vi"><head><meta charset="utf-8">
		<meta name="viewport" content="width=device-width, initial-scale=1">
		<style>body{font:17px -apple-system,sans-serif;text-align:center;padding:36px 20px;color:#15414a;background:#f4fbfc}a{display:inline-block;background:#008aa6;color:white;padding:16px 28px;border-radius:18px;text-decoration:none}p{line-height:1.5}</style>
		<title>Cài đặt ứng dụng</title></head><body>
		<h2>Ứng dụng đã sẵn sàng</h2><p>Đang mở trình cài đặt. Nếu chưa hiện thông báo, bấm Cài đặt bên dưới.</p>
		<a id="install" href="\(href)">Cài đặt</a>
		<p>Giữ CSign mở cho đến khi iPhone tải xong gói cài đặt.</p>
		<script>
		window.addEventListener("load", function () {
		  setTimeout(function () {
		    try { window.location.href = document.getElementById("install").href; }
		    catch (error) { /* Keep the visible link if automatic navigation is blocked. */ }
		  }, 300);
		}, { once: true });
		</script>
		</body></html>
		"""
	}
}
