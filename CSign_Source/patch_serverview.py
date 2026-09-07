import sys

with open("CSign/Views/Settings/Installation/Server & SSL/ServerView.swift", "r") as f:
    content = f.read()

# Change the labels
content = content.replace('private let _serverMethods: [String] = [.localized("Fully Local"), .localized("Semi Local")]', 'private let _serverMethods: [String] = [.localized("Local Server"), .localized("Recommended Server")]')

with open("CSign/Views/Settings/Installation/Server & SSL/ServerView.swift", "w") as f:
    f.write(content)
print("Patched ServerView")
