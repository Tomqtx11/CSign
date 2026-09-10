import sys

with open("CSign/CSignApp.swift", "r") as f:
    content = f.read()

target = """				existing.name = "CSign IPA Repo"
				Storage.shared.saveContext()
			} else {
				Storage.shared.addSource(url, name: "CSign IPA Repo", identifier: url.absoluteString) { _ in }
			}"""

replacement = """				existing.name = "CSign IPA Repo"
				existing.iconURL = URL(string: "https://apptesters.org/apptesters-512x512.png")
				Storage.shared.saveContext()
			} else {
				Storage.shared.addSource(url, name: "CSign IPA Repo", identifier: url.absoluteString, iconURL: URL(string: "https://apptesters.org/apptesters-512x512.png")) { _ in }
			}"""

content = content.replace(target, replacement)

with open("CSign/CSignApp.swift", "w") as f:
    f.write(content)

print("Patched default source iconURL")
