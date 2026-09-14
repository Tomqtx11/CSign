import SwiftUI
import Foundation

struct HexEditorView: View {
    let fileURL: URL
    @Environment(\.dismiss) var dismiss
    
    @State private var fileSize: UInt64 = 0
    @State private var fileHandle: FileHandle?
    @State private var visibleLines: Int = 0
    @State private var errorMessage: String?
    
    // Search states
    @State private var isSearching = false
    @State private var searchType = 0 // 0: Hex, 1: String
    @State private var searchString = ""
    @State private var searchResultOffset: UInt64?
    @State private var searchError = ""
    @State private var showSearchAlert = false
    
    let bytesPerLine = 16
    
    var body: some View {
        NavigationView {
            Group {
                if let error = errorMessage {
                    Text(error).foregroundColor(.red).padding()
                } else if fileHandle == nil {
                    ProgressView(.localized("Đang mở tệp..."))
                } else {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(0..<visibleLines, id: \.self) { lineIndex in
                                HexLineView(fileHandle: fileHandle!, lineIndex: lineIndex, bytesPerLine: bytesPerLine, fileURL: fileURL)
                                    .id(lineIndex)
                            }
                        }
                        .listStyle(.plain)
                        .environment(\.defaultMinListRowHeight, 20)
                        .onChange(of: searchResultOffset) { offset in
                            if let offset = offset {
                                let targetLine = Int(offset) / bytesPerLine
                                withAnimation {
                                    proxy.scrollTo(targetLine, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(fileURL.lastPathComponent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(.localized("Đóng")) {
                        try? fileHandle?.close()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showSearchAlert = true }) {
                        Image(systemName: "magnifyingglass")
                    }
                }
            }
            .onAppear(perform: loadFile)
            .sheet(isPresented: $showSearchAlert) {
                NavigationView {
                    Form {
                        Section(header: Text(.localized("Tìm kiếm (Search)"))) {
                            Picker("Loại", selection: $searchType) {
                                Text("Chuỗi (String)").tag(1)
                                Text("Mã Hex (Hex)").tag(0)
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            
                            TextField(searchType == 0 ? "Nhập Hex (VD: 4A 5B 00)" : "Nhập chuỗi...", text: $searchString)
                            
                            if !searchError.isEmpty {
                                Text(searchError).foregroundColor(.red).font(.caption)
                            }
                        }
                    }
                    .navigationTitle(.localized("Tìm kiếm"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(.localized("Huỷ")) { showSearchAlert = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(.localized("Tìm")) {
                                performSearch()
                            }
                        }
                    }
                }
            }
            .overlay {
                if isSearching {
                    ProgressView(.localized("Đang tìm kiếm..."))
                        .padding()
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(10)
                }
            }
        }
    }
    
    func loadFile() {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            fileSize = attrs[.size] as? UInt64 ?? 0
            visibleLines = Int(ceil(Double(fileSize) / Double(bytesPerLine)))
            fileHandle = try FileHandle(forUpdating: fileURL) // Changed to updating so we can write
        } catch {
            errorMessage = "Lỗi đọc file: \(error.localizedDescription)"
        }
    }
    
    func performSearch() {
        guard !searchString.isEmpty else { return }
        showSearchAlert = false
        isSearching = true
        searchError = ""
        
        let type = searchType
        let query = searchString
        let url = fileURL
        
        Task.detached {
            do {
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                
                var targetData = Data()
                if type == 1 {
                    targetData = query.data(using: .utf8) ?? Data()
                } else {
                    let hexStr = query.replacingOccurrences(of: " ", with: "")
                    var hexData = Data(capacity: hexStr.count / 2)
                    var index = hexStr.startIndex
                    while index < hexStr.endIndex {
                        let nextIndex = hexStr.index(index, offsetBy: 2, limitedBy: hexStr.endIndex) ?? hexStr.endIndex
                        if let byte = UInt8(hexStr[index..<nextIndex], radix: 16) {
                            hexData.append(byte)
                        }
                        index = nextIndex
                    }
                    targetData = hexData
                }
                
                guard !targetData.isEmpty else {
                    await MainActor.run { 
                        self.isSearching = false
                        self.searchError = "Dữ liệu tìm kiếm không hợp lệ"
                        self.showSearchAlert = true
                    }
                    return
                }
                
                // Chunked reading for large files
                let chunkSize = 1024 * 1024 * 5 // 5MB chunks
                let overlap = targetData.count - 1
                
                var currentOffset: UInt64 = 0
                let totalSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? UInt64 ?? 0
                var foundOffset: UInt64? = nil
                
                while currentOffset < totalSize {
                    try handle.seek(toOffset: currentOffset)
                    let readData = handle.readData(ofLength: chunkSize + overlap)
                    if readData.isEmpty { break }
                    
                    if let range = readData.range(of: targetData) {
                        foundOffset = currentOffset + UInt64(range.lowerBound)
                        break
                    }
                    currentOffset += UInt64(chunkSize)
                }
                
                await MainActor.run {
                    self.isSearching = false
                    if let found = foundOffset {
                        self.searchResultOffset = found
                    } else {
                        self.searchError = "Không tìm thấy"
                        self.showSearchAlert = true
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.isSearching = false
                    self.searchError = "Lỗi đọc file"
                    self.showSearchAlert = true
                }
            }
        }
    }
}

struct HexLineView: View {
    let fileHandle: FileHandle
    let lineIndex: Int
    let bytesPerLine: Int
    let fileURL: URL
    
    @State private var offsetString: String = ""
    @State private var hexString: String = ""
    @State private var asciiString: String = ""
    
    @State private var showEditAlert = false
    @State private var editHexString = ""
    @State private var updateTrigger = false // Used to refresh view after edit
    
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
        .contentShape(Rectangle())
        .onTapGesture {
            editHexString = hexString.trimmingCharacters(in: .whitespaces)
            showEditAlert = true
        }
        .onAppear(perform: loadData)
        .onChange(of: updateTrigger) { _ in loadData() }
        .alert(.localized("Sửa mã Hex (Edit Hex)"), isPresented: $showEditAlert) {
            TextField("Hex", text: $editHexString)
            Button(.localized("Huỷ"), role: .cancel) { }
            Button(.localized("Lưu")) {
                saveHexData()
            }
        } message: {
            Text(.localized("Chỉnh sửa các byte Hex tại offset \(offsetString)"))
        }
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
    
    func saveHexData() {
        let hexStr = editHexString.replacingOccurrences(of: " ", with: "")
        var hexData = Data(capacity: hexStr.count / 2)
        var index = hexStr.startIndex
        while index < hexStr.endIndex {
            let nextIndex = hexStr.index(index, offsetBy: 2, limitedBy: hexStr.endIndex) ?? hexStr.endIndex
            if let byte = UInt8(hexStr[index..<nextIndex], radix: 16) {
                hexData.append(byte)
            }
            index = nextIndex
        }
        
        guard !hexData.isEmpty else { return }
        
        do {
            let offset = UInt64(lineIndex * bytesPerLine)
            try fileHandle.seek(toOffset: offset)
            fileHandle.write(hexData)
            updateTrigger.toggle()
        } catch {
            print("Write error: \(error)")
        }
    }
}
