import sys

with open("CSign/Views/Signing/SigningView.swift", "r") as f:
    content = f.read()

# Revert previous bad patch if any
content = content.replace('''
			// clone app
			if _optionsManager.options.cloneApp, let identifier = app.identifier {
				_temporaryOptions.appIdentifier = "\\(identifier).\\(_optionsManager.options.ppqString)"
			}
			
			// ppq protection
''', '// ppq protection')

# Correct patch
logic = r"""
			// clone app
			if _optionsManager.options.cloneApp, let identifier = app.identifier {
				_temporaryOptions.appIdentifier = "\(identifier).\(_optionsManager.options.ppqString)"
			}
			
			// ppq protection
"""

content = content.replace('// ppq protection\n', logic)

with open("CSign/Views/Signing/SigningView.swift", "w") as f:
    f.write(content)
print("Patched SigningView correctly")
