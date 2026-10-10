import Foundation

@main
struct RegressionTests {
	@MainActor
	static func main() async throws {
		let payload = URL(string: "http://127.0.0.1:4321/Payload.ipa?key=a+b&part=1")!
		let appName = "CSign & Friends + Tiếng Việt #1 <\"Test\">"
		let manifest = try InstallationLinks.externalManifest(payload: payload, identifier: "com.example.test", name: appName, version: "1.2+3")
		let query = URLComponents(url: manifest, resolvingAgainstBaseURL: false)!.queryItems!
		precondition(query.first { $0.name == "version" }?.value == "1.2+3")
		let fields = Dictionary(uniqueKeysWithValues: query.map { ($0.name, $0.value!) })
		// Exercise the external service's literal XML interpolation contract.
		let serviceXML = """
		<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
		<key>title</key><string>\(fields["name"]!)</string>
		<key>payload</key><string>\(fields["fetchurl"]!)</string>
		</dict></plist>
		"""
		let parsed = try PropertyListSerialization.propertyList(from: Data(serviceXML.utf8), options: [], format: nil) as! [String: String]
		precondition(parsed["title"] == appName, "External manifest must remain valid XML for special app names")
		precondition(parsed["payload"] == payload.absoluteString, "Payload query separators must survive XML interpolation")
		let installer = InstallationLinks.installer(manifest: manifest)
		let outerQuery = URLComponents(url: installer, resolvingAgainstBaseURL: false)!.queryItems!
		precondition(installer.scheme == "itms-services")
		precondition(installer.absoluteString.hasPrefix("itms-services://?action=download-manifest&url="), "iOS installation links require an empty authority (://)")
		precondition(outerQuery.first { $0.name == "url" }?.value == manifest.absoluteString)
		let page = InstallationLinks.installPage(installer: installer)
		let expression = try NSRegularExpression(pattern: "href=\"([^\"]+)\"")
		let range = NSRange(page.startIndex..<page.endIndex, in: page)
		let match = expression.firstMatch(in: page, range: range)!
		let hrefRange = Range(match.range(at: 1), in: page)!
		let decodedHref = String(page[hrefRange]).replacingOccurrences(of: "&amp;", with: "&")
		precondition(URL(string: decodedHref) == installer, "Safari's visible install link must preserve the complete nested manifest URL")
		precondition(page.contains(">Cài đặt</a>"), "Safari needs a visible install action even when automatic redirects are blocked")
		do {
			_ = try InstallationLinks.externalManifest(payload: payload, identifier: nil, name: nil, version: nil)
			preconditionFailure("Missing bundle identifier must fail")
		} catch InstallationError.invalidMetadata { }
		let local = URL(string: "https://example.backloop.dev:4321/app.plist")!
		precondition(InstallationLinks.installer(manifest: local).absoluteString.hasPrefix("itms-services://?"))
		precondition(URLComponents(url: InstallationLinks.installer(manifest: local), resolvingAgainstBaseURL: false)!.queryItems!.last?.value == local.absoluteString)

		let start = Date(timeIntervalSince1970: 0)
		var tracker = InstallProgressTracker(start: start, timeout: 10)
		precondition(tracker.update(nil, now: start) == .waiting)
		precondition(tracker.update(0.8, now: start) == .progress(0.8))
		precondition(tracker.update(nil, now: start) == .needsConfirmation)
		precondition(tracker.update(0, now: start) == .needsConfirmation)
		precondition(tracker.update(1, now: start) == .completed)
		tracker = InstallProgressTracker(start: start, timeout: 10)
		precondition(tracker.update(nil, now: start.addingTimeInterval(10)) == .needsConfirmation)
		precondition(tracker.update(.nan, now: start) == .waiting)

		let state = SigningProgress.shared
		precondition(state.start())
		precondition(!state.start(), "A second signer must not start")
		SigningProgress.update(phase: .signing, subProgress: 0.2)
		try await Task.sleep(nanoseconds: 50_000_000)
		let previous = state.progress
		SigningProgress.update(phase: .copying, subProgress: 0.5)
		try await Task.sleep(nanoseconds: 50_000_000)
		precondition(state.progress == previous, "Late phase updates must not move backwards")
		state.cancel()
		precondition(state.isRunning, "Cancel must wait for native work to settle")
		precondition(SigningProgress.cancellationRequested)
		state.finish(error: CancellationError())
		precondition(state.progress < 1)
		precondition(state.start())
		precondition(!SigningProgress.cancellationRequested)
		state.finish(error: nil)
		precondition(state.progress == 1 && !state.isRunning)
		print("PASS: iOS install URL format, Safari install action, URL encoding, installation completion, signing cancellation and single-operation guard")
	}
}
