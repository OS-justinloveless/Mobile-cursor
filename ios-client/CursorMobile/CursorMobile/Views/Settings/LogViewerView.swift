import SwiftUI

/// View for displaying and filtering app and server logs
struct LogViewerView: View {
    @EnvironmentObject var authManager: AuthManager
    @ObservedObject var logManager = LogManager.shared
    
    // Filter state
    @State private var selectedLogType: LogSourceType = .app
    @State private var selectedLevel: LogLevel? = nil
    @State private var categoryFilter: String = ""
    @State private var isLoading = false
    @State private var error: String?
    
    // Server logs state
    @State private var serverLogs: [ServerLogEntry] = []
    @State private var serverLogDates: [String] = []
    @State private var selectedServerDate: String? = nil
    
    // Export/Share
    @State private var showShareSheet = false
    @State private var exportedContent: String = ""
    
    enum LogSourceType: String, CaseIterable, Identifiable {
        case app = "App"
        case server = "Server"
        
        var id: String { rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Source and filter bar
            filterBar
            
            Divider()
            
            // Log content
            if isLoading {
                Spacer()
                ProgressView("Loading logs...")
                Spacer()
            } else if let error = error {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        loadLogs()
                    }
                }
                .padding()
                Spacer()
            } else {
                logList
            }
        }
        .navigationTitle("Logs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        exportLogs()
                    } label: {
                        Label("Export Logs", systemImage: "square.and.arrow.up")
                    }
                    
                    Button {
                        loadLogs()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    
                    if selectedLogType == .app {
                        Button(role: .destructive) {
                            logManager.clearLogs()
                        } label: {
                            Label("Clear App Logs", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [exportedContent])
        }
        .onAppear {
            loadLogs()
        }
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        VStack(spacing: 8) {
            // Log source picker
            Picker("Source", selection: $selectedLogType) {
                ForEach(LogSourceType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: selectedLogType) { _, _ in
                loadLogs()
            }
            
            HStack(spacing: 8) {
                // Level filter
                Menu {
                    Button {
                        selectedLevel = nil
                    } label: {
                        HStack {
                            Text("All Levels")
                            if selectedLevel == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Divider()
                    
                    ForEach(LogLevel.allCases, id: \.rawValue) { level in
                        Button {
                            selectedLevel = level
                        } label: {
                            HStack {
                                Text("\(level.emoji) \(level.rawValue.capitalized)")
                                if selectedLevel == level {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text(selectedLevel?.rawValue.capitalized ?? "All")
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                }
                
                // Category filter
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    
                    TextField("Category", text: $categoryFilter)
                        .font(.caption)
                        .textFieldStyle(.plain)
                    
                    if !categoryFilter.isEmpty {
                        Button {
                            categoryFilter = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)
                
                // Server date picker (only for server logs)
                if selectedLogType == .server && !serverLogDates.isEmpty {
                    Menu {
                        Button {
                            selectedServerDate = nil
                            loadLogs()
                        } label: {
                            HStack {
                                Text("Latest")
                                if selectedServerDate == nil {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                        
                        Divider()
                        
                        ForEach(serverLogDates, id: \.self) { date in
                            Button {
                                selectedServerDate = date
                                loadLogs()
                            } label: {
                                HStack {
                                    Text(date)
                                    if selectedServerDate == date {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                            Text(selectedServerDate ?? "Latest")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Log List
    
    private var logList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                if selectedLogType == .app {
                    let filtered = filteredAppLogs
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        ForEach(filtered) { entry in
                            AppLogEntryRow(entry: entry)
                        }
                    }
                } else {
                    let filtered = filteredServerLogs
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        ForEach(filtered) { entry in
                            ServerLogEntryRow(entry: entry)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            Text("No logs found")
                .font(.subheadline)
                .foregroundColor(.secondary)
            if selectedLevel != nil || !categoryFilter.isEmpty {
                Text("Try adjusting your filters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Filtered Logs
    
    private var filteredAppLogs: [LogEntry] {
        logManager.getFilteredLogs(
            level: selectedLevel,
            category: categoryFilter.isEmpty ? nil : categoryFilter,
            limit: 500
        )
    }
    
    private var filteredServerLogs: [ServerLogEntry] {
        var logs = serverLogs
        
        if let level = selectedLevel {
            logs = logs.filter { $0.logLevel.priority >= level.priority }
        }
        
        if !categoryFilter.isEmpty {
            logs = logs.filter { $0.category.localizedCaseInsensitiveContains(categoryFilter) }
        }
        
        return logs
    }
    
    // MARK: - Data Loading
    
    private func loadLogs() {
        if selectedLogType == .server {
            loadServerLogs()
        }
        // App logs are already managed by LogManager
    }
    
    private func loadServerLogs() {
        isLoading = true
        error = nil
        
        Task {
            guard let api = authManager.createAPIService() else {
                await MainActor.run {
                    error = "Not authenticated"
                    isLoading = false
                }
                return
            }
            
            do {
                // Load available dates
                let dates = try await api.getServerLogDates()
                
                // Load logs
                let logs: [ServerLogEntry]
                if let date = selectedServerDate {
                    logs = try await api.getServerLogsForDate(date, limit: 300)
                } else {
                    logs = try await api.getServerLogs(limit: 300)
                }
                
                await MainActor.run {
                    serverLogDates = dates
                    serverLogs = logs
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    // MARK: - Export
    
    private func exportLogs() {
        if selectedLogType == .app {
            exportedContent = logManager.exportLogs()
        } else {
            var output = "Server Logs - \(Date())\n"
            output += String(repeating: "=", count: 50) + "\n\n"
            
            for entry in filteredServerLogs {
                output += "[\(entry.timestamp)] [\(entry.level.uppercased())] [\(entry.category)]\n"
                output += "  \(entry.message)\n"
                if let data = entry.formattedData {
                    output += "  Data: \(data)\n"
                }
                output += "\n"
            }
            
            exportedContent = output
        }
        
        showShareSheet = true
    }
}

// MARK: - App Log Entry Row

private struct AppLogEntryRow: View {
    let entry: LogEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Text(entry.level.emoji)
                    .font(.caption)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.category)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(levelColor)
                        
                        Spacer()
                        
                        Text(entry.formattedTimestamp)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(entry.message)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(isExpanded ? nil : 2)
                }
            }
            
            if let data = entry.data, !data.isEmpty {
                if isExpanded {
                    Text(data)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                        .padding(.top, 4)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
    
    private var levelColor: Color {
        switch entry.level {
        case .debug: return .gray
        case .info: return .blue
        case .warn: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Server Log Entry Row

private struct ServerLogEntryRow: View {
    let entry: ServerLogEntry
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Text(entry.logLevel.emoji)
                    .font(.caption)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.category)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(levelColor)
                        
                        Spacer()
                        
                        Text(entry.formattedTimestamp)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(entry.message)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(isExpanded ? nil : 2)
                }
            }
            
            if let data = entry.formattedData, !data.isEmpty {
                if isExpanded {
                    Text(data)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.leading, 24)
                        .padding(.top, 4)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
    
    private var levelColor: Color {
        switch entry.logLevel {
        case .debug: return .gray
        case .info: return .blue
        case .warn: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        LogViewerView()
            .environmentObject(AuthManager())
    }
}
