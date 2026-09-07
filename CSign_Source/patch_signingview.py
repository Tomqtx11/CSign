import re

with open("CSign/Views/Signing/SigningView.swift", "r") as f:
    content = f.read()

target = r"(\t\t\t\t\t_cert\(\)\n\t\t\t\t\t_customizationProperties\(for: app\))"
replacement = r"""					_cert()
					
					NBSection(.localized("Tính năng chung")) {
						Toggle(isOn: $_temporaryOptions.cloneApp) {
							Label(.localized("Nhân bản ứng dụng"), systemImage: "doc.on.doc")
						}
						Toggle(isOn: $_temporaryOptions.fileSharing) {
							Label(.localized("Hỗ trợ trình duyệt tài liệu"), systemImage: "folder")
						}
					}
					
					_customizationProperties(for: app)"""

content = re.sub(target, replacement, content)

with open("CSign/Views/Signing/SigningView.swift", "w") as f:
    f.write(content)

print("Patched SigningView.swift")
