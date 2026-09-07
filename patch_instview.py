import re

with open("CSign/Views/Settings/Installation/InstallationView.swift", "r") as f:
    content = f.read()

target = 'NBList(.localized("Installation")) {'
replacement = 'NBList(.localized("Chọn máy chủ ký")) {'

content = content.replace(target, replacement)

with open("CSign/Views/Settings/Installation/InstallationView.swift", "w") as f:
    f.write(content)

print("Patched InstallationView.swift")
