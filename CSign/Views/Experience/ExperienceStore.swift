import SwiftUI
import AltSourceKit

struct DiscoveryApp: Identifiable {
    let sourceURL: URL
    let repository: ASRepository
    let app: ASRepository.App
    var identifier: String { app.id ?? app.currentName }
    var id: String { ExperienceState.favoriteKey(sourceURL: sourceURL, appIdentifier: identifier) }
    var favorite: FavoriteApp {
        FavoriteApp(sourceURL: sourceURL, appIdentifier: identifier, name: app.currentName,
                    iconURL: app.iconURL, seenVersion: app.currentVersion, savedAt: Date())
    }
}

@MainActor
final class ExperienceStore: ObservableObject {
    static let shared = ExperienceStore()
    private static let stateKey = "CSign.experience.v1"
    private static let weeklyKey = "CSign.weeklySelection.v1"
    @Published private(set) var state: ExperienceState
    @Published private(set) var weekly: WeeklySelection?
    @Published private(set) var suggestedApps: [DiscoveryApp] = []
    @Published private(set) var suggestedGames: [DiscoveryApp] = []
    private var isRefreshingWeekly = false

    private init() {
        state = UserDefaults.standard.data(forKey: Self.stateKey)
            .flatMap { try? JSONDecoder().decode(ExperienceState.self, from: $0) } ?? ExperienceState()
        let cached = UserDefaults.standard.data(forKey: Self.weeklyKey)
            .flatMap { try? JSONDecoder().decode(WeeklySelection.self, from: $0) }
        if let url = Bundle.main.url(forResource: "weekly-picks", withExtension: "json"),
                let data = try? Data(contentsOf: url),
                let bundled = try? JSONDecoder().decode(WeeklySelection.self, from: data), bundled.isValid {
            weekly = (cached?.isValid == true && cached?.edition == bundled.edition) ? cached : bundled
        } else if let cached, cached.isValid { weekly = cached }
    }

