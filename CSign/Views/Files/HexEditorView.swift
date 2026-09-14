import SwiftUI
import Foundation

struct HexEditorView: View {
    let fileURL: URL
    @Environment(\.dismiss) var dismiss
    
    @State private var fileSize: UInt64 = 0
    @State private var fileHandle: FileHandle?
    @State private var visibleLines: Int = 0
    @State private var errorMessage: String?
    
    let bytesPerLine = 16
    
    var body: some View {
        NavigationView {
            Group {
                if let error = errorMessage {
                    Text(error).foregroundColor(.red).padding()
                } else if fileHandle == nil {
                    ProgressView("Đang mở tệp...")
                } else {
                    List {
                        ForEach(0..<visibleLines, id: \.self) { lineIndex in
                            HexLineView(fileHandle: fileHandle!, lineIndex: lineIndex, bytesPerLine: bytesPerLine)
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.defaultMinListRowHeight, 20)
                }
            }
            .navigationTitle(fileURL.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        try? fileHandle?.close()
                        dismiss()
                    }
                }
            }
            .onAppear(perform: loadFile)
        }
    }
    
    func loadFile() {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            fileSize = attrs[.size] as? UInt64 ?? 0
            visibleLines = Int(ceil(Double(fileSize) / Double(bytesPerLine)))
            fileHandle = try FileHandle(forReadingFrom: fileURL)
        } catch {
            errorMessage = "Lỗi đọc file: \(error.localizedDescription)"
        }
    }
}

struct HexLineView: View {
    let fileHandle: FileHandle
    let lineIndex: Int
    let bytesPerLine: Int
    
    @State private var offsetString: String = ""
    @State private var hexString: String = ""
    @State private var asciiString: String = ""
    
    var body: some View {
        HStack(spacing: 8) {
            Text(offsetString)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(hexString)
                .font(.system(size: 12, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(asciiString)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.blue)
                .frame(width: 100, alignment: .trailing)
        }
        .padding(.vertical, 2)
        .onAppear(perform: loadData)
    }
    
    func loadData() {
        let offset = UInt64(lineIndex * bytesPerLine)
        offsetString = String(format: "%08X", offset)
        
        do {
            try fileHandle.seek(toOffset: offset)
            let data = fileHandle.readData(ofLength: bytesPerLine)
            
            var hex = ""
            var ascii = ""
            
            for i in 0..<bytesPerLine {
                if i < data.count {
                    let byte = data[i]
                    hex += String(format: "%02X ", byte)
                    
                    if byte >= 32 && byte <= 126 {
                        ascii += String(Character(UnicodeScalar(byte)))
                    } else {
                        ascii += "."
                    }
                } else {
                    hex += "   "
                    ascii += " "
                }
            }
            
            hexString = hex
            asciiString = ascii
        } catch {
            hexString = "ERROR"
        }
    }
}
