import sys

with open("CSign/CSignApp.swift", "r") as f:
    content = f.read()

func_def = """	private func _addDefaultSources() {
		guard UserDefaults.standard.bool(forKey: "csign.didImportDefaultSources") == false else { return }
		
		if let url = URL(string: "https://is.gd/17AE4t") {
			Storage.shared.addSource(url, name: "CSign Repository", identifier: url.absoluteString) { _ in }
		}
		
		UserDefaults.standard.set(true, forKey: "csign.didImportDefaultSources")
	}"""

if "private func _addDefaultSources()" not in content:
    content = content.replace("private func _addDefaultCertificates() {", func_def + "\n\t\n\tprivate func _addDefaultCertificates() {")

with open("CSign/CSignApp.swift", "w") as f:
    f.write(content)
print("Added missing _addDefaultSources definition")
