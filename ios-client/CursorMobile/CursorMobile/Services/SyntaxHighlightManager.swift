import SwiftUI
import SyntaxHighlight

// MARK: - Installed Grammar Model

struct InstalledGrammar: Codable, Identifiable {
    let id: UUID
    let name: String
    let scopeName: String
    let fileExtensions: [String]
    let isBundled: Bool
    let localPath: String
    let sourceURL: String?
    let installedAt: Date
    
    init(id: UUID = UUID(), name: String, scopeName: String, fileExtensions: [String], isBundled: Bool, localPath: String, sourceURL: String? = nil, installedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.scopeName = scopeName
        self.fileExtensions = fileExtensions
        self.isBundled = isBundled
        self.localPath = localPath
        self.sourceURL = sourceURL
        self.installedAt = installedAt
    }
}

// MARK: - Syntax Highlight Manager

class SyntaxHighlightManager: ObservableObject {
    static let shared = SyntaxHighlightManager()
    
    @Published var installedGrammars: [InstalledGrammar] = []
    @Published var syntaxHighlightingEnabled: Bool = true
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    private var grammarCache: [String: Grammar] = [:]
    private var themeCache: [String: Theme] = [:]
    
    private let userDefaultsKey = "installedGrammars"
    private let syntaxEnabledKey = "syntaxHighlightingEnabled"
    
    // Language to scope name mapping
    private let languageScopeMap: [String: String] = [
        "swift": "source.swift",
        "javascript": "source.js",
        "jsx": "source.js",
        "typescript": "source.ts",
        "tsx": "source.ts",
        "python": "source.python",
        "ruby": "source.ruby",
        "csharp": "source.cs",
        "rust": "source.rust",
        "go": "source.go",
        "json": "source.json",
        "html": "text.html",
        "css": "source.css",
        "yaml": "source.yaml",
        "markdown": "text.markdown",
        "plaintext": ""
    ]
    
    // Language to grammar file mapping
    private let languageGrammarFile: [String: String] = [
        "swift": "swift",
        "javascript": "javascript",
        "jsx": "javascript",
        "typescript": "typescript",
        "tsx": "typescript",
        "python": "python",
        "ruby": "ruby",
        "csharp": "csharp",
        "rust": "rust",
        "go": "go",
        "json": "json",
        "html": "html",
        "css": "css",
        "yaml": "yaml",
        "markdown": "markdown"
    ]
    
    private init() {
        loadSettings()
        loadBundledGrammars()
        loadUserGrammars()
    }
    
    // MARK: - Settings
    
    private func loadSettings() {
        syntaxHighlightingEnabled = UserDefaults.standard.object(forKey: syntaxEnabledKey) as? Bool ?? true
    }
    
