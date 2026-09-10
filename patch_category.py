import sys

with open("CSign/Views/Sources/Apps/UIKit/SourceAppsTableRepresentableView.swift", "r") as f:
    content = f.read()

# Add _groupedAppsByCategory
content = content.replace(
    "private var _groupedAppsByNameFirstLetter: [String: [SourceAppEntry]] = [:]",
    "private var _groupedAppsByNameFirstLetter: [String: [SourceAppEntry]] = [:]\n\tprivate var _groupedAppsByCategory: [String: [SourceAppEntry]] = [:]"
)

# Add .category logic to _calculateSortedApps
category_logic = """		case .category:
			let sorted = filtered.sorted {
				let n1 = $0.app.name ?? ""
				let n2 = $1.app.name ?? ""
				let comparison = n1.localizedCaseInsensitiveCompare(n2) == .orderedAscending
				return sortAscending ? comparison : !comparison
			}
			_groupedAppsByCategory = Dictionary(grouping: sorted) {
				$0.app.category?.capitalized ?? .localized("Others")
			}
			_sortedSectionTitles = _groupedAppsByCategory.keys.sorted(by: {
				let other = .localized("Others")
				if $0 == other { return false }
				if $1 == other { return true }
				return sortAscending ? $0 < $1 : $0 > $1
			})
			return sorted
		}"""

content = content.replace("return sorted\n\t\t}", "return sorted\n" + category_logic)

# Replace switch sortOption in other methods
content = content.replace("case .name, .date: _sortedSectionTitles.count", "case .name, .date, .category: _sortedSectionTitles.count")
content = content.replace("case .name, .date: title = _sortedSectionTitles[section]", "case .name, .date, .category: title = _sortedSectionTitles[section]")

content = content.replace(
    "case .date: _groupedAppsByDate[_sortedSectionTitles[section]]?.count ?? 0",
    "case .date: _groupedAppsByDate[_sortedSectionTitles[section]]?.count ?? 0\n\t\tcase .category: _groupedAppsByCategory[_sortedSectionTitles[section]]?.count ?? 0"
)

content = content.replace(
    "case .date: entry = _groupedAppsByDate[_sortedSectionTitles[indexPath.section]]?[indexPath.row] ?? _sortedApps[indexPath.row]",
    "case .date: entry = _groupedAppsByDate[_sortedSectionTitles[indexPath.section]]?[indexPath.row] ?? _sortedApps[indexPath.row]\n\t\tcase .category: entry = _groupedAppsByCategory[_sortedSectionTitles[indexPath.section]]?[indexPath.row] ?? _sortedApps[indexPath.row]"
)

with open("CSign/Views/Sources/Apps/UIKit/SourceAppsTableRepresentableView.swift", "w") as f:
    f.write(content)

print("Patched SourceAppsTableRepresentableView for categories")
