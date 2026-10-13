import SwiftUI

struct CuratedShelf: View {
    var games = false
    @ObservedObject private var experience = ExperienceStore.shared
    @ObservedObject private var sources = SourcesViewModel.shared
    @AppStorage("CSign.activeTab") private var activeTab = TabEnum.today.rawValue
    private var items: [DiscoveryApp] { games ? experience.suggestedGames : experience.suggestedApps }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                ExperienceSectionHeading(title: games ? "Game cho cuộc vui mới" : "App đáng thử", subtitle: "\(items.count) \(games ? "game" : "ứng dụng") • Vuốt ngang để khám phá", symbol: games ? "gamecontroller.fill" : "sparkles")
                Button {
                    experience.updateSuggestions(sources.sources, shuffle: true, gamesOnly: games)
                } label: {
                    Label("Đổi", systemImage: "shuffle").font(.caption.weight(.semibold)).frame(minHeight: 32)
                }.buttonStyle(.bordered).disabled(items.isEmpty)
                    .accessibilityLabel(games ? "Đổi gợi ý game" : "Đổi gợi ý app")
                    .accessibilityIdentifier(games ? "discovery.shuffle.games" : "discovery.shuffle.apps")
            }
            if !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(items) { item in
                            DiscoveryFeatureCard(item: item, caption: experience.suggestionCaption(item), game: games)
                        }
                    }.padding(.vertical, 2)
                }.accessibilityIdentifier(games ? "discovery.cards.games" : "discovery.cards.apps")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Label(sources.isFinished ? "Nguồn chưa cung cấp các lựa chọn này" : "Đang mở kho ứng dụng…", systemImage: games ? "gamecontroller" : "square.stack.3d.up")
                        .font(.headline)
                    Text("Kéo xuống để làm mới nguồn hoặc mở kho để khám phá ứng dụng.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Button("Mở kho IPA") { activeTab = TabEnum.sources.rawValue }.buttonStyle(.bordered)
                }.frame(maxWidth: .infinity, alignment: .leading).experienceCard()
            }
        }.accessibilityElement(children: .contain)
            .accessibilityIdentifier(games ? "discovery.shelf.games" : "discovery.shelf.apps")
    }
}

struct DiscoveryFeatureCard: View {
    let item: DiscoveryApp
    let caption: String
    var game = false
    @ObservedObject private var experience = ExperienceStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("CSign.playfulAnimations") private var animations = true
    private var color: Color { game ? Color.indigo : CSignTheme.cyan }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            NavigationLink {
                SourceAppsDetailView(sourceURL: item.sourceURL, source: item.repository, app: item.app)
            } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        ExperienceAppIcon(url: item.app.iconURL, size: 68)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 6) {
                            Image(systemName: game ? "gamecontroller.fill" : "sparkles").font(.title2).foregroundStyle(color)
                            Text(item.app.currentVersion.map { "v\($0)" } ?? "IPA")
                                .font(.caption2.weight(.semibold)).lineLimit(1).foregroundStyle(.secondary)
                        }
                    }
                    Text(item.app.currentName).font(.title3.bold()).lineLimit(2)
                        .frame(height: 48, alignment: .topLeading)
                    Text(caption).font(.subheadline).foregroundStyle(.secondary).lineLimit(3)
                        .frame(height: 56, alignment: .topLeading)
                    HStack(spacing: 5) {
                        Image(systemName: "externaldrive")
                        Text(item.repository.name ?? "Nguồn IPA").lineLimit(1)
                    }.font(.caption2).foregroundStyle(.secondary)
                    HStack {
                        Text("Xem & tải IPA").font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill").font(.title3)
                    }.foregroundStyle(color)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("discovery.details." + item.identifier)
            Divider()
            HStack(spacing: 8) {
                Button {
                    withAnimation(animations && !reduceMotion ? .spring(response: 0.3) : nil) { experience.toggle(item) }
                } label: {
                    Label(experience.isFavorite(item) ? "Đã lưu" : "Lưu", systemImage: experience.isFavorite(item) ? "heart.fill" : "heart")
                        .font(.caption.weight(.semibold)).frame(minHeight: 36)
                }.foregroundStyle(CSignTheme.pink).buttonStyle(.bordered).accessibilityIdentifier("discovery.favorite." + item.identifier)
                if game {
                    Button {
                        withAnimation(animations && !reduceMotion ? .spring(response: 0.3) : nil) { experience.togglePlaying(item) }
                    } label: {
                        Label(experience.isPlaying(item) ? "Đã ghim" : "Đang chơi", systemImage: experience.isPlaying(item) ? "checkmark" : "gamecontroller")
                            .font(.caption.weight(.semibold)).frame(minHeight: 36)
                    }.tint(.indigo).buttonStyle(.bordered).accessibilityIdentifier("discovery.playing." + item.identifier)
                } else if experience.hasUpdate(item) {
                    Label("Bản mới", systemImage: "sparkles").font(.caption).foregroundStyle(CSignTheme.pink)
                }
            }
        }.padding(18).frame(width: 270, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: 3).fill(color.opacity(0.7)).frame(width: 48, height: 4).padding(.top, 0)
        }
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(color.opacity(0.12), lineWidth: 1))
    }
}

