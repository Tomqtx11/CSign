import Foundation

let url = URL(fileURLWithPath: "/tmp/App.app")
let bundle = Bundle(url: url)
print("bundle:", bundle != nil)
if let bundle = bundle {
    print("execURL:", bundle.executableURL?.relativePath ?? "nil")
}
