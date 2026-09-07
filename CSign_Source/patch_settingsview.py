import re

with open("CSign/Views/Settings/SettingsView.swift", "r") as f:
    content = f.read()

target = r"""				Section {
					NavigationLink(destination: ResetView()) {
						Label(.localized("Reset"), systemImage: "trash")
					}
				} footer: {
					Text(.localized("Reset the applications sources, certificates, apps, and general contents."))
				}"""

replacement = """				Section {
					NavigationLink(destination: ResetView()) {
						Label(.localized("Reset"), systemImage: "trash")
					}
				} footer: {
					Text(.localized("Reset the applications sources, certificates, apps, and general contents."))
				}
				
				NBSection("Giới thiệu") {
					Button(action: { UIApplication.shared.open(URL(string: "https://t.me/tomqtx1111")!) }) {
						Label("Liên hệ admin", systemImage: "person.crop.circle")
					}
					Button(action: { UIApplication.shared.open(URL(string: "https://t.me/chungchicuios")!) }) {
						Label("Tham gia group", systemImage: "person.3")
					}
					Button(action: { UIApplication.shared.open(URL(string: "https://t.me/chungchifree11")!) }) {
						Label("Kênh thông báo", systemImage: "bell.badge")
					}
				}
				"""

content = content.replace(target, replacement)

with open("CSign/Views/Settings/SettingsView.swift", "w") as f:
    f.write(content)

print("Patched SettingsView.swift")
