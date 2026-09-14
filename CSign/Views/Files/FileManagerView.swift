import SwiftUI
import UniformTypeIdentifiers
import Zip
import NimbleViews

struct FileManagerView: View {
    @State var currentDir: URL
    @State private var files: [URL] = []
    @State private var isImporting = false
    @State private var selectedFileURL: URL?
    @State private var isEditingText = false
    @State private var isLoading = false
    
    init(directory: URL? = nil) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self._currentDir = State(initialValue: directory ?? docs)
    }
    
    var body: some View {
        NBNavigationView(currentDir.lastPathComponent) {
            NBList {
                if files.isEmpty {
                    Text(.localized("Thư mục trống"))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(files, id: \.self) { file in
                        FileRowView(
                            file: file,
                            onDelete: { deleteFile(file) },
                            onExtract: { extractZip(file) },
                            onCompress: { compressToIPA(file) },
                            onEdit: { 
                                selectedFileURL = file
                                isEditingText = true 
                            }
                        )
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { isImporting = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear(perform: loadFiles)
            .overlay {
                if isLoading {
                    ProgressView(.localized("Đang xử lý..."))
                        .padding()
                        .background(Color(.systemBackground).opacity(0.8))
                        .cornerRadius(10)
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
        }
    }
    
    func loadFiles() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: currentDir,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
                options: .skipsHiddenFiles
            )
            files = contents.sorted { 
                let isDir1 = (try? $0.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let isDir2 = (try? $1.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDir1 != isDir2 { return isDir1 }
                return $0.lastPathComponent.lowercased() < $1.lastPathComponent.lowercased()
            }
        } catch {
            print("Error loading files: \(error)")
        }
    }
    
    func importFiles(_ urls: [URL]) {
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            
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
        loadFiles()
    }
    
    func deleteFile(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        loadFiles()
    }
    
    func extractZip(_ url: URL) {
        isLoading = true
        Task {
            do {
                let destFolder = currentDir.appendingPathComponent(url.deletingPathExtension().lastPathComponent)
                try FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: true)
                try Zip.unzipFile(url, destination: destFolder, overwrite: true, password: nil)
                await MainActor.run {
                    isLoading = false
                    loadFiles()
                }
            } catch {
                await MainActor.run { isLoading = false }
                print("Extract error: \(error)")
            }
        }
    }
    
    func compressToIPA(_ url: URL) {
        isLoading = true
        Task {
            do {
                let ipaURL = currentDir.appendingPathComponent(url.lastPathComponent + "_Repack.ipa")
                try await Zip.zipFiles(paths: [url], zipFilePath: ipaURL, password: nil, progress: nil)
                await MainActor.run {
                    isLoading = false
                    loadFiles()
                }
            } catch {
                await MainActor.run { isLoading = false }
                print("Compress error: \(error)")
            }
        }
    }
}

struct FileRowView: View {
    let file: URL
    let onDelete: () -> Void
    let onExtract: () -> Void
    let onCompress: () -> Void
    let onEdit: () -> Void
    
    var isDir: Bool {
        (try? file.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }
    
    var ext: String {
        file.pathExtension.lowercased()
    }
    
    var body: some View {
        if isDir {
            NavigationLink(destination: FileManagerView(directory: file)) {
                rowContent
            }
            .contextMenu { dirMenu }
        } else {
            rowContent
                .contextMenu { fileMenu }
                .onTapGesture {
                    handleTap()
                }
        }
    }
    
    var rowContent: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.title2)
                .frame(width: 32)
            
            VStack(alignment: .leading) {
                Text(file.lastPathComponent)
                    .lineLimit(1)
                
                if !isDir, let attr = try? FileManager.default.attributesOfItem(atPath: file.path), let size = attr[.size] as? Int64 {
                    Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    var iconName: String {
        if isDir { return "folder.fill" }
        switch ext {
        case "ipa", "tipa", "zip", "deb": return "doc.zipper"
        case "plist", "json", "strings", "txt", "entitlements": return "doc.text"
        case "dylib", "bin": return "hammer.fill"
        default: return "doc"
        }
    }
    
    var iconColor: Color {
        if isDir { return .blue }
        if ["ipa", "tipa"].contains(ext) { return .accentColor }
        if ["dylib", "deb"].contains(ext) { return .purple }
        return .secondary
    }
    
    @ViewBuilder
    var dirMenu: some View {
        Button(action: onCompress) {
            Label(.localized("Đóng gói thành IPA/ZIP"), systemImage: "archivebox")
        }
        Button(role: .destructive, action: onDelete) {
            Label(.localized("Xoá"), systemImage: "trash")
        }
    }
    
    @ViewBuilder
    var fileMenu: some View {
        if ["ipa", "tipa", "zip", "deb"].contains(ext) {
            Button(action: onExtract) {
                Label(.localized("Giải nén"), systemImage: "doc.zipper")
            }
        }
        if ["plist", "json", "strings", "txt", "entitlements"].contains(ext) {
            Button(action: onEdit) {
                Label(.localized("Chỉnh sửa văn bản"), systemImage: "pencil")
            }
        }
        
        Button(action: {
            let activityVC = UIActivityViewController(activityItems: [file], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }) {
            Label(.localized("Chia sẻ"), systemImage: "square.and.arrow.up")
        }
        
        Button(role: .destructive, action: onDelete) {
            Label(.localized("Xoá"), systemImage: "trash")
        }
    }
    
    func handleTap() {
        if ["plist", "json", "strings", "txt", "entitlements"].contains(ext) {
            onEdit()
        } else if ["ipa", "tipa", "zip", "deb"].contains(ext) {
            onExtract()
        }
    }
}
