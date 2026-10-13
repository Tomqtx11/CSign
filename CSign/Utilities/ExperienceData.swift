import Foundation

/// Independent local preferences: never changes the IPA/certificate Core Data store.
struct FavoriteApp: Codable, Identifiable, Equatable {
    let sourceURL: URL
    let appIdentifier: String
    var name: String
    var iconURL: URL?
    var seenVersion: String?
    let savedAt: Date
    var id: String { ExperienceState.favoriteKey(sourceURL: sourceURL, appIdentifier: appIdentifier) }
}

enum ExperienceMission: String, Codable, CaseIterable {
    case explored, favorite, certificate, signed
    var title: String {
        switch self {
        case .explored: return "Khám phá một ứng dụng"
        case .favorite: return "Lưu ứng dụng yêu thích đầu tiên"
        case .certificate: return "Thêm chứng chỉ vào CSign"
        case .signed: return "Ký thành công IPA đầu tiên"
        }
    }
    var badgeName: String {
        switch self {
        case .explored: return "Tiên phong"
        case .favorite: return "Sưu tầm"
        case .certificate: return "Sẵn sàng"
        case .signed: return "Phù thủy IPA"
        }
    }
    var symbol: String {
        switch self {
        case .explored: return "safari"
        case .favorite: return "heart"
        case .certificate: return "checkmark.seal"
        case .signed: return "signature"
        }
    }
}

struct ExperienceState: Codable, Equatable {
    var favorites: [FavoriteApp] = []
    var completedMissions: Set<ExperienceMission> = []
    var playingGames: [FavoriteApp] = []
    var equippedBadge: ExperienceMission?
    // Old preview preferences must decode without losing favorites or earned badges.
    enum CodingKeys: String, CodingKey { case favorites, completedMissions, playingGames, equippedBadge }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        favorites = try c.decodeIfPresent([FavoriteApp].self, forKey: .favorites) ?? []
        completedMissions = try c.decodeIfPresent(Set<ExperienceMission>.self, forKey: .completedMissions) ?? []
        playingGames = try c.decodeIfPresent([FavoriteApp].self, forKey: .playingGames) ?? []
        equippedBadge = try c.decodeIfPresent(ExperienceMission.self, forKey: .equippedBadge)
        if let badge = equippedBadge, !completedMissions.contains(badge) { equippedBadge = nil }
    }
    mutating func togglePlaying(_ app: FavoriteApp) {
        if playingGames.contains(where: { $0.id == app.id }) { playingGames.removeAll { $0.id == app.id } }
        else { playingGames.insert(app, at: 0) }
    }
    mutating func equip(_ badge: ExperienceMission?) {
        guard badge == nil || completedMissions.contains(badge!) else { return }
        equippedBadge = badge
    }
    var rewardUnlocked: Bool { completedMissions.count == ExperienceMission.allCases.count }

    static func favoriteKey(sourceURL: URL, appIdentifier: String) -> String {
        var parts = URLComponents(url: sourceURL, resolvingAgainstBaseURL: false)
        let scheme = parts?.scheme?.lowercased()
        let host = parts?.host?.lowercased()
        parts?.scheme = scheme
        parts?.host = host
        parts?.fragment = nil
        let url = parts?.url?.absoluteString ?? sourceURL.absoluteString
        return url + "\u{1F}" + appIdentifier
    }

    mutating func toggle(_ app: FavoriteApp) {
        if let index = favorites.firstIndex(where: { $0.id == app.id }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(app, at: 0)
            completedMissions.insert(.favorite)
        }
    }

    mutating func markSeen(key: String, version: String?) {
        guard let index = favorites.firstIndex(where: { $0.id == key }), let version, !version.isEmpty else { return }
        favorites[index].seenVersion = version
    }

    static func hasNewVersion(_ latest: String?, since previous: String?) -> Bool {
        guard let latest, let previous, !latest.isEmpty, !previous.isEmpty else { return false }
        let a = latest.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = previous.trimmingCharacters(in: .whitespacesAndNewlines)
        return a != b && a.compare(b, options: .numeric) == .orderedDescending
    }
}

struct WeeklySelection: Codable, Equatable {
    struct Pick: Codable, Identifiable, Equatable {
        let sourceURL: URL
        let appIdentifier: String
        let caption: String
        var category: String? = nil
        var isGame: Bool { category == "game" }
        var id: String { ExperienceState.favoriteKey(sourceURL: sourceURL, appIdentifier: appIdentifier) }
    }
    let title: String
    let edition: String
    let picks: [Pick]

    var isValid: Bool {
        !title.isEmpty && !edition.isEmpty && picks.count <= 12 &&
        Set(picks.map(\.id)).count == picks.count && picks.allSatisfy {
            ["http", "https"].contains($0.sourceURL.scheme?.lowercased() ?? "") &&
            !$0.appIdentifier.isEmpty && !$0.caption.isEmpty
        }
    }
}

/// Keep the chosen certificate when importing/deleting reorders the date-sorted list.
enum ExperienceCertificateSelection {
    static func index(identifiers: [String], selectedID: String, legacyIndex: Int) -> Int? {
        guard !identifiers.isEmpty else { return nil }
        if !selectedID.isEmpty, let index = identifiers.firstIndex(of: selectedID) { return index }
        // An explicitly selected certificate was removed: reset to the first available one.
        if !selectedID.isEmpty { return 0 }
        return identifiers.indices.contains(legacyIndex) ? legacyIndex : 0
    }
    static func title(nickname: String?, profileName: String?) -> String {
        for value in [nickname, profileName] {
            if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return value }
        }
        return "Chứng chỉ đang dùng"
    }
}
