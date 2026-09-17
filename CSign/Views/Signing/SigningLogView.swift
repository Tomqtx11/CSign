import SwiftUI

struct SigningLogView: View {
	let app: AppInfoPresentable
	let options: Options
	let error: Error?
	var onDismiss: () -> Void
	
	@ObservedObject var logCapture = LogCapture.shared
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Text(.localized("Quá trình Ký"))
					.font(.headline)
				Spacer()
				if error == nil && logCapture.isCapturing {
					ProgressView()
				} else {
					Button(.localized("Đóng")) {
						dismiss()
						onDismiss()
					}
					.font(.headline)
					.foregroundColor(.accentColor)
				}
			}
			.padding()
			.background(Color(.secondarySystemBackground))
			
			// App Info
			VStack(alignment: .leading, spacing: 8) {
				Text("📦 Tên App: \(options.appName ?? app.name ?? "Không rõ")")
				Text("🆔 Bundle ID: \(options.appIdentifier ?? app.identifier ?? "Không rõ")")
				Text("🏷 Phiên bản: \(options.appVersion ?? app.version ?? "Không rõ")")
				
				if !options.disInjectionFiles.isEmpty {
					Text("✂️ Đã xoá (Disinject): \(options.disInjectionFiles.count) dylib")
				}
				
				if let error = error {
					Text("❌ Lỗi: \(error.localizedDescription)")
						.foregroundColor(.red)
						.bold()
				} else if !logCapture.isCapturing {
					Text("✅ Ký thành công! Đang hoàn tất...")
						.foregroundColor(.green)
						.bold()
				}
			}
			.font(.subheadline)
			.padding()
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(Color(.systemBackground))
			
			Divider()
			
			// Console Logs
			ScrollViewReader { proxy in
				ScrollView {
					Text(logCapture.logs)
						.font(.system(.caption, design: .monospaced))
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding()
						.id("LOG_BOTTOM")
				}
				.background(Color.black)
				.foregroundColor(.green)
				.onChange(of: logCapture.logs) { _ in
					proxy.scrollTo("LOG_BOTTOM", anchor: .bottom)
				}
			}
		}
		.onChange(of: logCapture.isCapturing) { isCapturing in
			if !isCapturing && error == nil {
				DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
					dismiss()
					onDismiss()
				}
			}
		}
	}
}
