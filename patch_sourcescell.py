import sys

with open("CSign/Views/Sources/SourcesCellView.swift", "r") as f:
    content = f.read()

content = content.replace('subtitle: source.sourceURL?.absoluteString ?? "",', 'subtitle: .localized("Protected Source"),')
content = content.replace('''	@ViewBuilder
	private func _contextActions(for source: AltSource) -> some View {
		Button(.localized("Copy"), systemImage: "doc.on.clipboard") {
			UIPasteboard.general.string = source.sourceURL?.absoluteString
		}
	}''', '''	@ViewBuilder
	private func _contextActions(for source: AltSource) -> some View {
	}''')

with open("CSign/Views/Sources/SourcesCellView.swift", "w") as f:
    f.write(content)
print("Patched SourcesCellView")
