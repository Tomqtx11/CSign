import SwiftUI
import NimbleViews

struct TodayView: View {
    @ObservedObject private var experience = ExperienceStore.shared
    @ObservedObject private var sources = SourcesViewModel.shared
    @ObservedObject private var downloads = DownloadManager.shared
    @ObservedObject private var updates = UpdateManager.shared
    @AppStorage("csign.selectedCert") private var selectedCertificate = 0
    @FetchRequest(entity: AltSource.entity(), sortDescriptors: []) private var repositories: FetchedResults<AltSource>
    @FetchRequest(entity: CertificatePair.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)])
    private var certificates: FetchedResults<CertificatePair>
    @FetchRequest(entity: Signed.entity(), sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)])
    private var signedApps: FetchedResults<Signed>
    @FetchRequest(entity: Imported.entity(), sortDescriptors: []) private var importedApps: FetchedResults<Imported>
    @Environment(\.scenePhase) private var scenePhase
    @State private var checking = false
    @AppStorage("CSign.activeTab") private var activeTab = TabEnum.today.rawValue
    @State private var showingCertificate = false
    @State private var showingGuide = false
    private var greeting: String {
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return "Chào buổi sáng"
        case 12..<18: return "Chào buổi chiều"
        default: return "Chào buổi tối"
        }
    }
    private var certificate: CertificatePair? {
        certificates.indices.contains(selectedCertificate) ? certificates[selectedCertificate] : nil
    }
    private var newFavorites: Int { experience.catalog(sources.sources, matching: Set(experience.state.favorites.map(\.id))).filter { experience.hasUpdate($0) }.count }
    var body: some View {
        NBNavigationView("Hôm nay") {
            List {
                Section {
                    HStack(spacing: 16) {
                        CSignMascotView(mood: downloads.downloads.isEmpty ? .idle : .downloading)
                            .scaleEffect(1.25).frame(width: 60, height: 65)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(greeting).font(.title2.bold())
                            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "CSign")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Text("Một ứng dụng mới, một trải nghiệm mới.").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 9)
                }
                Section("Chứng chỉ đang dùng") {
                    Button { showingCertificate = true } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Label(certificate?.displayNickname ?? "Chưa chọn chứng chỉ", systemImage: "checkmark.seal")
                                .font(.headline)
                            if let certificate {
                                Text(certificateStatus(certificate)).font(.subheadline)
                                    .foregroundStyle(certificate.revoked ? Color.red : Color.secondary)
                            } else {
                                Text("Chọn chứng chỉ trong Cài đặt để chuẩn bị ký IPA.").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 5)
                    }
                }
                Section("Lối tắt của bạn") {
                    NavigationLink { FavoritesView() } label: {
                        Label("Yêu thích · \(experience.state.favorites.count) ứng dụng", systemImage: "heart.fill")
                    }
                    if newFavorites > 0 {
                        NavigationLink { FavoritesView() } label: {
                            Label("\(newFavorites) ứng dụng yêu thích có bản mới", systemImage: "sparkles").foregroundStyle(CSignTheme.pink)
                        }
                    }
                    NavigationLink { MissionsView() } label: {
                        Label("Nhiệm vụ · \(experience.state.completedMissions.count)/4", systemImage: "seal")
                    }
                    Button { activeTab = TabEnum.history.rawValue } label: {
                        Label(downloads.downloads.isEmpty ? "Lịch sử ký và tải xuống" : "Tiếp tục xem \(downloads.downloads.count) tác vụ tải", systemImage: "clock.arrow.circlepath")
                    }
                    Button { activeTab = TabEnum.library.rawValue } label: { Label("Mở thư viện IPA", systemImage: "square.grid.2x2") }
                    Button { showingGuide = true } label: { Label("Hướng dẫn sử dụng", systemImage: "book.closed") }
                }
                Section("Cập nhật ứng dụng") {
                    Button {
                        Task { await refresh(checkUpdates: true) }
                    } label: {
                        HStack {
                            Label("Kiểm tra nguồn và phiên bản mới", systemImage: "arrow.clockwise")
                            Spacer()
                            if checking || updates.isChecking { ProgressView() }
                        }
                    }.disabled(checking || updates.isChecking)
                    if let last = updates.lastCheckedDate {
                        Text("Đã kiểm tra: " + last.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    }
                    if !updates.updates.isEmpty {
                        Text("\(updates.updates.count) bản cập nhật cho các IPA trong thư viện. Mở thư viện để xem và tải.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                WeeklyPicksSection()
            }
            .sheet(isPresented: $showingCertificate) {
                NavigationStack {
                    CertificatesView().navigationTitle("Chứng chỉ")
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Đóng") { showingCertificate = false } } }
                }
            }
            .sheet(isPresented: $showingGuide) { ExperienceGuideSheet() }
            .refreshable { await refresh(checkUpdates: true) }
            .task {
                recordExistingProgress()
                await refresh(checkUpdates: false)
            }
            .onChange(of: certificates.count) { _ in recordExistingProgress() }
            .onChange(of: signedApps.count) { _ in recordExistingProgress() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { recordExistingProgress() }
            }
        }
    }
    private func certificateStatus(_ certificate: CertificatePair) -> String {
        if certificate.revoked { return "Chứng chỉ được đánh dấu đã thu hồi" }
        guard let expiration = certificate.expiration else { return "Chưa có thông tin hết hạn" }
        if expiration <= Date() { return "Đã hết hạn · " + expiration.formatted(date: .abbreviated, time: .omitted) }
        let days = max(0, Calendar.current.dateComponents([.day], from: Date(), to: expiration).day ?? 0)
        return "Còn \(days) ngày · " + expiration.formatted(date: .abbreviated, time: .omitted)
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
