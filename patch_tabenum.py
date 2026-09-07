import sys

with open("CSign/Views/TabView/TabEnum.swift", "r") as f:
    content = f.read()

content = content.replace('case .sources:     	return .localized("Sources")', 'case .sources:     	return "IPA Mod"')
content = content.replace('case .sources:\n\t\t\tcase .library', 'case .library:\n\t\t\tcase .sources')
content = content.replace('.sources,\n\t\t\t.library', '.library,\n\t\t\t.sources')

with open("CSign/Views/TabView/TabEnum.swift", "w") as f:
    f.write(content)
print("Patched TabEnum")
