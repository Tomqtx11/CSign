import re

with open("CSign/Views/Settings/SettingsView.swift", "r") as f:
    content = f.read()

target = r"""				NBSection(.localized("General")) {
					NavigationLink(destination: AppIconView(currentIcon: $_currentIcon)) {
						Label(.localized("App Icon"), systemImage: "app.dashed")
					}"""

replacement = """				NBSection(.localized("General")) {"""

content = content.replace(target, replacement)

with open("CSign/Views/Settings/SettingsView.swift", "w") as f:
    f.write(content)

print("Patched SettingsView.swift Icon")
