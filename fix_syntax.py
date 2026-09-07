import sys

with open("CSign/CSignApp.swift", "r") as f:
    content = f.read()

bad_str = "private func _addDefaultCertificates()\n\t\t_addDefaultSources() {"
good_str = "private func _addDefaultCertificates() {"
content = content.replace(bad_str, good_str)

with open("CSign/CSignApp.swift", "w") as f:
    f.write(content)
print("Fixed syntax error")