    func isFavorite(_ item: DiscoveryApp) -> Bool { state.favorites.contains { $0.id == item.id } }
    func hasUpdate(_ item: DiscoveryApp) -> Bool {
        guard let saved = state.favorites.first(where: { $0.id == item.id }) else { return false }
        return ExperienceState.hasNewVersion(item.app.currentVersion, since: saved.seenVersion)
    }
    func isPlaying(_ item: DiscoveryApp) -> Bool { state.playingGames.contains { $0.id == item.id } }
    func togglePlaying(_ item: DiscoveryApp) { state.togglePlaying(item.favorite); save() }
    func removePlaying(_ app: FavoriteApp) { state.playingGames.removeAll { $0.id == app.id }; save() }
    func equip(_ badge: ExperienceMission?) { state.equip(badge); save() }
    func isGame(_ item: DiscoveryApp) -> Bool {
        item.app.inferredCategory == "Games" || (weekly?.picks.contains { $0.id == item.id && $0.isGame } ?? false)
    }
    func toggle(_ item: DiscoveryApp) { state.toggle(item.favorite); save() }
    func remove(_ favorite: FavoriteApp) { state.favorites.removeAll { $0.id == favorite.id }; save() }
    func markSeen(_ item: DiscoveryApp) {
        let before = state
        state.markSeen(key: item.id, version: item.app.currentVersion)
        if state != before { save() }
    }
    func complete(_ mission: ExperienceMission) {
        guard !state.completedMissions.contains(mission) else { return }
        state.completedMissions.insert(mission); save()
    }
    private func save() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.stateKey)
    }

    func recordExistingSignatures(_ apps: [Signed]) {
        guard !state.completedMissions.contains(.signed) else { return }
        for app in apps {
            if let uuid = app.uuid,
               let data = UserDefaults.standard.data(forKey: "csign_options_\(uuid)"),
               let options = try? JSONDecoder().decode(Options.self, from: data) {
                if options.signingOption != .onlyModify { complete(.signed); return }
            } else if app.certificate != nil {
                complete(.signed); return
            }
        }
    }

    func catalog(_ repositories: [AltSource: ASRepository], matching keys: Set<String>) -> [DiscoveryApp] {
        guard !keys.isEmpty else { return [] }
        var result: [DiscoveryApp] = []
        for (source, repository) in repositories {
            guard let url = source.sourceURL else { continue }
            let prefix = ExperienceState.favoriteKey(sourceURL: url, appIdentifier: "")
            guard keys.contains(where: { $0.hasPrefix(prefix) }) else { continue }
            for app in repository.apps {
                let key = prefix + (app.id ?? app.currentName)
                if keys.contains(key) {
                    result.append(DiscoveryApp(sourceURL: url, repository: repository, app: app))
                }
            }
        }
        return result.sorted { $0.id < $1.id }
    }

    /// Suggestions change on entry/refresh or explicit shuffle, never on favorite/playing updates.
    func updateSuggestions(_ repositories: [AltSource: ASRepository], shuffle: Bool = false, gamesOnly: Bool? = nil) {
        guard !repositories.isEmpty else { return } // Keep the current cards while sources refresh.
        var generator = SystemRandomNumberGenerator()
        let oldApps = suggestedApps.map { $0.identifier.lowercased() }
        let oldGames = suggestedGames.map { $0.identifier.lowercased() }
        var apps = ExperienceRecommendationSampler<DiscoveryApp>(previousKeys: Set(oldApps))
        var games = ExperienceRecommendationSampler<DiscoveryApp>(previousKeys: Set(oldGames))
        var retainedApps: [String: DiscoveryApp] = [:]
        var retainedGames: [String: DiscoveryApp] = [:]
        let oldSources = Dictionary((suggestedApps + suggestedGames).map { ($0.identifier.lowercased(), $0.id) }, uniquingKeysWith: { first, _ in first })
        let gameOverrides = Set(weekly?.picks.filter(\.isGame).map(\.id) ?? [])
        for (source, repository) in repositories.sorted(by: { ($0.key.sourceURL?.absoluteString ?? "") < ($1.key.sourceURL?.absoluteString ?? "") }) {
            guard let url = source.sourceURL else { continue }
            let prefix = ExperienceState.favoriteKey(sourceURL: url, appIdentifier: "")
            for app in repository.apps {
                guard app.currentDownloadUrl != nil else { continue }
                let identifier = app.id ?? app.currentName
                let key = identifier.lowercased()
                let item = DiscoveryApp(sourceURL: url, repository: repository, app: app)
                let category = app.inferredCategory.lowercased()
                let isGame = category == "games" || category == "game" || gameOverrides.contains(prefix + identifier)
                if isGame {
                    games.consider(item, key: key, using: &generator)
                    if oldSources[key] == item.id { retainedGames[key] = item }
                } else {
                    apps.consider(item, key: key, using: &generator)
                    if oldSources[key] == item.id { retainedApps[key] = item }
                }
            }
        }
        if gamesOnly != true {
            if !shuffle, retainedApps.count == min(5, apps.availableCount), !retainedApps.isEmpty {
                suggestedApps = oldApps.compactMap { retainedApps[$0] }
            } else { suggestedApps = apps.selection(using: &generator) }
        }
        if gamesOnly != false {
            if !shuffle, retainedGames.count == min(5, games.availableCount), !retainedGames.isEmpty {
                suggestedGames = oldGames.compactMap { retainedGames[$0] }
            } else { suggestedGames = games.selection(using: &generator) }
        }
    }

    func suggestionCaption(_ item: DiscoveryApp) -> String {
        if let caption = weekly?.picks.first(where: { $0.id == item.id })?.caption { return caption }
        if let description = item.app.currentDescription, !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(description.split(whereSeparator: \.isNewline).joined(separator: " ").prefix(160))
        }
        return isGame(item) ? "Khám phá game mới và ghim vào góc Đang chơi của bạn." : "Một lựa chọn từ kho IPA của bạn để khám phá và trải nghiệm."
    }

    /// Refresh only on demand; invalid/unavailable network content keeps the cached selection.
    func refreshWeekly() async {
        guard !isRefreshingWeekly,
              let url = URL(string: "https://raw.githubusercontent.com/Tomqtx11/CSign/feature/experience-20261013/CSign/Resources/weekly-picks.json") else { return }
        isRefreshingWeekly = true
        defer { isRefreshingWeekly = false }
        var request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData, timeoutInterval: 15)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count < 128_000,
                  let selection = try? JSONDecoder().decode(WeeklySelection.self, from: data), selection.isValid else { return }
            weekly = selection
            UserDefaults.standard.set(data, forKey: Self.weeklyKey)
        } catch { /* The bundled/cached selection remains usable offline. */ }
    }
}
