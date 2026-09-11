import re

with open("CSign/CSignApp.swift", "r") as f:
    content = f.read()

target = """						let content = UNMutableNotificationContent()
						content.title = "CSign"
						content.body = "Đang tiếp tục tải xuống/xử lý file ở chế độ nền..."
						let request = UNNotificationRequest(identifier: "background_dl", content: content, trigger: nil)
						UNUserNotificationCenter.current().add(request)"""

content = content.replace(target, "")

with open("CSign/CSignApp.swift", "w") as f:
    f.write(content)
