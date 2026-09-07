import sys

with open("CSign/CSignApp.swift", "r") as f:
    content = f.read()

alert_code = """
			.alert("Hướng dẫn sử dụng", isPresented: Binding(get: { !hasSeenTutorialAlert }, set: { _ in })) {
				Button("Bỏ qua", role: .cancel) {
					hasSeenTutorialAlert = true
				}
				Button("Xem hướng dẫn") {
					hasSeenTutorialAlert = true
					if let url = URL(string: "https://www.google.com/search?q=cach+su+dung+esign") {
						UIApplication.shared.open(url)
					}
				}
			} message: {
				Text("Bạn đã biết cách sử dụng CSign chưa? Nếu rồi hãy bỏ qua, còn chưa biết sử dụng hãy bấm nút xem hướng dẫn.")
			}
"""

if alert_code not in content:
    content = content.replace('\n\t\t}\n\t}\n\t\n\tprivate func _handleURL', alert_code + '\n\t\t}\n\t}\n\t\n\tprivate func _handleURL')

with open("CSign/CSignApp.swift", "w") as f:
    f.write(content)
print("Restored tutorial alert in CSignApp.swift")
