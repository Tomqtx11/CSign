import sys

with open("CSign/Views/Settings/SettingsView.swift", "r") as f:
    content = f.read()

# Change donation URL
content = content.replace('private let _donationsUrl = "https://github.com/sponsors/claration"', 'private let _donationsUrl = "https://cuios.shop"')

# Remove _feedback() from body
content = content.replace('\t\t\t\t_feedback()', '')

# Remove _githubUrl
content = content.replace('private let _githubUrl = "https://github.com/claration/CSign"', '')

# Add Language Toggle
lang_button = """
			.toolbar {
				ToolbarItem(placement: .navigationBarTrailing) {
					Button(action: {
						let current = UserDefaults.standard.stringArray(forKey: "AppleLanguages")?.first ?? "vi"
						let newLanguage = current == "en" ? "vi" : "en"
						UserDefaults.standard.set([newLanguage], forKey: "AppleLanguages")
						UserDefaults.standard.synchronize()
						
						let alert = UIAlertController(title: "Language Changed", message: "Ứng dụng sẽ thoát để áp dụng ngôn ngữ mới.", preferredStyle: .alert)
						alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
							exit(0)
						})
						UIApplication.topViewController()?.present(alert, animated: true)
					}) {
						Image(systemName: "globe")
					}
				}
			}
"""
content = content.replace('}\n\t\t}\n\t}\n}', '}\n' + lang_button + '\t\t}\n\t}\n}')

# Remove _feedback block
start_fb = content.find('\t@ViewBuilder\n\tprivate func _feedback() -> some View {')
if start_fb != -1:
    end_fb = content.find('@ViewBuilder\n\tprivate func _directories()', start_fb)
    content = content[:start_fb] + content[end_fb-1:]

# Remove _makeGitHubIssueURL
start_issue = content.find('\tprivate func _makeGitHubIssueURL(url: String) -> String {')
if start_issue != -1:
    end_issue = content.find('\n}\n', start_issue)
    content = content[:start_issue] + content[end_issue+1:]

with open("CSign/Views/Settings/SettingsView.swift", "w") as f:
    f.write(content)
print("Patched SettingsView")
