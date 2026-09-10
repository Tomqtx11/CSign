import sys

with open("CSign/CSignApp.swift", "r") as f:
    content = f.read()

if "import UserNotifications" not in content:
    content = content.replace("import OSLog", "import OSLog\nimport UserNotifications")

if "UNUserNotificationCenter.current().requestAuthorization" not in content:
    app_delegate_start = content.find("func application(")
    after_bracket = content.find("{", app_delegate_start) + 1
    insert = "\n\t\tUNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }"
    content = content[:after_bracket] + insert + content[after_bracket:]

if "@Environment(\\.scenePhase) var scenePhase" not in content:
    content = content.replace("var body: some Scene {", "@Environment(\\.scenePhase) var scenePhase\n\t@State private var backgroundTask: UIBackgroundTaskIdentifier = .invalid\n\n\tvar body: some Scene {")

if ".onChange(of: scenePhase)" not in content:
    insert_on_change = """
			.onChange(of: scenePhase) { newPhase in
				if newPhase == .background {
					if downloadManager.downloads.count > 0 {
						backgroundTask = UIApplication.shared.beginBackgroundTask {
							UIApplication.shared.endBackgroundTask(backgroundTask)
							backgroundTask = .invalid
						}
						
						let content = UNMutableNotificationContent()
						content.title = "CSign"
						content.body = "Đang tiếp tục tải xuống/xử lý file ở chế độ nền..."
						let request = UNNotificationRequest(identifier: "background_dl", content: content, trigger: nil)
						UNUserNotificationCenter.current().add(request)
					}
				} else if newPhase == .active {
					if backgroundTask != .invalid {
						UIApplication.shared.endBackgroundTask(backgroundTask)
						backgroundTask = .invalid
					}
				}
			}"""
    content = content.replace(".fullScreenCover(isPresented: Binding(get: { !hasAcceptedDisclaimer }, set: { _ in })) {", insert_on_change + "\n\t\t\t.fullScreenCover(isPresented: Binding(get: { !hasAcceptedDisclaimer }, set: { _ in })) {")

with open("CSign/CSignApp.swift", "w") as f:
    f.write(content)
print("Patched CSignApp.swift for notifications")
