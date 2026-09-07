with open("CSign/Views/Settings/SettingsView.swift", "r") as f:
    content = f.read()

target = """				NBSection("Giới thiệu") {
					Button(action: { UIApplication.shared.open(URL(string: "https://t.me/tomqtx1111")!) }) {
						Label("Liên hệ admin", systemImage: "person.crop.circle")
					}
					Button(action: { UIApplication.shared.open(URL(string: "https://t.me/chungchicuios")!) }) {
						Label("Tham gia group", systemImage: "person.3")
					}
					Button(action: { UIApplication.shared.open(URL(string: "https://t.me/chungchifree11")!) }) {
						Label("Kênh thông báo", systemImage: "bell.badge")
					}
				}"""

replacement = """				NBSection("Giới thiệu") {
					Link(destination: URL(string: "https://t.me/tomqtx1111")!) {
						Label("Liên hệ admin", systemImage: "person.crop.circle")
					}
					Link(destination: URL(string: "https://t.me/chungchicuios")!) {
						Label("Tham gia group", systemImage: "person.3")
					}
					Link(destination: URL(string: "https://t.me/chungchifree11")!) {
						Label("Kênh thông báo", systemImage: "bell.badge")
					}
				}"""

content = content.replace(target, replacement)

with open("CSign/Views/Settings/SettingsView.swift", "w") as f:
    f.write(content)

print("Patched Links")
