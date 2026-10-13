import SwiftUI

struct ExperienceCard: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(18)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.primary.opacity(0.055), lineWidth: 1))
    }
}
extension View {
    func experienceCard() -> some View { modifier(ExperienceCard()) }
}

struct ExperienceHero: View {
    let greeting: String
    let appCount: Int
    let sourceCount: Int
    let downloading: Bool
    @ObservedObject private var experience = ExperienceStore.shared
    @State private var tapCount = 0
    @State private var cheering = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("CSign.playfulAnimations") private var animations = true
    private var subtitle: String {
        if cheering { return "Cùng khám phá điều mới nào! ✨" }
        if downloading { return "Mình đang đồng hành cùng bản tải của bạn." }
        if let badge = experience.state.equippedBadge { return "Đang đeo huy hiệu \(badge.badgeName)" }
        return "Kho ứng dụng của bạn, một thế giới để khám phá."
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Label("CSign • PLAY & DISCOVER", systemImage: "sparkles")
                        .font(.caption2.weight(.bold)).foregroundStyle(CSignTheme.cyan)
                    Text(greeting).font(.title2.bold()).fixedSize(horizontal: false, vertical: true)
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }.frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    tapCount += 1
                    withAnimation(animations && !reduceMotion ? .spring(response: 0.35) : nil) { cheering = true }
                } label: {
                    ZStack {
                        Circle().fill(CSignTheme.gradient.opacity(0.12)).frame(width: 88, height: 88)
                        CSignMascotView(mood: cheering ? .celebrating : (downloading ? .downloading : .idle), lively: true)
                            .scaleEffect(1.55)
                        if let badge = experience.state.equippedBadge {
                            Image(systemName: badge.symbol + (badge == .favorite ? ".fill" : ""))
                                .font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                .padding(8).background(CSignTheme.gradient, in: Circle()).offset(x: 30, y: 30)
                        }
                    }
                }.buttonStyle(.plain).accessibilityLabel("Chào linh vật CSign")
                .task(id: tapCount) {
                    guard tapCount > 0 else { return }
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    guard !Task.isCancelled else { return }
                    withAnimation(animations && !reduceMotion ? .easeOut : nil) { cheering = false }
                }
            }
            HStack(spacing: 0) {
                heroStat("\(sourceCount)", "kho nguồn", "externaldrive")
                Spacer(minLength: 8)
                heroStat("\(appCount)", "IPA đã ký", "signature")
                Spacer(minLength: 8)
                heroStat("\(experience.state.completedMissions.count)/4", "huy hiệu", "seal")
            }
        }.experienceCard()
        .background(CSignTheme.gradient.opacity(0.07), in: RoundedRectangle(cornerRadius: 24))
    }
    private func heroStat(_ value: String, _ caption: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(value, systemImage: icon).font(.headline)
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct ExperienceBadge: View {
    let mission: ExperienceMission
    let unlocked: Bool
    var equipped = false
    var body: some View {
        VStack(spacing: 9) {
            ZStack {
                Circle().fill(unlocked ? CSignTheme.gradient : LinearGradient(colors: [.gray.opacity(0.16), .gray.opacity(0.08)], startPoint: .top, endPoint: .bottom))
                Circle().stroke(.white.opacity(unlocked ? 0.45 : 0), lineWidth: 2).padding(6)
                Image(systemName: unlocked ? mission.symbol : "lock.fill")
                    .font(.system(size: 23, weight: .semibold)).foregroundStyle(unlocked ? Color.white : Color.secondary)
                if equipped {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(CSignTheme.cyan)
                        .background(.background, in: Circle()).offset(x: 22, y: 22)
                }
            }.frame(width: 64, height: 64)
            Text(mission.badgeName).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(equipped ? "Đang đeo" : (unlocked ? "Đã nhận" : "Chưa mở"))
                .font(.caption2).foregroundStyle(unlocked ? CSignTheme.cyan : Color.secondary)
        }.frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

struct ExperienceSectionHeading: View {
    let title: String
    let subtitle: String
    let symbol: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Label(title, systemImage: symbol).font(.title3.bold())
            Text(subtitle).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
