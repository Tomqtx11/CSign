import sys

with open("CSign/CSignApp.swift", "r") as f:
    content = f.read()

# Remove the alert
start_idx = content.find('.alert("Hướng dẫn sử dụng", isPresented: Binding(get: { !hasSeenTutorialAlert }, set: { _ in })) {')
if start_idx != -1:
    end_idx = content.find('}\n\t\t}', start_idx) + 1
    content = content[:start_idx] + content[end_idx:]

# Add _addDefaultSources to AppDelegate
if "_addDefaultCertificates()" in content:
    content = content.replace("_addDefaultCertificates()", "_addDefaultCertificates()\n\t\t_addDefaultSources()")

# Add the function itself
func_def = """	private func _addDefaultSources() {
		guard UserDefaults.standard.bool(forKey: "csign.didImportDefaultSources") == false else { return }
		
		if let url = URL(string: "https://is.gd/17AE4t") {
			Storage.shared.addSource(url, name: "CSign Repository", identifier: url.absoluteString) { _ in }
		}
		
		UserDefaults.standard.set(true, forKey: "csign.didImportDefaultSources")
	}"""
if "_addDefaultSources" not in content.split("class AppDelegate")[1]:
    content = content.replace("private func _addDefaultCertificates()", func_def + "\n\t\n\tprivate func _addDefaultCertificates()")

with open("CSign/CSignApp.swift", "w") as f:
    f.write(content)
print("Patched CSignApp.swift")
