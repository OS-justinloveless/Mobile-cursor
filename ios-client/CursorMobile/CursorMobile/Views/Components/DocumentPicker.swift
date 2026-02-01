import SwiftUI
import UniformTypeIdentifiers

/// A file selected for upload
struct SelectedFile: Identifiable {
    let id = UUID()
    let filename: String
    let data: Data
    let mimeType: String
    let fileSize: Int
    
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
    
    /// Convert to UploadFile for API
    func toUploadFile() -> UploadFile {
        return UploadFile(filename: filename, data: data, mimeType: mimeType)
    }
}

/// Document picker that allows selecting files from the Files app
struct DocumentPicker: UIViewControllerRepresentable {
    let onFilesSelected: ([SelectedFile]) -> Void
    let allowedContentTypes: [UTType]
    let allowsMultipleSelection: Bool
    
    @Environment(\.dismiss) private var dismiss
    
    init(
        allowedContentTypes: [UTType] = [.item],
        allowsMultipleSelection: Bool = true,
        onFilesSelected: @escaping ([SelectedFile]) -> Void
    ) {
        self.allowedContentTypes = allowedContentTypes
        self.allowsMultipleSelection = allowsMultipleSelection
        self.onFilesSelected = onFilesSelected
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes, asCopy: true)
        picker.allowsMultipleSelection = allowsMultipleSelection
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            var selectedFiles: [SelectedFile] = []
            
            for url in urls {
                // Start accessing the security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    print("[DocumentPicker] Failed to access security-scoped resource: \(url)")
                    continue
                }
                
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                
                do {
                    let data = try Data(contentsOf: url)
                    let filename = url.lastPathComponent
                    let mimeType = UploadFile.detectMimeType(filename: filename)
                    
                    let selectedFile = SelectedFile(
                        filename: filename,
                        data: data,
                        mimeType: mimeType,
                        fileSize: data.count
                    )
                    selectedFiles.append(selectedFile)
                    
                    print("[DocumentPicker] Selected file: \(filename) (\(data.count) bytes)")
                } catch {
                    print("[DocumentPicker] Failed to read file \(url): \(error)")
                }
            }
            
            parent.onFilesSelected(selectedFiles)
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

/// Sheet view for uploading files
struct FileUploadSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    let destinationPath: String
    let onUploadComplete: () -> Void
    
    @State private var selectedFiles: [SelectedFile] = []
    @State private var showDocumentPicker = false
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var uploadResult: UploadFilesResponse?
    
    var body: some View {
        NavigationView {
            VStack {
                if selectedFiles.isEmpty {
                    emptyState
                } else {
                    fileList
                }
                
                if let error = uploadError {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
                
                if let result = uploadResult {
                    uploadResultView(result)
                }
            }
            .navigationTitle("Upload Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        uploadFiles()
                    } label: {
                        if isUploading {
                            ProgressView()
                        } else {
                            Text("Upload")
                        }
                    }
                    .disabled(selectedFiles.isEmpty || isUploading)
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPicker { files in
                    selectedFiles.append(contentsOf: files)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No files selected")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Tap below to select files to upload")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button {
                showDocumentPicker = true
            } label: {
                Label("Select Files", systemImage: "folder")
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var fileList: some View {
        List {
            Section {
                ForEach(selectedFiles) { file in
                    HStack {
                        Image(systemName: iconForFile(file.filename))
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading) {
                            Text(file.filename)
                                .font(.body)
                            Text(file.formattedSize)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button {
                            removeFile(file)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } header: {
                HStack {
                    Text("Selected Files (\(selectedFiles.count))")
                    Spacer()
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("Add More", systemImage: "plus")
                            .font(.caption)
                    }
                }
            } footer: {
                Text("Uploading to: \(destinationPath)")
                    .font(.caption2)
            }
        }
    }
    
    private func uploadResultView(_ result: UploadFilesResponse) -> some View {
        VStack(spacing: 8) {
            if result.totalUploaded > 0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("\(result.totalUploaded) file(s) uploaded successfully")
                }
            }
            
            if result.totalFailed > 0 {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                    Text("\(result.totalFailed) file(s) failed")
                }
            }
        }
        .font(.caption)
        .padding()
    }
    
    private func iconForFile(_ filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "js", "jsx", "ts", "tsx": return "chevron.left.forwardslash.chevron.right"
        case "py": return "chevron.left.forwardslash.chevron.right"
        case "json": return "curlybraces"
        case "md", "txt": return "doc.text.fill"
        case "html", "css": return "globe"
        case "png", "jpg", "jpeg", "gif", "svg": return "photo.fill"
        case "pdf": return "doc.richtext.fill"
        case "zip", "tar", "gz", "rar": return "doc.zipper"
        default: return "doc.fill"
        }
    }
    
    private func removeFile(_ file: SelectedFile) {
        selectedFiles.removeAll { $0.id == file.id }
    }
    
    private func uploadFiles() {
        guard let api = authManager.createAPIService() else {
            uploadError = "Not authenticated"
            return
        }
        
        isUploading = true
        uploadError = nil
        
        Task {
            do {
                let uploadFiles = selectedFiles.map { $0.toUploadFile() }
                let result = try await api.uploadFiles(files: uploadFiles, destinationPath: destinationPath)
                
                await MainActor.run {
                    uploadResult = result
                    isUploading = false
                    
                    if result.success && result.totalFailed == 0 {
                        // All files uploaded successfully, dismiss after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            onUploadComplete()
                            dismiss()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    uploadError = error.localizedDescription
                    isUploading = false
                }
            }
        }
    }
}

#Preview {
    FileUploadSheet(destinationPath: "/path/to/directory") {
        print("Upload complete")
    }
    .environmentObject(AuthManager())
}
