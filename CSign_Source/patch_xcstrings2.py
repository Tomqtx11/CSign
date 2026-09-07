import json

with open("CSign/Resources/Localizable.xcstrings", "r") as f:
    data = json.load(f)

if "Server Type" in data["strings"]:
    if "en" in data["strings"]["Server Type"]["localizations"]:
        data["strings"]["Server Type"]["localizations"]["en"]["stringUnit"]["value"] = "Install Server"
    if "vi" in data["strings"]["Server Type"]["localizations"]:
        data["strings"]["Server Type"]["localizations"]["vi"]["stringUnit"]["value"] = "Địa chỉ máy chủ cài đặt"
    else:
        data["strings"]["Server Type"]["localizations"]["vi"] = {"stringUnit": {"state": "translated", "value": "Địa chỉ máy chủ cài đặt"}}
else:
    data["strings"]["Server Type"] = {
        "extractionState": "manual",
        "localizations": {
            "en": {"stringUnit": {"state": "translated", "value": "Install Server"}},
            "vi": {"stringUnit": {"state": "translated", "value": "Địa chỉ máy chủ cài đặt"}}
        }
    }

with open("CSign/Resources/Localizable.xcstrings", "w") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
print("Patched Localizable.xcstrings 2")
