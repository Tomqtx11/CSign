import SwiftUI
import UIKit
import UniformTypeIdentifiers
import Zip
import NimbleViews


struct FileItem: Hashable, Identifiable {
    var id: URL { url }
    let url: URL
    let name: String
    let isDir: Bool
    let size: Int64
    let ext: String
}

struct FileManagerView: View {
    @State var currentDir: URL
    @State private var files: [FileItem] = []
    @State private var isImporting = false

    @State private var selectedFileURL: URL?
    @State private var isEditingText = false
    @State private var navigateToHexEditor = false

    @State private var isLoading = false
    @State private var loadingMessage = "Đang xử lý..."

    @State private var isCreatingFolder = false
    @State private var newFolderName = ""
    @State private var isCreatingFile = false
    @State private var newFileName = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var isEditing = false
    @State private var selectedFiles = Set<FileItem>()
    
    // File action sheet
    @State private var showFileActions = false
    @State private var actionFile: FileItem?

    
    init(directory: URL? = nil) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self._currentDir = State(initialValue: directory ?? docs)
    }
    
    var body: some View {
        Group {
            NBListAdaptable {
                if files.isEmpty {
                    Text(.localized("Thư mục trống"))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(files) { file in
                        HStack {
                            if isEditing {
                                Image(systemName: selectedFiles.contains(file) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedFiles.contains(file) ? .accentColor : .secondary)
                                    .font(.title2)
                                    .padding(.trailing, 8)
                            }
                            
                            if file.isDir {
                                NavigationLink(destination: FileManagerView(directory: file.url)) {
                                    fileRowContent(file: file)
                                }
                                .contextMenu { dirContextMenu(file: file) }
                                .allowsHitTesting(!isEditing)
                            } else {
                                fileRowContent(file: file)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if !isEditing {
                                            actionFile = file
                                            showFileActions = true
                                        }
                                    }
                                    .contextMenu { fileContextMenu(file: file) }
                                    .allowsHitTesting(!isEditing)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isEditing {
                                if selectedFiles.contains(file) {
                                    selectedFiles.remove(file)
                                } else {
                                    selectedFiles.insert(file)
                                }
                            }
                        }
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        if !isEditing {
                            Menu {
                                Button(action: { isImporting = true }) {
                                    Label("Nhập File", systemImage: "square.and.arrow.down")
                                }
                                Button(action: { isCreatingFolder = true }) {
                                    Label("Tạo thư mục", systemImage: "folder.badge.plus")
                                }
                                Button(action: { isCreatingFile = true }) {
                                    Label("Tạo tập tin", systemImage: "doc.badge.plus")
                                }
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                        
                        Button(action: {
                            withAnimation {
                                isEditing.toggle()
                                if !isEditing { selectedFiles.removeAll() }
                            }
                        }) {
                            Text(isEditing ? "Xong" : "Sửa")
                        }
                    }
                }
                
                if isEditing {
                    ToolbarItem(placement: .bottomBar) {
                        HStack {
                            Button(action: {
                                if selectedFiles.count == files.count {
                                    selectedFiles.removeAll()
                                } else {
                                    selectedFiles = Set(files)
                                }
                            }) {
                                Text("Chọn tất cả")
                            }
                            Spacer()
                            Button(role: .destructive, action: {
                                deleteSelectedFiles()
                            }) {
                                Image(systemName: "trash")
                            }
                            .disabled(selectedFiles.isEmpty)
                        }
                    }
                }
            }
            
            .alert("Tạo thư mục mới", isPresented: $isCreatingFolder) {
                TextField("Tên thư mục", text: $newFolderName)
                Button("Huỷ", role: .cancel) { newFolderName = "" }
                Button("Tạo") { createNewFolder() }
            }
            .alert("Tạo tập tin mới", isPresented: $isCreatingFile) {
                TextField("Tên tập tin (VD: info.txt)", text: $newFileName)
                Button("Huỷ", role: .cancel) { newFileName = "" }
                Button("Tạo") { createNewFile() }
            }
            .alert("Thông báo", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }

            .onAppear(perform: loadFiles)
            .overlay {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text(loadingMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(24)
                    .background(Color(.systemBackground).opacity(0.95))
                    .cornerRadius(12)
                    .shadow(radius: 5)
                }
            }
            .sheet(isPresented: $isImporting) {
                FileImporterRepresentableView(
                    allowedContentTypes: [.item],
                    allowsMultipleSelection: true,
                    onDocumentsPicked: { urls in
                        importFiles(urls)
                    }
                )
                .ignoresSafeArea()
            }

            .sheet(isPresented: $isEditingText) {
                if let url = selectedFileURL {
                    TextEditorView(fileURL: url)
                }
            }
            
            // File action sheet
            .confirmationDialog(
                actionFile?.name ?? "File",
                isPresented: $showFileActions,
                titleVisibility: .visible
            ) {
                if let file = actionFile {
                    let textExts = ["plist", "json", "strings", "txt", "entitlements", "xml", "html", "css", "js", "swift", "m", "h", "c", "cpp", "py", "sh", "md"]
                    let archiveExts = ["ipa", "tipa", "zip", "deb"]
                    
                    if textExts.contains(file.ext) {
                        Button("Chỉnh sửa văn bản") {
                            selectedFileURL = file.url
                            isEditingText = true
                        }
                    }
                    
                    if archiveExts.contains(file.ext) {
                        Button("Giải nén") {
                            extractZip(file.url)
                        }
                    }
                    
                    Button("Hex Editor") {
                        selectedFileURL = file.url
                        navigateToHexEditor = true
                    }
                    
                    Button("Chia sẻ") {
                        shareFile(file.url)
                    }
                    
                    Button("Sao chép") {
                        UIPasteboard.general.url = file.url
                        alertMessage = "Đã sao chép đường dẫn file."
                        showAlert = true
                    }
                    
                    Button("Xoá", role: .destructive) {
                        deleteFile(file.url)
                    }
                }
            }
            
            // Hidden NavigationLink for Hex Editor push navigation
            NavigationLink(
                destination: Group {
                    if let url = selectedFileURL {
                        HexEditorView(fileURL: url)
                    }
                },
                isActive: $navigateToHexEditor
            ) {
                EmptyView()
            }
            .hidden()
        }
        .navigationTitle(
            currentDir == FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] 
            ? String.localized("Tệp tin") 
            : currentDir.lastPathComponent
        )
    }
    
    // MARK: - Row Content
    
    func fileRowContent(file: FileItem) -> some View {
        HStack {
            Image(systemName: iconName(for: file))
                .foregroundColor(iconColor(for: file))
                .font(.title2)
                .frame(width: 32)
            
            VStack(alignment: .leading) {
                Text(file.name)
                    .lineLimit(1)
                
                if !file.isDir && file.size > 0 {
                    Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    func iconName(for file: FileItem) -> String {
        if file.isDir { return "folder.fill" }
        switch file.ext {
        case "ipa", "tipa", "zip", "deb": return "doc.zipper"
        case "plist", "json", "strings", "txt", "entitlements", "xml", "html", "css", "js", "swift", "m", "h", "c", "cpp", "py", "sh", "md": return "doc.text"
        case "dylib", "bin", "framework": return "hammer.fill"
        case "png", "jpg", "jpeg", "gif", "webp", "svg": return "photo"
        default: return "doc"
        }
    }
    
    func iconColor(for file: FileItem) -> Color {
        if file.isDir { return .blue }
        if ["ipa", "tipa"].contains(file.ext) { return .accentColor }
        if ["dylib", "deb"].contains(file.ext) { return .purple }
        if ["png", "jpg", "jpeg", "gif"].contains(file.ext) { return .pink }
        return .secondary
    }
    
    // MARK: - Context Menus
    
    @ViewBuilder
    func dirContextMenu(file: FileItem) -> some View {
        Button(action: { compressToIPA(file.url) }) {
            Label("Đóng gói thành IPA/ZIP", systemImage: "archivebox")
        }
        Button(action: { shareFile(file.url) }) {
            Label("Chia sẻ", systemImage: "square.and.arrow.up")
        }
        Button(role: .destructive, action: { deleteFile(file.url) }) {
            Label("Xoá", systemImage: "trash")
        }
    }
    
    @ViewBuilder
    func fileContextMenu(file: FileItem) -> some View {
        let textExts = ["plist", "json", "strings", "txt", "entitlements", "xml", "html", "css", "js"]
        let archiveExts = ["ipa", "tipa", "zip", "deb"]
        
        if archiveExts.contains(file.ext) {
            Button(action: { extractZip(file.url) }) {
                Label("Giải nén", systemImage: "doc.zipper")
            }
        }
        if textExts.contains(file.ext) {
            Button(action: {
                selectedFileURL = file.url
                isEditingText = true
            }) {
                Label("Chỉnh sửa văn bản", systemImage: "pencil")
            }
        }
        
        Button(action: {
            selectedFileURL = file.url
            navigateToHexEditor = true
        }) {
            Label("Hex Editor", systemImage: "chevron.left.forwardslash.chevron.right")
        }
        
        Button(action: { shareFile(file.url) }) {
            Label("Chia sẻ", systemImage: "square.and.arrow.up")
        }
        
        Button(role: .destructive, action: { deleteFile(file.url) }) {
            Label("Xoá", systemImage: "trash")
        }
    }
    
    // MARK: - Actions
    
    func shareFile(_ url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
    
    func deleteSelectedFiles() {
        for file in selectedFiles {
            try? FileManager.default.removeItem(at: file.url)
        }
        selectedFiles.removeAll()
        isEditing = false
        loadFiles()
    }
    
    func createNewFolder() {
        guard !newFolderName.isEmpty else { return }
        let url = currentDir.appendingPathComponent(newFolderName)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        newFolderName = ""
        loadFiles()
    }
    
    func createNewFile() {
        guard !newFileName.isEmpty else { return }
        let url = currentDir.appendingPathComponent(newFileName)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        newFileName = ""
        loadFiles()
    }

    func loadFiles() {
        let current = self.currentDir
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: current,
                    includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                    options: .skipsHiddenFiles
                )
                
                let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                var items: [FileItem] = []
                
                for url in contents {
                    let name = url.lastPathComponent
                    if current == docs {
                        let hidden = ["Archives", "Signed", "Unsigned", "Certificates"]
                        if hidden.contains(name) || name.hasPrefix(".") {
                            continue
                        }
                    }
                    
                    let vals = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
                    let isDir = vals?.isDirectory ?? false
                    let size = Int64(vals?.fileSize ?? 0)
                    let ext = url.pathExtension.lowercased()
                    
                    items.append(FileItem(url: url, name: name, isDir: isDir, size: size, ext: ext))
                }
                
                let sortedItems = items.sorted {
                    if $0.isDir != $1.isDir { return $0.isDir }
                    return $0.name.lowercased() < $1.name.lowercased()
                }
                
                DispatchQueue.main.async {
                    self.files = sortedItems
                }
            } catch {
                print("Error loading files: \(error)")
            }
        }
    }
    
    func importFiles(_ urls: [URL]) {
        for url in urls {
            
            let dest = currentDir.appendingPathComponent(url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: url, to: dest)
            } catch {
                print("Import error: \(error)")
            }
        }
        
        if urls.count > 0 {
            alertMessage = String.localized("Đã nhập thành công \(urls.count) tệp tin.")
            showAlert = true
        }
        loadFiles()
    }
    
    func deleteFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        loadFiles()
    }
    
    func extractZip(_ url: URL) {
        loadingMessage = "Đang giải nén..."
        isLoading = true
        let current = self.currentDir
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let destFolder = current.appendingPathComponent(url.deletingPathExtension().lastPathComponent)
                try FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
                try Zip.unzipFile(url, destination: destFolder, overwrite: true, password: nil)
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.alertMessage = "Giải nén thành công!"
                    self.showAlert = true
                    self.loadFiles()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.alertMessage = "Lỗi giải nén: \(error.localizedDescription)"
                    self.showAlert = true
                }
                print("Extract error: \(error)")
            }
        }
    }
    
    func compressToIPA(_ url: URL) {
        loadingMessage = "Đang đóng gói IPA..."
        isLoading = true
        let current = self.currentDir
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let ipaURL = current.appendingPathComponent(url.lastPathComponent + "_Repack.ipa")
                try Zip.zipFiles(paths: [url], zipFilePath: ipaURL, password: nil, compression: .DefaultCompression, progress: nil)
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.alertMessage = "Đóng gói thành công!"
                    self.showAlert = true
                    self.loadFiles()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.alertMessage = "Lỗi đóng gói: \(error.localizedDescription)"
                    self.showAlert = true
                }
                print("Compress error: \(error)")
            }
        }
    }
}