    func setSyntaxHighlightingEnabled(_ enabled: Bool) {
        syntaxHighlightingEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: syntaxEnabledKey)
    }
    
    // MARK: - Bundled Grammars
    
    private func loadBundledGrammars() {
        let bundledLanguages = [
            ("Swift", "source.swift", ["swift"], "swift"),
            ("JavaScript", "source.js", ["js", "jsx", "mjs", "cjs"], "javascript"),
            ("TypeScript", "source.ts", ["ts", "tsx", "mts", "cts"], "typescript"),
            ("Python", "source.python", ["py", "pyw", "pyi"], "python"),
            ("Ruby", "source.ruby", ["rb", "rake", "gemspec", "ru", "erb"], "ruby"),
            ("C#", "source.cs", ["cs", "csx"], "csharp"),
            ("Rust", "source.rust", ["rs"], "rust"),
            ("Go", "source.go", ["go"], "go"),
            ("JSON", "source.json", ["json", "jsonc", "json5"], "json"),
            ("HTML", "text.html", ["html", "htm", "xhtml"], "html"),
            ("CSS", "source.css", ["css"], "css"),
            ("YAML", "source.yaml", ["yaml", "yml"], "yaml"),
            ("Markdown", "text.markdown", ["md", "markdown", "mdown", "mkd"], "markdown")
        ]
        
        for (name, scopeName, extensions, fileName) in bundledLanguages {
            let grammar = InstalledGrammar(
                name: name,
                scopeName: scopeName,
                fileExtensions: extensions,
                isBundled: true,
                localPath: "bundled://\(fileName)"
            )
            
            if !installedGrammars.contains(where: { $0.scopeName == scopeName && $0.isBundled }) {
                installedGrammars.append(grammar)
            }
        }
    }
    
    // MARK: - User Grammars
    
    private var userGrammarsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("SyntaxGrammars", isDirectory: true)
    }
    
    private func loadUserGrammars() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let userGrammars = try? JSONDecoder().decode([InstalledGrammar].self, from: data) {
            for grammar in userGrammars where !grammar.isBundled {
                if !installedGrammars.contains(where: { $0.id == grammar.id }) {
                    installedGrammars.append(grammar)
                }
            }
        }
    }
    
    private func saveUserGrammars() {
        let userGrammars = installedGrammars.filter { !$0.isBundled }
        if let data = try? JSONEncoder().encode(userGrammars) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
    
    // MARK: - Grammar Loading
    
    func grammar(for language: String) -> Grammar? {
        guard syntaxHighlightingEnabled else { return nil }
        
        let lang = language.lowercased()
        
        // Check cache first
        if let cached = grammarCache[lang] {
            return cached
        }
        
        // Find the grammar file name
        guard let fileName = languageGrammarFile[lang] else {
            return nil
        }
        
        // Try to load from bundle
        // File names are like "javascript.tmLanguage.json" in the Grammars folder
        let grammarFileName = "\(fileName).tmLanguage.json"
        
        // Try using subdirectory first
        if let url = Bundle.main.url(forResource: "\(fileName).tmLanguage", withExtension: "json", subdirectory: "Grammars") {
            do {
                let grammar = try Grammar(contentsOf: url)
                grammarCache[lang] = grammar
                print("[SyntaxHighlightManager] Loaded grammar for \(lang) from \(url)")
                return grammar
            } catch {
                print("[SyntaxHighlightManager] Failed to parse grammar for \(lang): \(error)")
            }
        }
        
        // Fallback: try constructing path directly
        if let bundlePath = Bundle.main.resourcePath {
            let directPath = URL(fileURLWithPath: bundlePath)
                .appendingPathComponent("Grammars")
                .appendingPathComponent(grammarFileName)
            
            if FileManager.default.fileExists(atPath: directPath.path) {
                do {
                    let grammar = try Grammar(contentsOf: directPath)
                    grammarCache[lang] = grammar
                    print("[SyntaxHighlightManager] Loaded grammar for \(lang) from direct path: \(directPath)")
                    return grammar
                } catch {
                    print("[SyntaxHighlightManager] Failed to parse grammar from direct path for \(lang): \(error)")
                }
            } else {
                print("[SyntaxHighlightManager] Grammar file not found at: \(directPath.path)")
            }
        } else {
            print("[SyntaxHighlightManager] Could not get bundle resource path")
        }
        
        // Try to load from user-installed grammars
        let scopeName = languageScopeMap[lang] ?? ""
        if let userGrammar = installedGrammars.first(where: { !$0.isBundled && $0.scopeName == scopeName }) {
            let userPath = userGrammarsDirectory.appendingPathComponent(userGrammar.localPath)
            if FileManager.default.fileExists(atPath: userPath.path) {
                do {
                    let grammar = try Grammar(contentsOf: userPath)
                    grammarCache[lang] = grammar
                    return grammar
                } catch {
                    print("Failed to load user grammar for \(lang): \(error)")
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Theme Loading
    
    func theme(for colorScheme: ColorScheme) -> Theme? {
        let themeName = colorScheme == .dark ? "Default-Dark" : "Default-Light"
        
        // Check cache
        if let cached = themeCache[themeName] {
            return cached
        }
        
        // Load from bundle using subdirectory
        if let url = Bundle.main.url(forResource: themeName, withExtension: "tmTheme", subdirectory: "Themes") {
            do {
                let theme = try Theme(contentsOf: url)
                themeCache[themeName] = theme
                print("[SyntaxHighlightManager] Loaded theme \(themeName) from \(url)")
                return theme
            } catch {
                print("[SyntaxHighlightManager] Failed to parse theme \(themeName): \(error)")
            }
        }
        
        // Fallback: try constructing path directly
        if let bundlePath = Bundle.main.resourcePath {
            let directPath = URL(fileURLWithPath: bundlePath)
                .appendingPathComponent("Themes")
                .appendingPathComponent("\(themeName).tmTheme")
            
            if FileManager.default.fileExists(atPath: directPath.path) {
                do {
                    let theme = try Theme(contentsOf: directPath)
                    themeCache[themeName] = theme
                    print("[SyntaxHighlightManager] Loaded theme \(themeName) from direct path: \(directPath)")
                    return theme
                } catch {
                    print("[SyntaxHighlightManager] Failed to parse theme from direct path: \(error)")
                }
            } else {
                print("[SyntaxHighlightManager] Theme file not found at: \(directPath.path)")
            }
        }
        
        return nil
    }
    
    // MARK: - Grammar Installation
    
    func installGrammar(from urlString: String) async throws -> InstalledGrammar {
        guard let url = URL(string: urlString) else {
            throw GrammarError.invalidURL
        }
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        defer {
            Task { @MainActor in
                isLoading = false
            }
        }
        
        // Download the grammar file
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GrammarError.downloadFailed
        }
        
        // Parse the JSON to validate it and extract metadata
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = json["name"] as? String,
              let scopeName = json["scopeName"] as? String else {
            throw GrammarError.invalidGrammarFormat
        }
        
        let fileTypes = json["fileTypes"] as? [String] ?? []
        
        // Create user grammars directory if needed
        try FileManager.default.createDirectory(at: userGrammarsDirectory, withIntermediateDirectories: true)
        
        // Generate a unique filename
        let fileName = "\(UUID().uuidString).tmLanguage.json"
        let localURL = userGrammarsDirectory.appendingPathComponent(fileName)
        
        // Save the grammar file
        try data.write(to: localURL)
        
        // Create and save the grammar record
        let grammar = InstalledGrammar(
            name: name,
            scopeName: scopeName,
            fileExtensions: fileTypes,
            isBundled: false,
            localPath: fileName,
            sourceURL: urlString
        )
        
        await MainActor.run {
            installedGrammars.append(grammar)
            saveUserGrammars()
            
            // Clear cache for languages that might use this grammar
            for (lang, scope) in languageScopeMap where scope == scopeName {
                grammarCache.removeValue(forKey: lang)
            }
        }
        
        return grammar
    }
    
    func removeGrammar(_ grammar: InstalledGrammar) throws {
        guard !grammar.isBundled else {
            throw GrammarError.cannotRemoveBundled
        }
        
        // Remove the file
        let localURL = userGrammarsDirectory.appendingPathComponent(grammar.localPath)
        if FileManager.default.fileExists(atPath: localURL.path) {
            try FileManager.default.removeItem(at: localURL)
        }
        
        // Remove from list
        installedGrammars.removeAll { $0.id == grammar.id }
        saveUserGrammars()
        
        // Clear related cache entries
        for (lang, scope) in languageScopeMap where scope == grammar.scopeName {
            grammarCache.removeValue(forKey: lang)
        }
    }
    
    // MARK: - Highlighting
    
    func highlight(code: String, language: String, colorScheme: ColorScheme) -> Text {
        guard syntaxHighlightingEnabled,
              let grammar = grammar(for: language),
              let theme = theme(for: colorScheme) else {
            // Return plain text
            return Text(code)
        }
        
        let highlighter = Highlighter(string: code, theme: theme, grammar: grammar)
        return Text(from: highlighter)
    }
}

// MARK: - Errors

enum GrammarError: LocalizedError {
    case invalidURL
    case downloadFailed
    case invalidGrammarFormat
    case cannotRemoveBundled
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .downloadFailed:
            return "Failed to download grammar file"
        case .invalidGrammarFormat:
            return "Invalid grammar file format. Expected a valid TextMate grammar (.tmLanguage.json)"
        case .cannotRemoveBundled:
            return "Cannot remove bundled grammars"
        }
    }
}
