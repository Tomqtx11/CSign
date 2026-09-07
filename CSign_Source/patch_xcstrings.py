import json

with open("CSign/Resources/Localizable.xcstrings", "r") as f:
    data = json.load(f)

if "Fully Local" in data["strings"]:
    # update english
    if "en" in data["strings"]["Fully Local"]["localizations"]:
        data["strings"]["Fully Local"]["localizations"]["en"]["stringUnit"]["value"] = "Local Server"
    # update vietnamese
    if "vi" in data["strings"]["Fully Local"]["localizations"]:
        data["strings"]["Fully Local"]["localizations"]["vi"]["stringUnit"]["value"] = "Máy chủ Local"
    else:
        data["strings"]["Fully Local"]["localizations"]["vi"] = {"stringUnit": {"state": "translated", "value": "Máy chủ Local"}}

if "Semi Local" in data["strings"]:
    # update english
    if "en" in data["strings"]["Semi Local"]["localizations"]:
        data["strings"]["Semi Local"]["localizations"]["en"]["stringUnit"]["value"] = "Recommended Server"
    # update vietnamese
    if "vi" in data["strings"]["Semi Local"]["localizations"]:
        data["strings"]["Semi Local"]["localizations"]["vi"]["stringUnit"]["value"] = "Máy chủ Khuyến nghị"
    else:
        data["strings"]["Semi Local"]["localizations"]["vi"] = {"stringUnit": {"state": "translated", "value": "Máy chủ Khuyến nghị"}}

with open("CSign/Resources/Localizable.xcstrings", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
print("Patched Localizable.xcstrings")
