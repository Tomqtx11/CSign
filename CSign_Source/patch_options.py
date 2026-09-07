import sys

with open("CSign/Backend/Observable/OptionsManager.swift", "r") as f:
    content = f.read()

content = content.replace("post_installAppAfterSigned: false,", "post_installAppAfterSigned: true,")

with open("CSign/Backend/Observable/OptionsManager.swift", "w") as f:
    f.write(content)
print("Patched OptionsManager")
