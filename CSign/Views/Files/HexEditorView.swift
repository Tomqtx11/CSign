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
    @State private var searchResultLineIndex: Int?
    @State private var searchError = ""
    @State private var showSearchSheet = false
    
    // Go to offset
    @State private var showGoToOffset = false
    @State private var goToOffsetString = ""
    
    let bytesPerLine = 16
    
    var fileSizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    
    var body: some View {
        Group {
            if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
            } else if fileHandle == nil {
                ProgressView("Đang mở tệp...")
            } else {
                VStack(spacing: 0) {
                    // Header row like ESign
                    HStack(spacing: 0) {
                        Text("Offset")
                            .frame(width: 70, alignment: .leading)
                        Text("00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("ASCII")
                            .frame(width: 90, alignment: .center)
                    }
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    
                    Divider()
                    
                    // File info bar
                    HStack {
                        Text(fileURL.lastPathComponent)
                            .font(.caption2)
                            .lineLimit(1)
                        Spacer()
                        Text(fileSizeText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray6).opacity(0.5))
                    
                    Divider()
                    
                    // Hex content
                    ScrollViewReader { proxy in
                        List {
                            ForEach(0..<visibleLines, id: \.self) { lineIndex in
                                HexLineView(
                                    fileHandle: fileHandle!,
                                    lineIndex: lineIndex,
                                    bytesPerLine: bytesPerLine,
                                    fileURL: fileURL,
                                    isHighlighted: lineIndex == searchResultLineIndex
                                )
                                .id(lineIndex)
                                .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8))
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                        .environment(\.defaultMinListRowHeight, 22)
                        .onChange(of: searchResultLineIndex) { lineIdx in
                            if let lineIdx = lineIdx {
                                withAnimation {
                                    proxy.scrollTo(lineIdx, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(fileURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showSearchSheet = true }) {
                        Label("Tìm kiếm", systemImage: "magnifyingglass")
                    }
                    Button(action: { showGoToOffset = true }) {
                        Label("Đi đến Offset", systemImage: "arrow.right.to.line")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear(perform: loadFile)
        .sheet(isPresented: $showSearchSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Tìm kiếm")) {
                        Picker("Loại", selection: $searchType) {
                            Text("Hex").tag(0)
                            Text("String").tag(1)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        TextField(searchType == 0 ? "VD: 4A 5B 00 FF" : "Nhập chuỗi...", text: $searchString)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if !searchError.isEmpty {
                            Text(searchError).foregroundColor(.red).font(.caption)
                        }
                    }
                }
                .navigationTitle("Tìm kiếm")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Huỷ") { showSearchSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Tìm") {
                            performSearch()
                        }
                    }
                }
            }
        }
        .alert("Đi đến Offset", isPresented: $showGoToOffset) {
            TextField("VD: 0x1A00 hoặc 6656", text: $goToOffsetString)
                .autocapitalization(.none)
            Button("Huỷ", role: .cancel) { }
            Button("Đi") { goToOffset() }
        }
        .overlay {
            if isSearching {
                ProgressView("Đang tìm kiếm...")
                    .padding()
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(10)
                    .shadow(radius: 5)
            }
        }
    }
    
    func loadFile() {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            fileSize = attrs[.size] as? UInt64 ?? 0
            visibleLines = Int(ceil(Double(fileSize) / Double(bytesPerLine)))
            fileHandle = try FileHandle(forUpdating: fileURL)
        } catch {
            errorMessage = "Lỗi đọc file: \(error.localizedDescription)"
        }
    }
    
    func goToOffset() {
        let str = goToOffsetString.trimmingCharacters(in: .whitespaces)
        var offset: UInt64 = 0
        
        if str.lowercased().hasPrefix("0x") {
            let hexPart = String(str.dropFirst(2))
            offset = UInt64(hexPart, radix: 16) ?? 0
        } else {
            offset = UInt64(str) ?? 0
        }
        
        let targetLine = Int(offset) / bytesPerLine
        if targetLine < visibleLines {
            searchResultLineIndex = targetLine
        }
        goToOffsetString = ""
    }
    
    func performSearch() {
        guard !searchString.isEmpty else { return }
        showSearchSheet = false
        isSearching = true
        searchError = ""
        
        let type = searchType
        let query = searchString
        let url = fileURL
        
        DispatchQueue.global(qos: .userInitiated).async {
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
                    DispatchQueue.main.async {
                        self.isSearching = false
                        self.searchError = "Dữ liệu tìm kiếm không hợp lệ"
                        self.showSearchSheet = true
                    }
                    return
                }
                
                let chunkSize = 1024 * 1024 * 5
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
                
                DispatchQueue.main.async {
                    self.isSearching = false
                    if let found = foundOffset {
                        self.searchResultOffset = found
                        self.searchResultLineIndex = Int(found) / self.bytesPerLine
                    } else {
                        self.searchError = "Không tìm thấy"
                        self.showSearchSheet = true
                    }
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.isSearching = false
                    self.searchError = "Lỗi đọc file"
                    self.showSearchSheet = true
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
    var isHighlighted: Bool = false
    
    @State private var offsetString: String = ""
    @State private var hexParts: [String] = []
    @State private var asciiString: String = ""
    @State private var dataBytes: Data = Data()
    
    @State private var showEditAlert = false
    @State private var editHexString = ""
    @State private var updateTrigger = false
    
    var body: some View {
        HStack(spacing: 0) {
            // Offset column
            Text(offsetString)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.orange)
                .frame(width: 70, alignment: .leading)
            
            // Hex bytes
            Text(hexParts.joined(separator: " "))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // ASCII column
            Text(asciiString)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.green)
                .frame(width: 90, alignment: .leading)
        }
        .padding(.vertical, 1)
        .background(isHighlighted ? Color.yellow.opacity(0.3) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            editHexString = hexParts.joined(separator: " ")
            showEditAlert = true
        }
        .onAppear(perform: loadData)
        .onChange(of: updateTrigger) { _ in loadData() }
        .alert("Sửa Hex tại \(offsetString)", isPresented: $showEditAlert) {
            TextField("Hex bytes", text: $editHexString)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            Button("Huỷ", role: .cancel) { }
            Button("Lưu") {
                saveHexData()
            }
        } message: {
            Text("Chỉnh sửa các byte hex. Các byte cách nhau bằng dấu cách.")
        }
    }
    
    func loadData() {
        let offset = UInt64(lineIndex * bytesPerLine)
        offsetString = String(format: "%08X", offset)
        
        do {
            try fileHandle.seek(toOffset: offset)
            let data = fileHandle.readData(ofLength: bytesPerLine)
            dataBytes = data
            
            var parts: [String] = []
            var ascii = ""
            
            for i in 0..<bytesPerLine {
                if i < data.count {
                    let byte = data[i]
                    parts.append(String(format: "%02X", byte))
                    
                    if byte >= 32 && byte <= 126 {
                        ascii += String(Character(UnicodeScalar(byte)))
                    } else {
                        ascii += "."
                    }
                } else {
                    parts.append("  ")
                    ascii += " "
                }
            }
            
            hexParts = parts
            asciiString = ascii
        } catch {
            hexParts = ["ERROR"]
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
