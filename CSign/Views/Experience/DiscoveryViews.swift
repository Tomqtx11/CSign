import SwiftUI
import NukeUI

struct DiscoveryAppRow: View {
    let item: DiscoveryApp
    @ObservedObject private var experience = ExperienceStore.shared
    var body: some View {
        HStack(spacing: 12) {
            ExperienceAppIcon(url: item.app.iconURL)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.app.currentName).font(.headline).lineLimit(1)
                Text(item.repository.name ?? "Nguồn IPA").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                if experience.hasUpdate(item) {
                    Label("Có bản mới", systemImage: "sparkles").font(.caption).foregroundStyle(CSignTheme.pink)
                } else if let version = item.app.currentVersion {
                    Text("v\(version)").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            if experience.isFavorite(item) {
                Image(systemName: "heart.fill").foregroundStyle(CSignTheme.pink).accessibilityLabel("Đã yêu thích")
            }
        }
        .padding(.vertical, 3)
    }
}

struct ExperienceAppIcon: View {
    let url: URL?
    var body: some View {
        LazyImage(url: url) { state in
            if let image = state.image {
                image.resizable().scaledToFit()
            } else {
                Image(systemName: "app.fill").resizable().scaledToFit().foregroundStyle(CSignTheme.cyan).padding(9)
            }
        }
        .frame(width: 48, height: 48)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .accessibilityHidden(true)
    }
}

