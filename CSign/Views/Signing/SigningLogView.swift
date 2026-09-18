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
					let progress = calculateProgress(from: logCapture.logs)
					ProgressView(value: progress)
						.progressViewStyle(CircularProgressViewStyle())
					Text("\(Int(progress * 100))%")
						.font(.caption)
						.foregroundColor(.secondary)
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
						.id("LogText")
				}
				.background(Color(.secondarySystemBackground))
				.foregroundColor(Color.primary)
				.cornerRadius(8)
				.padding()
				.onChange(of: logCapture.logs) { _ in
					withAnimation {
						proxy.scrollTo("LogText", anchor: .bottom)
					}
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
	
	private func calculateProgress(from logs: String) -> Double {
		if !logCapture.isCapturing && error == nil { return 1.0 }
		var progress: Double = 0.05 // Initial
		if logs.contains("Tạo thư mục bộ nhớ đệm") { progress = 0.1 }
		if logs.contains("Sao chép tệp .app") { progress = 0.3 }
		if logs.contains("Chuẩn bị tuỳ chỉnh ứng dụng") { progress = 0.5 }
		if logs.contains("Đang gỡ bỏ (Disinject)") { progress = 0.6 }
		if logs.contains("Hoàn tất và lưu vào cơ sở dữ liệu") { progress = 0.9 }
		return progress
	}
}