struct PlayingGamesStrip: View {
    @ObservedObject private var experience = ExperienceStore.shared
    @ObservedObject private var sources = SourcesViewModel.shared
    private var catalog: [String: DiscoveryApp] {
        Dictionary(experience.catalog(sources.sources, matching: Set(experience.state.playingGames.map(\.id))).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
    var body: some View {
        let items = catalog
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(experience.state.playingGames) { game in
                    Group {
                        if let item = items[game.id] {
                            NavigationLink {
                                SourceAppsDetailView(sourceURL: item.sourceURL, source: item.repository, app: item.app)
                            } label: { savedCard(game) }
                        } else { savedCard(game) }
                    }.buttonStyle(.plain)
                    .contextMenu { Button("Bỏ khỏi Đang chơi", role: .destructive) { experience.removePlaying(game) } }
                }
            }
        }
    }
    private func savedCard(_ game: FavoriteApp) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ExperienceAppIcon(url: game.iconURL, size: 56)
            Text(game.name).font(.subheadline.weight(.semibold)).lineLimit(2)
            Label("Đã ghim", systemImage: "pin.fill").font(.caption2).foregroundStyle(.indigo)
        }.frame(width: 130, alignment: .leading).experienceCard()
    }
}

struct PlayingGamesView: View {
    @ObservedObject private var experience = ExperienceStore.shared
    @ObservedObject private var sources = SourcesViewModel.shared
    @FetchRequest(entity: AltSource.entity(), sortDescriptors: []) private var repositories: FetchedResults<AltSource>
    private var catalog: [String: DiscoveryApp] {
        Dictionary(experience.catalog(sources.sources, matching: Set(experience.state.playingGames.map(\.id))).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
    var body: some View {
        List {
            Section {
                if experience.state.playingGames.isEmpty {
                    Label("Ghim game từ Trang Chủ để tạo góc chơi của bạn.", systemImage: "gamecontroller.fill")
                        .padding(.vertical, 16)
                } else {
                    let items = catalog
                    ForEach(experience.state.playingGames) { game in
                        Group {
                            if let item = items[game.id] {
                                NavigationLink { SourceAppsDetailView(sourceURL: item.sourceURL, source: item.repository, app: item.app) } label: { DiscoveryAppRow(item: item) }
                            } else {
                                HStack {
                                    ExperienceAppIcon(url: game.iconURL)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(game.name).font(.headline)
                                        Text("Nguồn chưa tải hoặc game tạm không có trong nguồn").font(.caption).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }.swipeActions { Button("Bỏ ghim", role: .destructive) { experience.removePlaying(game) } }
                    }
                }
            } footer: {
                Text("Danh sách do bạn tự lưu. CSign không đọc thời gian chơi hoặc tự mở game đã cài.")
            }
        }.navigationTitle("Game đang chơi")
        .task { await sources.fetchSources(repositories) }
        .refreshable { await sources.fetchSources(repositories, refresh: true) }
    }
}
