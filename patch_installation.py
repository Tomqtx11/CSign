import re

with open("CSign/Views/Settings/SettingsView.swift", "r") as f:
    content = f.read()

target = 'Label(.localized("Installation"), systemImage: "arrow.down.circle")'
replacement = 'Label(.localized("Chọn máy chủ ký"), systemImage: "arrow.down.circle")'

content = content.replace(target, replacement)

with open("CSign/Views/Settings/SettingsView.swift", "w") as f:
    f.write(content)

print("Patched SettingsView.swift Installation")
