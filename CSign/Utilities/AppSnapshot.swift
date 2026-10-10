import Foundation

/// Read managed objects on their context's queue before doing file work.
struct AppSnapshot: AppInfoPresentable {
	let name: String?
	let version: String?
	let identifier: String?
	let date: Date?
	let icon: String?
	let uuid: String?
	let source: URL?
	let isSigned: Bool

	init(_ app: AppInfoPresentable) {
		name = app.name
		version = app.version
		identifier = app.identifier
		date = app.date
		icon = app.icon
		uuid = app.uuid
		source = app.source
		isSigned = app.isSigned
	}
}

struct SigningIdentity {
	let provisionURL: URL?
	let certificateURL: URL?
	let password: String
	let expiration: Date?

	init(_ certificate: CertificatePair) {
		provisionURL = Storage.shared.getFile(.provision, from: certificate)
		certificateURL = Storage.shared.getFile(.certificate, from: certificate)
		password = certificate.password ?? ""
		expiration = certificate.expiration
	}
}
