import SwiftUI

struct SyntaxSettingsView: View {
    @ObservedObject private var manager = SyntaxHighlightManager.shared
    @State private var showImportSheet = false
    @State private var grammarURL = ""
    @State private var importError: String?
    @State private var showDeleteConfirmation = false
    @State private var grammarToDelete: InstalledGrammar?
    
    var bundledGrammars: [InstalledGrammar] {
        manager.installedGrammars.filter { $0.isBundled }
    }
    
    var userGrammars: [InstalledGrammar] {
        manager.installedGrammars.filter { !$0.isBundled }
    }
    
    var body: some View {
        List {
            // Enable/Disable Toggle
            Section {
                Toggle(isOn: Binding(
                    get: { manager.syntaxHighlightingEnabled },
                    set: { manager.setSyntaxHighlightingEnabled($0) }
                )) {
                    Label("Syntax Highlighting", systemImage: "paintbrush")
                }
            } footer: {
                Text("When enabled, code files will be displayed with colored syntax highlighting based on the language.")
            }
            
            // Bundled Grammars
            Section {
                ForEach(bundledGrammars) { grammar in
                    GrammarRow(grammar: grammar)
                }
            } header: {
                Label("Bundled Languages", systemImage: "shippingbox")
            } footer: {
                Text("These language grammars are included with the app and cannot be removed.")
            }
            
            // User-Installed Grammars
            Section {
                if userGrammars.isEmpty {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "square.stack.3d.up.slash")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("No custom grammars installed")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical)
                        Spacer()
                    }
                } else {
                    ForEach(userGrammars) { grammar in
                        GrammarRow(grammar: grammar)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    grammarToDelete = grammar
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                
                Button {
                    showImportSheet = true
                } label: {
                    Label("Import from URL", systemImage: "plus.circle")
                }
            } header: {
                Label("Custom Languages", systemImage: "square.and.arrow.down")
            } footer: {
                Text("Import TextMate grammar files (.tmLanguage.json) from URLs to add support for additional languages.")
            }
            
            // Grammar Sources
            Section {
                Link(destination: URL(string: "https://github.com/microsoft/vscode/tree/main/extensions")!) {
                    HStack {
                        Label("VS Code Extensions", systemImage: "link")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Link(destination: URL(string: "https://github.com/textmate")!) {
                    HStack {
                        Label("TextMate Bundles", systemImage: "link")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Grammar Sources")
            } footer: {
                Text("Find TextMate grammars for additional languages at these repositories. Use raw GitHub URLs to import .tmLanguage.json files.")
            }
        }
        .navigationTitle("Syntax Highlighting")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showImportSheet) {
            ImportGrammarSheet(
                url: $grammarURL,
                error: $importError,
                isPresented: $showImportSheet
            )
        }
        .confirmationDialog(
            "Delete Grammar",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let grammar = grammarToDelete {
                    deleteGrammar(grammar)
                }
            }
            Button("Cancel", role: .cancel) {
                grammarToDelete = nil
            }
        } message: {
            if let grammar = grammarToDelete {
                Text("Are you sure you want to delete the \(grammar.name) grammar? This cannot be undone.")
            }
        }
    }
    
    private func deleteGrammar(_ grammar: InstalledGrammar) {
        do {
            try manager.removeGrammar(grammar)
        } catch {
            // Show error - in a real app you'd want proper error handling
            print("Failed to delete grammar: \(error)")
        }
        grammarToDelete = nil
    }
}

// MARK: - Grammar Row

private struct GrammarRow: View {
    let grammar: InstalledGrammar
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(grammar.name)
                    .font(.body)
                
                HStack(spacing: 4) {
                    ForEach(grammar.fileExtensions.prefix(4), id: \.self) { ext in
                        Text(".\(ext)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }
                    
                    if grammar.fileExtensions.count > 4 {
                        Text("+\(grammar.fileExtensions.count - 4)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if grammar.isBundled {
                Text("Built-in")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Import Grammar Sheet

private struct ImportGrammarSheet: View {
    @Binding var url: String
    @Binding var error: String?
    @Binding var isPresented: Bool
    
    @ObservedObject private var manager = SyntaxHighlightManager.shared
    @State private var isImporting = false
    @FocusState private var isURLFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Grammar URL", text: $url)
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($isURLFieldFocused)
                } header: {
                    Text("Grammar URL")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter the URL to a TextMate grammar file (.tmLanguage.json)")
                        Text("Example:\nhttps://raw.githubusercontent.com/microsoft/vscode/main/extensions/javascript/syntaxes/JavaScript.tmLanguage.json")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let error = error {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section {
                    Button {
                        importGrammar()
                    } label: {
                        HStack {
                            Spacer()
                            if isImporting {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Importing...")
                            } else {
                                Label("Import Grammar", systemImage: "square.and.arrow.down")
                            }
                            Spacer()
                        }
                    }
                    .disabled(url.isEmpty || isImporting)
                }
            }
            .navigationTitle("Import Grammar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                isURLFieldFocused = true
            }
        }
        .presentationDetents([.medium])
    }
    
    private func importGrammar() {
        isImporting = true
        error = nil
        
        Task {
            do {
                _ = try await manager.installGrammar(from: url)
                await MainActor.run {
                    isImporting = false
                    url = ""
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isImporting = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SyntaxSettingsView()
    }
}
