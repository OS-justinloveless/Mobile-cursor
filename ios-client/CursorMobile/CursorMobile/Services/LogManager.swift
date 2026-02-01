import Foundation

/// Log levels for categorizing log entries
enum LogLevel: String, Codable, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warn = "warn"
    case error = "error"
    
    var emoji: String {
        switch self {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warn: return "⚠️"
        case .error: return "❌"
        }
    }
    
    var priority: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warn: return 2
        case .error: return 3
        }
    }
}

/// A single log entry
struct LogEntry: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    let data: String?
    
    init(level: LogLevel, category: String, message: String, data: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
        self.data = data
    }
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
    
    var fullTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: timestamp)
    }
}

/// Server log entry (from API)
struct ServerLogEntry: Codable, Identifiable {
    let timestamp: String
    let level: String
    let category: String
    let message: String
    let data: [String: AnyCodableValue]?
    
    var id: String { "\(timestamp)-\(message.prefix(20))" }
    
    var logLevel: LogLevel {
        LogLevel(rawValue: level) ?? .info
    }
    
    var formattedTimestamp: String {
        // Parse ISO timestamp and format for display
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: timestamp) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateFormat = "HH:mm:ss"
            return displayFormatter.string(from: date)
        }
        return String(timestamp.suffix(12))
    }
    
    var formattedData: String? {
        guard let data = data else { return nil }
        // Convert to readable string
        var lines: [String] = []
        for (key, value) in data.sorted(by: { $0.key < $1.key }) {
            lines.append("\(key): \(formatValue(value))")
        }
        return lines.joined(separator: "\n")
    }
    
    private func formatValue(_ value: AnyCodableValue) -> String {
        switch value {
        case .string(let s): return s
        case .int(let i): return String(i)
        case .double(let d): return String(d)
        case .bool(let b): return String(b)
        case .array(let arr): return "[\(arr.count) items]"
        case .dictionary(let dict): return "{\(dict.count) keys}"
        case .null: return "null"
        }
    }
}

/// Response from server logs API
struct ServerLogsResponse: Codable {
    let logs: [ServerLogEntry]
    let count: Int
    let levels: [String]?
}

struct ServerLogDatesResponse: Codable {
    let dates: [String]
}

/// LogManager - Centralized logging for the iOS app
/// 
/// Provides:
/// - In-memory log storage with size limits
/// - File persistence for session logs
/// - Level-based filtering
/// - Category-based organization
@MainActor
class LogManager: ObservableObject {
    static let shared = LogManager()
    
    /// Recent logs in memory (newest first)
    @Published private(set) var logs: [LogEntry] = []
    
    /// Maximum logs to keep in memory
    private let maxMemoryLogs = 500
    
    /// Minimum log level to record
    var minLevel: LogLevel = .debug
    
    /// File URL for persisting logs
    private var logFileURL: URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let logsDir = documentsDir.appendingPathComponent("Logs", isDirectory: true)
        