struct WeeklyPicksSection: View {
    @ObservedObject private var experience = ExperienceStore.shared
    @ObservedObject private var sources = SourcesViewModel.shared
    private var catalog: [String: DiscoveryApp] {
        Dictionary(experience.catalog(sources.sources).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
    var body: some View {
        Section {
            if let weekly = experience.weekly {
                let items = catalog
                ForEach(weekly.picks) { pick in
                    if let item = items[pick.id] {
                        NavigationLink {
                            SourceAppsDetailView(sourceURL: item.sourceURL, source: item.repository, app: item.app)
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                DiscoveryAppRow(item: item)
                                Text(pick.caption).font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 5)
                        }
                    }
                }
                if !weekly.picks.contains(where: { items[$0.id] != nil }) {
                    Text(sources.isFinished ? "Các lựa chọn sẽ hiện khi nguồn chứa ứng dụng được tải thành công." : "Đang tải các lựa chọn từ nguồn…")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
        } header: {
            Label(experience.weekly?.title ?? "App đáng thử tuần này", systemImage: "sparkles")
        } footer: {
            if let weekly = experience.weekly {
                Text(weekly.edition + " · CSign tuyển chọn")
            }
        }
    }
}

struct FavoritesView: View {
    @ObservedObject private var experience = ExperienceStore.shared
    @ObservedObject private var sources = SourcesViewModel.shared
    @State private var search = ""
    @FetchRequest(entity: AltSource.entity(), sortDescriptors: []) private var repositories: FetchedResults<AltSource>
    private var catalog: [String: DiscoveryApp] {
        Dictionary(experience.catalog(sources.sources).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
    private var favorites: [FavoriteApp] {
        experience.state.favorites.filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        List {
            if experience.state.favorites.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart.circle").font(.system(size: 48)).foregroundStyle(CSignTheme.pink)
                    Text("Bộ sưu tập của bạn bắt đầu ở đây").font(.headline)
                    Text("Mở một ứng dụng trong IPA Mod và bấm tim để lưu. Khi làm mới nguồn, CSign sẽ đối chiếu phiên bản của các ứng dụng bạn theo dõi.")
                        .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.vertical, 28)
            } else if favorites.isEmpty {
                Text("Không tìm thấy ứng dụng yêu thích phù hợp.").foregroundStyle(.secondary)
            } else {
                let items = catalog
                ForEach(favorites) { favorite in
                    Group {
                        if let item = items[favorite.id] {
                            NavigationLink {
                                SourceAppsDetailView(sourceURL: item.sourceURL, source: item.repository, app: item.app)
                            } label: { DiscoveryAppRow(item: item) }
                        } else {
                            HStack(spacing: 12) {
                                ExperienceAppIcon(url: favorite.iconURL)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(favorite.name).font(.headline)
                                    Text("Nguồn chưa tải hoặc ứng dụng tạm không có trong nguồn")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .swipeActions {
                        Button("Bỏ yêu thích", role: .destructive) { experience.remove(favorite) }
                    }
                    .contextMenu {
                        Button("Bỏ yêu thích", systemImage: "heart.slash", role: .destructive) { experience.remove(favorite) }
                    }
                }
            }
        }
        .navigationTitle("Yêu thích")
        .searchable(text: $search)
        .task { await sources.fetchSources(repositories) }
        .refreshable { await sources.fetchSources(repositories, refresh: true) }
    }
}

struct MissionsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("CSign.activeTab") private var activeTab = TabEnum.today.rawValue
    @State private var showingCertificates = false
    @ObservedObject private var experience = ExperienceStore.shared
    @AppStorage("CSign.userTintColor") private var tint = CSignTheme.defaultTint
    @FetchRequest(entity: CertificatePair.entity(), sortDescriptors: []) private var certificates: FetchedResults<CertificatePair>
    @FetchRequest(entity: Signed.entity(), sortDescriptors: []) private var signedApps: FetchedResults<Signed>
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    CSignMascotView(mood: experience.state.rewardUnlocked ? .celebrating : .idle)
                        .scaleEffect(1.5).frame(height: 80)
                    Text(experience.state.rewardUnlocked ? "Nhà khám phá CSign" : "Bắt đầu hành trình CSign").font(.title3.bold())
                    Text("\(experience.state.completedMissions.count)/4 nhiệm vụ hoàn thành").foregroundStyle(.secondary)
                    ProgressView(value: Double(experience.state.completedMissions.count), total: 4).tint(CSignTheme.cyan)
                }.frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            Section {
                ForEach(ExperienceMission.allCases, id: \.rawValue) { mission in
                    HStack(spacing: 12) {
                        Image(systemName: mission.symbol).foregroundStyle(CSignTheme.cyan).frame(width: 24)
                        Text(mission.title)
                        Spacer()
                        Image(systemName: experience.state.completedMissions.contains(mission) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(experience.state.completedMissions.contains(mission) ? CSignTheme.cyan : Color.secondary)
                    }.padding(.vertical, 5)
                }
            } header: { Text("Nhiệm vụ làm quen") } footer: {
                Text("Tiến độ được ghi nhận từ thao tác thật và lưu trên thiết bị. Các mốc đã hoàn thành vẫn được giữ khi bạn dọn thư viện.")
            }
            Section {
                Label("Huy hiệu Nhà khám phá CSign", systemImage: "seal.fill")
                    .foregroundStyle(experience.state.rewardUnlocked ? CSignTheme.pink : Color.secondary)
                Button {
                    tint = "#8B5CF6"
                } label: {
                    Label(tint == "#8B5CF6" ? "Đang dùng màu Aurora" : "Mở khóa màu Aurora", systemImage: "paintpalette.fill")
                }.disabled(!experience.state.rewardUnlocked)
            } header: { Text("Phần thưởng") } footer: {
                Text("Hoàn thành 4 nhiệm vụ để nhận huy hiệu và dùng màu Aurora. Bạn có thể đổi màu lại trong Giao diện.")
            }
            Section("Bắt đầu từ đây") {
                Button("Khám phá kho IPA") { activeTab = TabEnum.sources.rawValue; dismiss() }
                NavigationLink("Xem bộ sưu tập yêu thích") { FavoritesView() }
                Button("Quản lý chứng chỉ") { showingCertificates = true }
                Button("Mở thư viện để ký IPA") { activeTab = TabEnum.library.rawValue; dismiss() }
            }
        }
        .navigationTitle("Nhiệm vụ & huy hiệu")
        .sheet(isPresented: $showingCertificates) {
            NavigationStack {
                CertificatesView().navigationTitle("Chứng chỉ")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Đóng") { showingCertificates = false } } }
            }
        }
        .onAppear {
            if !certificates.isEmpty { experience.complete(.certificate) }
            if !signedApps.isEmpty { experience.complete(.signed) }
        }
    }
}
