import SwiftUI

enum CSignTheme {
	static let defaultTint = "#008AA6"
	static let cyan = Color(uiColor: UIColor { traits in
		traits.userInterfaceStyle == .dark
			? UIColor(red: 0.16, green: 0.88, blue: 0.94, alpha: 1)
			: UIColor(red: 0, green: 0.54, blue: 0.65, alpha: 1)
	})
	static let pink = Color(uiColor: UIColor { traits in
		traits.userInterfaceStyle == .dark
			? UIColor(red: 1, green: 0.34, blue: 0.77, alpha: 1)
			: UIColor(red: 0.76, green: 0.12, blue: 0.48, alpha: 1)
	})
	static let gradient = LinearGradient(colors: [cyan, pink], startPoint: .topLeading, endPoint: .bottomTrailing)

	static func tint(_ hex: String) -> Color {
		hex == defaultTint ? cyan : Color(hex: hex)
	}
}

/// A tiny vector mascot: no GIF decoder, image frames, timers or network requests.
struct CSignMascotView: View {
	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.scenePhase) private var scenePhase
	@AppStorage("CSign.playfulAnimations") private var enabled = true
	@State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
	@State private var bouncing = false
	var isWorking = false

	private var shouldAnimate: Bool {
		isWorking && enabled && !reduceMotion && !lowPower && scenePhase == .active
	}

	var body: some View {
		ZStack {
			RoundedRectangle(cornerRadius: 18).fill(CSignTheme.gradient).opacity(0.12)
			Path { path in
				path.move(to: CGPoint(x: 10, y: 24))
				path.addLine(to: CGPoint(x: 12, y: 9))
				path.addLine(to: CGPoint(x: 24, y: 19))
				path.addLine(to: CGPoint(x: 36, y: 9))
				path.addLine(to: CGPoint(x: 38, y: 24))
				path.closeSubpath()
			}.fill(CSignTheme.gradient)
			RoundedRectangle(cornerRadius: 12)
				.fill(CSignTheme.gradient)
				.frame(width: 32, height: 27)
				.offset(y: 5)
			HStack(spacing: 9) {
				Capsule().frame(width: 3, height: 6)
				Capsule().frame(width: 3, height: 6)
			}.foregroundStyle(.white).offset(y: 3)
			Text("ω").font(.system(size: 12, weight: .bold)).foregroundStyle(.white).offset(y: 11)
		}
		.frame(width: 48, height: 48)
		.rotationEffect(.degrees(bouncing ? 7 : -4))
		.offset(y: bouncing ? -3 : 0)
		.animation(shouldAnimate ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : nil, value: bouncing)
		.task(id: shouldAnimate) { bouncing = shouldAnimate }
		.onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
			lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
		}
		.accessibilityHidden(true)
	}
}

struct CSignBrandCard: View {
	var title = "CSign"
	var subtitle = "Ký app gọn nhẹ, theo cách của bạn."
	var isWorking = false

	var body: some View {
		HStack(spacing: 14) {
			CSignMascotView(isWorking: isWorking)
			VStack(alignment: .leading, spacing: 4) {
				Text(title).font(.system(.title3, design: .rounded).bold()).foregroundStyle(CSignTheme.gradient)
				Text(subtitle).font(.caption).foregroundStyle(.secondary)
			}
			Spacer(minLength: 0)
			Image(systemName: "sparkles").foregroundStyle(CSignTheme.pink)
		}
		.padding(16)
		.background { RoundedRectangle(cornerRadius: 20).fill(CSignTheme.gradient).opacity(0.06) }
		.overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(CSignTheme.gradient, lineWidth: 1).opacity(0.25) }
	}
}