        // Create logs directory if needed
        try? FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        
        return logsDir.appendingPathComponent("app-\(dateString).log")
    }
    
    private init() {
        // Load logs from current session file if it exists
        loadSessionLogs()
        
        // Clean up old log files
        cleanupOldLogs()
    }
    
    // MARK: - Logging Methods
    
    func log(_ level: LogLevel, _ category: String, _ message: String, data: Any? = nil) {
        guard level.priority >= minLevel.priority else { return }
        
        var dataString: String? = nil
        if let data = data {
            if let dict = data as? [String: Any] {
                dataString = dict.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            } else {
                dataString = String(describing: data)
            }
        }
        
        let entry = LogEntry(level: level, category: category, message: message, data: dataString)
        
        // Add to memory (newest first)
        logs.insert(entry, at: 0)
        
        // Trim if needed
        if logs.count > maxMemoryLogs {
            logs = Array(logs.prefix(maxMemoryLogs))
        }
        
        // Write to file
        writeToFile(entry)
        
        // Also print to console for Xcode
        print("[\(entry.formattedTimestamp)] [\(level.rawValue.uppercased())] [\(category)] \(message)" + (dataString.map { " | \($0)" } ?? ""))
    }
    
    func debug(_ category: String, _ message: String, data: Any? = nil) {
        log(.debug, category, message, data: data)
    }
    
    func info(_ category: String, _ message: String, data: Any? = nil) {
        log(.info, category, message, data: data)
    }
    
    func warn(_ category: String, _ message: String, data: Any? = nil) {
        log(.warn, category, message, data: data)
    }
    
    func error(_ category: String, _ message: String, data: Any? = nil) {
        log(.error, category, message, data: data)
    }
    
    // MARK: - Filtering
    
    func getFilteredLogs(level: LogLevel? = nil, category: String? = nil, limit: Int = 100) -> [LogEntry] {
        var filtered = logs
        
        if let level = level {
            filtered = filtered.filter { $0.level.priority >= level.priority }
        }
        
        if let category = category, !category.isEmpty {
            filtered = filtered.filter { $0.category.localizedCaseInsensitiveContains(category) }
        }
        
        return Array(filtered.prefix(limit))
    }
    
    // MARK: - File Operations
    
    private func writeToFile(_ entry: LogEntry) {
        guard let fileURL = logFileURL else { return }
        
        let line = "[\(entry.fullTimestamp)] [\(entry.level.rawValue.uppercased())] [\(entry.category)] \(entry.message)" + (entry.data.map { " | \($0)" } ?? "") + "\n"
        
        guard let data = line.data(using: .utf8) else { return }
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                try? fileHandle.close()
            }
        } else {
            try? data.write(to: fileURL)
        }
    }
    
    private func loadSessionLogs() {
        guard let fileURL = logFileURL,
              FileManager.default.fileExists(atPath: fileURL.path) else { return }
        
        // Only load if file was modified recently (within 1 hour)
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let modDate = attrs[.modificationDate] as? Date,
              Date().timeIntervalSince(modDate) < 3600 else { return }
        
        // For simplicity, we just start fresh each session
        // The file exists for historical reference
    }
    
    private func cleanupOldLogs() {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        
        let logsDir = documentsDir.appendingPathComponent("Logs", isDirectory: true)
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: logsDir.path) else { return }
        
        // Keep only last 7 days of logs
        let logFiles = files.filter { $0.hasPrefix("app-") && $0.hasSuffix(".log") }
            .sorted()
            .reversed()
        
        let filesToKeep = 7
        if logFiles.count > filesToKeep {
            for file in logFiles.dropFirst(filesToKeep) {
                try? FileManager.default.removeItem(at: logsDir.appendingPathComponent(file))
            }
        }
    }
    
    // MARK: - Log Management
    
    func clearLogs() {
        logs.removeAll()
    }
    
    func getAvailableLogDates() -> [String] {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return [] }
        
        let logsDir = documentsDir.appendingPathComponent("Logs", isDirectory: true)
        
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: logsDir.path) else { return [] }
        
        return files
            .filter { $0.hasPrefix("app-") && $0.hasSuffix(".log") }
            .compactMap { file -> String? in
                let name = file.replacingOccurrences(of: "app-", with: "").replacingOccurrences(of: ".log", with: "")
                return name
            }
            .sorted()
            .reversed()
            .map { $0 }
    }
    
    func getLogsForDate(_ date: String) -> String {
        guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return "" }
        
        let logsDir = documentsDir.appendingPathComponent("Logs", isDirectory: true)
        let fileURL = logsDir.appendingPathComponent("app-\(date).log")
        
        return (try? String(contentsOf: fileURL, encoding: .utf8)) ?? ""
    }
    
    /// Export all logs as a string for sharing
    func exportLogs() -> String {
        var output = "Napp Trapp Logs - \(Date())\n"
        output += "=".repeated(50) + "\n\n"
        
        for entry in logs.reversed() {
            output += "[\(entry.fullTimestamp)] [\(entry.level.rawValue.uppercased())] [\(entry.category)]\n"
            output += "  \(entry.message)\n"
            if let data = entry.data {
                output += "  Data: \(data)\n"
            }
            output += "\n"
        }
        
        return output
    }
}

// Helper extension
private extension String {
    func repeated(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}
