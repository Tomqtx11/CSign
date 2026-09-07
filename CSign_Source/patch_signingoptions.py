import sys

with open("CSign/Views/Signing/Shared/SigningOptionsView.swift", "r") as f:
    content = f.read()

toggle = """
			NBSection(.localized("App Cloning")) {
				_toggle(
					.localized("Clone App (Duplicate)"),
					systemImage: "doc.on.doc",
					isOn: $options.cloneApp,
					temporaryValue: temporaryOptions?.cloneApp
				)
			} footer: {
				Text(.localized("This will append a random string to the bundle identifier to allow installing multiple instances of the same app."))
			}
"""

content = content.replace('NBSection(.localized("Protection")) {', toggle + '\n\t\t\tNBSection(.localized("Protection")) {')

with open("CSign/Views/Signing/Shared/SigningOptionsView.swift", "w") as f:
    f.write(content)
print("Patched SigningOptionsView")
