import SwiftUI
import NimbleViews

struct TextEditorView: View {
    let fileURL: URL
    @State private var text: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .padding()
                .navigationTitle(fileURL.lastPathComponent)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(.localized("Đóng")) {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(.localized("Lưu")) {
                            saveFile()
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    loadFile()
                }
        }
    }
    
    func loadFile() {
        do {
            text = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            print("Error reading file: \(error)")
            // Thử đọc Plist
            if fileURL.pathExtension.lowercased() == "plist" {
                if let data = try? Data(contentsOf: fileURL),
                   let plistStr = String(data: data, encoding: .utf8) {
                    text = plistStr
                } else if let dict = NSDictionary(contentsOf: fileURL) {
                    text = dict.description
                }
            }
        }
    }
    
    func saveFile() {
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error writing file: \(error)")
        }
    }
}
