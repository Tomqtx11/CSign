import sys

with open("CSign/Views/Sources/SourcesView.swift", "r") as f:
    content = f.read()

start = content.find('#if !NIGHTLY && !DEBUG\n\t\t.onAppear {')
if start != -1:
    end = content.find('#endif', start) + 6
    content = content[:start] + content[end:]

with open("CSign/Views/Sources/SourcesView.swift", "w") as f:
    f.write(content)
print("Removed Enjoying alert from SourcesView")
