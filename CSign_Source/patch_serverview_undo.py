import sys

with open("CSign/Views/Settings/Installation/Server & SSL/ServerView.swift", "r") as f:
    content = f.read()

# Undo
content = content.replace('private let _serverMethods: [String] = [.localized("Local Server"), .localized("Recommended Server")]', 'private let _serverMethods: [String] = [.localized("Fully Local"), .localized("Semi Local")]')

with open("CSign/Views/Settings/Installation/Server & SSL/ServerView.swift", "w") as f:
    f.write(content)
print("Undid ServerView")
