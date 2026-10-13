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
        case .certificate: return "Có chứng chỉ sẵn sàng để ký"
        case .signed: return "Ký thành công IPA đầu tiên"
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
    var rewardUnlocked: Bool { completedMissions.count == ExperienceMission.allCases.count }

    static func favoriteKey(sourceURL: URL, appIdentifier: String) -> String {
        var parts = URLComponents(url: sourceURL, resolvingAgainstBaseURL: false)
        parts?.scheme = parts?.scheme?.lowercased()
        parts?.host = parts?.host?.lowercased()
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
