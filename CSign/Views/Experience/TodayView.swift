import SwiftUI
import NimbleViews

struct TodayView: View {
    @ObservedObject private var experience = ExperienceStore.shared
    @ObservedObject private var sources = SourcesViewModel.shared
    @ObservedObject private var downloads = DownloadManager.shared
    @ObservedObject private var updates = UpdateManager.shared
    @AppStorage("csign.selectedCert") private var selectedCertificate = 0
    @AppStorage("csign.selectedCertUUID") private var selectedCertificateID = ""
    @AppStorage("CSign.activeTab") private var activeTab = TabEnum.today.rawValue
    @FetchRequest(entity: AltSource.entity(), sortDescriptors: []) private var repositories: FetchedResults<AltSource>
    @FetchRequest(entity: CertificatePair.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)])
    private var certificates: FetchedResults<CertificatePair>
    @FetchRequest(entity: Signed.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)])
    private var signedApps: FetchedResults<Signed>
    @FetchRequest(entity: Imported.entity(), sortDescriptors: []) private var importedApps: FetchedResults<Imported>
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("CSign.playfulAnimations") private var animations = true
    @State private var checking = false
    @State private var showingCertificate = false
    @State private var showingGuide = false
    @State private var profileName: String?
    @State private var newBadge: ExperienceMission?
    @State private var observedMissions: Set<ExperienceMission> = []
    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Chào buổi sáng ☀️"
        case 12..<18: return "Một chiều đầy cảm hứng"
        default: return "Tối nay khám phá gì?"
        }
    }
    private var certificateIDs: [String] { certificates.map { $0.uuid ?? $0.objectID.uriRepresentation().absoluteString } }
    private var certificate: CertificatePair? {
        guard let index = ExperienceCertificateSelection.index(identifiers: certificateIDs, selectedID: selectedCertificateID, legacyIndex: selectedCertificate) else { return nil }
        return certificates[index]
    }
    private var newFavorites: Int {
        experience.catalog(sources.sources, matching: Set(experience.state.favorites.map(\.id))).filter { experience.hasUpdate($0) }.count
    }
    var body: some View {
        NBNavigationView("Hôm nay") {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 22) {
                    ExperienceHero(greeting: greeting, appCount: signedApps.count, sourceCount: repositories.count, downloading: !downloads.downloads.isEmpty)
                    certificateCard
                    quickActions
                    if let newBadge {
                        NavigationLink { MissionsView() } label: {
                            Label("Vừa nhận huy hiệu \(newBadge.badgeName)! Bấm để đeo.", systemImage: "seal.fill")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(CSignTheme.pink)
                                .frame(maxWidth: .infinity, alignment: .leading).experienceCard()
                        }.buttonStyle(.plain).transition(.opacity.combined(with: .scale(scale: 0.96)))
                    }
                    CuratedShelf(games: false)
                    CuratedShelf(games: true)
                    playingSection
                    badgesSection
                    toolsSection
                }.padding(16).frame(maxWidth: 820)
                    .frame(maxWidth: .infinity)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .sheet(isPresented: $showingCertificate) { certificateSheet }
            .sheet(isPresented: $showingGuide) { ExperienceGuideSheet() }
            .refreshable { await refresh(checkUpdates: true) }
            .task {
                observedMissions = experience.state.completedMissions
                recordExistingProgress()
                await refresh(checkUpdates: false)
            }
            .task(id: certificateIDs) { reconcileCertificate() }
            .task(id: selectedCertificateID) { loadProfileName() }
            .onChange(of: signedApps.count) { _ in recordExistingProgress() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { recordExistingProgress(); reconcileCertificate() }
            }
            .onChange(of: experience.state.completedMissions) { completed in
                let earned = completed.subtracting(observedMissions)
                observedMissions = completed
                guard !earned.isEmpty else { return }
                withAnimation(animations && !reduceMotion ? .spring(response: 0.4) : nil) {
                    newBadge = ExperienceMission.allCases.last { earned.contains($0) }
                }
            }
        }
    }
    private var certificateCard: some View {
        Button { showingCertificate = true } label: {
            HStack(spacing: 14) {
                Image(systemName: certificate == nil ? "checkmark.seal" : "checkmark.seal.fill")
                    .font(.title2).foregroundStyle(CSignTheme.cyan)
                    .frame(width: 48, height: 48).background(CSignTheme.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 5) {
                    Text(certificate == nil ? "Chọn chứng chỉ" : ExperienceCertificateSelection.title(nickname: certificate?.displayNickname, profileName: profileName))
                        .font(.headline).lineLimit(2)
                    Text(certificate.map(certificateStatus) ?? "Thêm chứng chỉ để bắt đầu ký IPA.")
                        .font(.caption).foregroundStyle(certificate?.revoked == true ? Color.red : Color.secondary)
                    if certificate != nil { Text("Được chọn mặc định khi mở màn hình ký").font(.caption2).foregroundStyle(.secondary) }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            }.experienceCard()
        }.buttonStyle(.plain)
    }
    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            Button { activeTab = TabEnum.sources.rawValue } label: {
                quickTile("Kho IPA", detail: "\(repositories.count) nguồn của bạn", icon: "externaldrive.fill", color: CSignTheme.cyan)
            }.buttonStyle(.plain)
            NavigationLink { FavoritesView() } label: {
                quickTile("Yêu thích", detail: newFavorites > 0 ? "\(newFavorites) app có bản mới" : "\(experience.state.favorites.count) app đã lưu", icon: "heart.fill", color: CSignTheme.pink)
            }.buttonStyle(.plain)
        }
    }
    private func quickTile(_ title: String, detail: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon).font(.title2).foregroundStyle(color)
            Text(title).font(.headline)
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, alignment: .leading).experienceCard()
    }
    private var playingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ExperienceSectionHeading(title: "Game đang chơi", subtitle: "Danh sách bạn tự chọn • giữ game yêu thích gần hơn", symbol: "gamecontroller.fill")
                NavigationLink { PlayingGamesView() } label: { Image(systemName: "arrow.up.right").font(.headline).padding(8) }
            }
            if experience.state.playingGames.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Góc chơi game đang chờ bạn").font(.headline)
                    Text("Bấm Đang chơi trên thẻ game ở phía trên để ghim vào đây. Bạn luôn có thể bỏ ghim.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity, alignment: .leading).experienceCard()
            } else {
                PlayingGamesStrip()
            }
        }
    }
    private var badgesSection: some View {
        NavigationLink { MissionsView() } label: {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    ExperienceSectionHeading(title: "Tủ huy hiệu của bạn", subtitle: "Mỗi bước một huy hiệu • mở khóa rồi đeo cho linh vật", symbol: "seal.fill")
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 68))], spacing: 12) {
                    ForEach(ExperienceMission.allCases, id: \.rawValue) { mission in
                        ExperienceBadge(mission: mission, unlocked: experience.state.completedMissions.contains(mission), equipped: experience.state.equippedBadge == mission)
                    }
                }
            }.experienceCard()
        }.buttonStyle(.plain).accessibilityIdentifier("experience.badges")
    }
    private var toolsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ExperienceSectionHeading(title: "Sẵn sàng cho IPA tiếp theo", subtitle: "Nhập, ký và theo dõi trong một chạm", symbol: "wand.and.stars")
            VStack(spacing: 0) {
                Button { activeTab = TabEnum.library.rawValue } label: { toolRow("Thư viện IPA", detail: "\(importedApps.count) đã nhập • \(signedApps.count) đã ký", icon: "square.grid.2x2") }
                Divider().padding(.vertical, 12)
                Button { activeTab = TabEnum.history.rawValue } label: { toolRow("Lịch sử ký & tải", detail: downloads.downloads.isEmpty ? "Xem lại các tác vụ của bạn" : "\(downloads.downloads.count) mục trong danh sách tải", icon: "clock.arrow.circlepath") }
                Divider().padding(.vertical, 12)
                Button { Task { await refresh(checkUpdates: true) } } label: {
                    HStack {
                        toolRow("Làm mới nguồn & ứng dụng", detail: updates.updates.isEmpty ? "Đối chiếu phiên bản mới" : "\(updates.updates.count) cập nhật trong thư viện", icon: "arrow.clockwise")
                        if checking || updates.isChecking { ProgressView() }
                    }
                }.disabled(checking || updates.isChecking)
                Divider().padding(.vertical, 12)
                Button { showingGuide = true } label: { toolRow("Hướng dẫn sử dụng", detail: "Cùng bắt đầu với CSign", icon: "book.closed") }
            }.buttonStyle(.plain).experienceCard()
        }
    }
    private func toolRow(_ title: String, detail: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.title3).foregroundStyle(CSignTheme.cyan).frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }.contentShape(Rectangle())
    }
    private var certificateSheet: some View {
        NavigationStack {
            CertificatesView().navigationTitle("Chứng chỉ")
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Đóng") { showingCertificate = false } } }
        }
    }
    private func certificateStatus(_ certificate: CertificatePair) -> String {
        if certificate.revoked { return "Đã được đánh dấu thu hồi • nên kiểm tra lại" }
        guard let expiration = certificate.expiration else { return "Chưa có thông tin hết hạn" }
        if expiration <= Date() { return "Đã hết hạn • " + expiration.formatted(date: .abbreviated, time: .omitted) }
        let days = max(0, Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0)
        return "Còn \(days) ngày • " + expiration.formatted(date: .abbreviated, time: .omitted)
    }
    private func reconcileCertificate() {
        guard let index = ExperienceCertificateSelection.index(identifiers: certificateIDs, selectedID: selectedCertificateID, legacyIndex: selectedCertificate) else {
            selectedCertificateID = ""; profileName = nil; return
        }
        if selectedCertificate != index { selectedCertificate = index }
        if selectedCertificateID != certificateIDs[index] { selectedCertificateID = certificateIDs[index] }
        loadProfileName()
        recordExistingProgress()
    }
    private func loadProfileName() {
        profileName = certificate.flatMap { Storage.shared.getProvisionFileDecoded(for: $0)?.Name }
    }
    private func recordExistingProgress() {
        if !certificates.isEmpty { experience.complete(.certificate) }
        experience.recordExistingSignatures(Array(signedApps))
    }
    private func refresh(checkUpdates: Bool) async {
        guard !checking else { return }
        checking = true
        defer { checking = false }
        await sources.fetchSources(repositories, refresh: checkUpdates)
        await experience.refreshWeekly()
        if checkUpdates {
            let local: [AppInfoPresentable] = signedApps.map { $0 as AppInfoPresentable } + importedApps.map { $0 as AppInfoPresentable }
            await updates.checkForUpdates(sources: Array(repositories), localApps: local)
        }
    }
}
