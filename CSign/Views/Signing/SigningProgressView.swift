import SwiftUI

struct SigningProgressView: View {
	let app: AppInfoPresentable
	let options: Options
	let error: Error?
	let finished: Bool
	var onClose: () -> Void
	var onInstall: () -> Void
	var onExport: () -> Void
	@ObservedObject private var progress = SigningProgress.shared

	var body: some View {
		VStack(spacing: 18) {
			HStack(spacing: 14) {
				FRAppIconView(app: app, size: 56)
				VStack(alignment: .leading, spacing: 4) {
					Text(options.appName ?? app.name ?? "Ứng dụng").font(.headline).lineLimit(2)
					Text(options.appIdentifier ?? app.identifier ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(1)
				}
				Spacer(minLength: 0)
				CSignMascotView(mood: error != nil ? .idle : (finished ? .celebrating : .signing))
			}
			if let error {
				Label(error.localizedDescription, systemImage: "exclamationmark.circle.fill")
					.font(.subheadline).foregroundStyle(progress.isCancelled ? Color.secondary : Color.red)
			} else if finished {
				Label(options.signingOption == .onlyModify ? "Đã lưu bản tuỳ chỉnh" : "Ký thành công", systemImage: "checkmark.seal.fill")
					.font(.headline).foregroundStyle(CSignTheme.cyan)
			} else {
				HStack {
					ProgressView()
					Text(progress.isCancelled ? "Đang dừng sau bước hiện tại…" : progress.currentPhase.rawValue + "…")
						.font(.subheadline)
					Spacer()
				}
				ProgressView(value: progress.progress).tint(CSignTheme.cyan)
			}
			if finished {
				if error == nil {
					HStack {
						if options.signingOption != .onlyModify {
							Button("Cài đặt", action: onInstall).buttonStyle(.borderedProminent)
						}
						Button("Xuất IPA", action: onExport).buttonStyle(.bordered)
					}
				}
				Button("Đóng", action: onClose).buttonStyle(.bordered)
			} else {
				Button("Huỷ", role: .cancel) { progress.cancel() }
					.disabled(progress.isCancelled)
			}
		}
		.padding(24)
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(CSignTheme.gradient.opacity(0.05))
        .onAppear { recordSuccess() }
        .onChange(of: finished) { _ in recordSuccess() }
	}
    private func recordSuccess() {
        if finished && error == nil && options.signingOption != .onlyModify {
            ExperienceStore.shared.complete(.signed)
        }
    }
}
