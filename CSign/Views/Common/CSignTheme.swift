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

/// Vector companion using the existing brand; respects motion, scene and battery preferences.
struct CSignMascotView: View {
    enum Mood: Equatable { case idle, downloading, signing, celebrating }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("CSign.playfulAnimations") private var enabled = true
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var bouncing = false
    var isWorking = false
    var mood: Mood = .idle
    var lively = false
    private var activeMood: Mood { isWorking ? .signing : mood }
    private var shouldAnimate: Bool {
        (activeMood != .idle || lively) && enabled && !reduceMotion && !lowPower && scenePhase == .active
    }
    private var symbol: String {
        switch activeMood {
        case .idle: return "heart.fill"
        case .downloading: return "arrow.down.circle.fill"
        case .signing: return "pencil.circle.fill"
        case .celebrating: return "sparkles"
        }
    }
    var body: some View {
        ZStack {
            if activeMood == .celebrating || lively {
                ForEach(0..<5) { i in
                    Image(systemName: i.isMultiple(of: 2) ? "sparkle" : "circle.fill")
                        .font(.system(size: i.isMultiple(of: 2) ? 8 : 3, weight: .bold))
                        .foregroundStyle(i.isMultiple(of: 2) ? CSignTheme.pink : CSignTheme.cyan)
                        .offset(x: cos(Double(i) * 1.26) * 29, y: sin(Double(i) * 1.26) * 29)
                        .opacity(shouldAnimate && bouncing ? 0.9 : 0.4)
                }
            }
            RoundedRectangle(cornerRadius: 18).fill(CSignTheme.gradient).opacity(0.12)
            Path { path in
                path.move(to: CGPoint(x: 10, y: 24))
                path.addLine(to: CGPoint(x: 12, y: 9))
                path.addLine(to: CGPoint(x: 24, y: 19))
                path.addLine(to: CGPoint(x: 36, y: 9))
                path.addLine(to: CGPoint(x: 38, y: 24))
                path.closeSubpath()
            }.fill(CSignTheme.gradient)
            RoundedRectangle(cornerRadius: 12).fill(CSignTheme.gradient)
                .frame(width: 32, height: 27).offset(y: 5)
            HStack(spacing: 9) {
                Capsule().frame(width: 3, height: activeMood == .celebrating ? 3 : 6)
                Capsule().frame(width: 3, height: activeMood == .celebrating ? 3 : 6)
            }.foregroundStyle(.white).offset(y: 3)
            Text("ω").font(.system(size: 12, weight: .bold)).foregroundStyle(.white).offset(y: 11)
            Image(systemName: symbol).font(.system(size: 12, weight: .bold))
                .foregroundStyle(CSignTheme.pink).offset(x: 19, y: -18)
        }
        .frame(width: 48, height: 48)
        .rotationEffect(.degrees(shouldAnimate ? (bouncing ? 7 : -4) : 0))
        .offset(y: shouldAnimate && bouncing ? -3 : 0)
        .animation(shouldAnimate ? .easeInOut(duration: 1.2).repeatForever(autoreverses: true) : nil, value: bouncing)
        .task(id: shouldAnimate) { bouncing = shouldAnimate }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .accessibilityHidden(true)
    }
}
