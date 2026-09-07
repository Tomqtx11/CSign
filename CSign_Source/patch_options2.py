import sys

with open("CSign/Backend/Observable/OptionsManager.swift", "r") as f:
    content = f.read()

# Add to Options
content = content.replace('var ppqProtection: Bool\n\t/// (Better) protection against PPQ', 'var ppqProtection: Bool\n\t/// Clone App (Duplicate App)\n\tvar cloneApp: Bool\n\t/// (Better) protection against PPQ')

# Add to Defaults
content = content.replace('ppqProtection: false,\n\t\tdynamicProtection: false,', 'ppqProtection: false,\n\t\tcloneApp: false,\n\t\tdynamicProtection: false,')

with open("CSign/Backend/Observable/OptionsManager.swift", "w") as f:
    f.write(content)
print("Patched OptionsManager 2")
