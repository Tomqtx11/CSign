import Foundation

@main
struct ExperienceRegressionTests {
    struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }
    static func main() throws {
        let source = URL(string: "https://example.com/repo.json")!
        let other = URL(string: "https://example.org/repo.json")!
        let a = FavoriteApp(sourceURL: source, appIdentifier: "app.example", name: "App", iconURL: nil, seenVersion: "1.9", savedAt: Date(timeIntervalSince1970: 0))
        let b = FavoriteApp(sourceURL: other, appIdentifier: "app.example", name: "Other App", iconURL: nil, seenVersion: "2", savedAt: Date(timeIntervalSince1970: 1))
        var state = ExperienceState()
        state.toggle(a); state.toggle(b)
        precondition(state.favorites.count == 2, "Same bundle ID in two repositories must remain separate")
        precondition(a.id != b.id)
        precondition(a.id == ExperienceState.favoriteKey(sourceURL: URL(string: "HTTPS://EXAMPLE.COM/repo.json#fragment")!, appIdentifier: "app.example"))
        let encoded = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(ExperienceState.self, from: encoded)
        precondition(restored == state, "Favorites and mission progress must survive reopening")
        precondition(ExperienceState.hasNewVersion("1.10", since: "1.9"))
        precondition(!ExperienceState.hasNewVersion("1.9", since: "1.10"), "A downgrade must not be advertised as a newer version")
        precondition(!ExperienceState.hasNewVersion("1.9", since: "1.9"))
        precondition(!ExperienceState.hasNewVersion(nil, since: "1.9"))
        state.markSeen(key: a.id, version: "1.10")
        precondition(state.favorites.first(where: { $0.id == a.id })?.seenVersion == "1.10")
        precondition(state.favorites.first(where: { $0.id == b.id })?.seenVersion == "2")
        state.toggle(a)
        precondition(state.favorites.count == 1 && state.favorites[0].id == b.id)
        precondition(state.completedMissions.contains(.favorite), "Removing a favorite must not erase an earned milestone")
        precondition(!state.rewardUnlocked)
        state.completedMissions.formUnion(ExperienceMission.allCases)
        precondition(state.rewardUnlocked)
        let valid = WeeklySelection(title: "Weekly", edition: "42", picks: [.init(sourceURL: source, appIdentifier: "app.example", caption: "Try this")])
        precondition(valid.isValid)
        let decodedSelection = try JSONDecoder().decode(WeeklySelection.self, from: JSONEncoder().encode(valid))
        precondition(decodedSelection == valid)
        let duplicate = WeeklySelection(title: "Weekly", edition: "42", picks: valid.picks + valid.picks)
        precondition(!duplicate.isValid, "Curated selections must reject duplicate source/app pairs")
        let invalid = WeeklySelection(title: "Weekly", edition: "42", picks: [.init(sourceURL: URL(string: "file:///tmp/repo.json")!, appIdentifier: "app.example", caption: "Invalid")])
        precondition(!invalid.isValid)
        let legacy = try JSONDecoder().decode(ExperienceState.self, from: Data("{\"favorites\":[],\"completedMissions\":[\"favorite\"]}".utf8))
        precondition(legacy.completedMissions == [.favorite] && legacy.playingGames.isEmpty)
        var upgraded = legacy
        upgraded.equip(.signed)
        precondition(upgraded.equippedBadge == nil, "Locked badges cannot be equipped")
        upgraded.equip(.favorite)
        precondition(upgraded.equippedBadge == .favorite)
        upgraded.togglePlaying(a); upgraded.togglePlaying(b)
        precondition(upgraded.playingGames.count == 2, "Playing collection remains source-aware")
        let reloaded = try JSONDecoder().decode(ExperienceState.self, from: JSONEncoder().encode(upgraded))
        precondition(reloaded == upgraded)
        upgraded.togglePlaying(a)
        precondition(upgraded.playingGames.map(\.id) == [b.id])
        upgraded.equip(nil)
        precondition(upgraded.equippedBadge == nil)
        precondition(ExperienceCertificateSelection.index(identifiers: ["new", "chosen", "other"], selectedID: "chosen", legacyIndex: 0) == 1)
        precondition(ExperienceCertificateSelection.index(identifiers: ["other"], selectedID: "deleted", legacyIndex: 1) == 0)
        precondition(ExperienceCertificateSelection.index(identifiers: ["a", "b"], selectedID: "", legacyIndex: 1) == 1)
        precondition(ExperienceCertificateSelection.index(identifiers: [], selectedID: "chosen", legacyIndex: 0) == nil)
        precondition(ExperienceCertificateSelection.title(nickname: nil, profileName: "Personal Profile") == "Personal Profile")
        precondition(ExperienceCertificateSelection.title(nickname: " ", profileName: nil) == "Chứng chỉ đang dùng")
        var seedA = SeededGenerator(state: 123)
        var sampler = ExperienceRecommendationSampler<Int>()
        for i in 0..<100 { sampler.consider(i, key: "app.\(i)", using: &seedA) }
        let sample = sampler.selection(using: &seedA)
        precondition(sample.count == 5 && Set(sample).count == 5)
        precondition(sample.contains { $0 >= 5 }, "Recommendations must not always take the first five apps")
        var seedB = SeededGenerator(state: 456)
        var small = ExperienceRecommendationSampler<Int>()
        for i in 0..<3 { small.consider(i, key: "app.\(i)", using: &seedB); small.consider(i, key: "app.\(i)", using: &seedB) }
        precondition(small.availableCount == 3)
        precondition(Set(small.selection(using: &seedB)) == Set(0..<3), "Small catalogs must not invent or duplicate apps")
        var next = ExperienceRecommendationSampler<Int>(previousKeys: Set((0..<5).map { "app.\($0)" }))
        for i in 0..<6 { next.consider(i, key: "app.\(i)", using: &seedB) }
        let nextSelection = next.selection(using: &seedB)
        precondition(nextSelection.count == 5 && nextSelection.contains(5), "Changing a six-app pool must introduce the available sixth app")
        var empty = ExperienceRecommendationSampler<Int>()
        precondition(empty.selection(using: &seedB).isEmpty)
        print("PASS experience persistence, source isolation, update tracking, milestones and weekly validation")
    }
}
