import re

with open("CSign/Views/Sources/Apps/SourceAppsView.swift", "r") as f:
    content = f.read()

target = 'cats.insert(app.category?.capitalized ?? String.localized("Others"))'

replacement = '''
				let cat = app.category?.capitalized ?? ""
				if !cat.isEmpty && cat.lowercased() != "unknown" && cat.lowercased() != "others" {
					cats.insert(cat)
				} else {
					let text = ((app.name ?? "") + " " + (app.description ?? "") + " " + (app.subtitle ?? "")).lowercased()
					if text.contains("game") || text.contains("hack") || text.contains("cheat") || text.contains("mod") { cats.insert("Games") }
					else if text.contains("video") || text.contains("youtube") || text.contains("tiktok") || text.contains("movie") { cats.insert("Video") }
					else if text.contains("photo") || text.contains("camera") || text.contains("image") || text.contains("instagram") || text.contains("picsart") { cats.insert("Photo") }
					else if text.contains("edit") || text.contains("capcut") || text.contains("luma") { cats.insert("Editor") }
					else if text.contains("music") || text.contains("spotify") || text.contains("audio") || text.contains("mp3") { cats.insert("Music") }
					else if text.contains("social") || text.contains("facebook") || text.contains("twitter") || text.contains("chat") || text.contains("messenger") { cats.insert("Social") }
					else if text.contains("tool") || text.contains("utility") || text.contains("jailbreak") || text.contains("trollstore") || text.contains("manager") { cats.insert("Utilities") }
					else { cats.insert(String.localized("Others")) }
				}
'''

content = content.replace(target, replacement)

with open("CSign/Views/Sources/Apps/SourceAppsView.swift", "w") as f:
    f.write(content)
