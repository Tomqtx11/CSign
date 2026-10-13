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
    private var isRefreshingWeekly = false

    private init() {
        state = UserDefaults.standard.data(forKey: Self.stateKey)
            .flatMap { try? JSONDecoder().decode(ExperienceState.self, from: $0) } ?? ExperienceState()
        let cached = UserDefaults.standard.data(forKey: Self.weeklyKey)
            .flatMap { try? JSONDecoder().decode(WeeklySelection.self, from: $0) }
        if let cached, cached.isValid { weekly = cached }
        else if let url = Bundle.main.url(forResource: "weekly-picks", withExtension: "json"),
                let data = try? Data(contentsOf: url),
                let bundled = try? JSONDecoder().decode(WeeklySelection.self, from: data), bundled.isValid {
            weekly = bundled
        }
    }

    func isFavorite(_ item: DiscoveryApp) -> Bool { state.favorites.contains { $0.id == item.id } }
    func hasUpdate(_ item: DiscoveryApp) -> Bool {
        guard let saved = state.favorites.first(where: { $0.id == item.id }) else { return false }
        return ExperienceState.hasNewVersion(item.app.currentVersion, since: saved.seenVersion)
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

    /// Refresh only on demand; invalid/unavailable network content keeps the cached selection.
    func refreshWeekly() async {
        guard !isRefreshingWeekly,
              let url = URL(string: "https://raw.githubusercontent.com/Tomqtx11/CSign/main/CSign/Resources/weekly-picks.json") else { return }
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
