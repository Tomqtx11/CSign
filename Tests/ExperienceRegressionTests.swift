import Foundation

@main
struct ExperienceRegressionTests {
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
        print("PASS experience persistence, source isolation, update tracking, milestones and weekly validation")
    }
}
