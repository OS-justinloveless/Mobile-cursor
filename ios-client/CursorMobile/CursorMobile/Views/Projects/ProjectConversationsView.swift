import SwiftUI

/// View that lists chat windows (tmux windows running AI CLIs) for a project
struct ProjectConversationsView: View {
    @EnvironmentObject var authManager: AuthManager
    
    let project: Project
    
    @State private var chats: [ChatWindow] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var searchText = ""
    @State private var showNewChatSheet = false
    
    // Navigation state for terminal
    @State private var selectedTerminalId: String?
    @State private var selectedProjectPath: String?
    
    /// Filter chats by search text
    private var filteredChats: [ChatWindow] {
        guard !searchText.isEmpty else { return chats }
        let lowercasedSearch = searchText.lowercased()
        return chats.filter { chat in
            chat.windowName.lowercased().contains(lowercasedSearch) ||
            chat.tool.lowercased().contains(lowercasedSearch) ||
            chat.displayTitle.lowercased().contains(lowercasedSearch)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            if !chats.isEmpty {
                searchBar
            }
            
            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading chats...")
                Spacer()
            } else if let error = error {
                Spacer()
                ErrorView(message: error) {
                    loadChats()
                }
                Spacer()
            } else if chats.isEmpty {
                emptyStateWithNewChat
            } else if filteredChats.isEmpty {
                filteredEmptyState
            } else {
                chatsList
            }
        }
        .navigationDestination(item: $selectedTerminalId) { terminalId in
            if let projectPath = selectedProjectPath {
                TerminalView(terminalId: terminalId, projectPath: projectPath)
            }
        }
        .sheet(isPresented: $showNewChatSheet) {
            NewChatSheet(project: project) { terminalId, projectPath in
                // Navigate to terminal view for the new chat
                selectedTerminalId = terminalId
                selectedProjectPath = projectPath
                // Refresh the list in the background so it's ready when user returns
                loadChats()
            }
        }
        .onAppear {
            // Always refresh when view appears (user might be returning from terminal)
            loadChats()
        }
        .onChange(of: project.id) { _, _ in
            // Reset state when project changes
            chats = []
            selectedTerminalId = nil
            selectedProjectPath = nil
            isLoading = true
            error = nil
            searchText = ""
            loadChats()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        showNewChatSheet = true
                    } label: {
                        Image(systemName: "plus.bubble")
                    }
                    
                    Button {
                        loadChats()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search chats...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var filteredEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Results")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("No chats match your search.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
        .padding()
    }
    
    private var emptyStateWithNewChat: some View {
        VStack(spacing: 20) {
            EmptyStateView(
                icon: "bubble.left.and.bubble.right",
                title: "No Chat Windows",
                message: "Start a new AI chat session for this project"
            )
            
            Button {
                showNewChatSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus.bubble.fill")
                    Text("New Chat")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .cornerRadius(12)
            }
        }
    }
    
    private var chatsList: some View {
        List {
            // Show filter status if active
            if !searchText.isEmpty {
                HStack {
                    Text("Showing \(filteredChats.count) of \(chats.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            
            ForEach(filteredChats) { chat in
                ChatWindowRow(chat: chat) {
                    selectedTerminalId = chat.id
                    selectedProjectPath = chat.projectPath
                }
            }
            .onDelete(perform: deleteChats)
        }
        .refreshable {
            await refreshChats()
        }
    }
    
    private func loadChats() {
        isLoading = true
        error = nil
        
        Task {
            await refreshChats()
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func refreshChats() async {
        guard let api = authManager.createAPIService() else {
            await MainActor.run {
                error = "Not authenticated"
            }
            return
        }
        
        do {
            let fetchedChats = try await api.getChats(projectPath: project.path)
            await MainActor.run {
                chats = fetchedChats
                error = nil
            }
            print("[ProjectConversationsView] Fetched \(fetchedChats.count) chat windows")
        } catch {
            await MainActor.run {
                if chats.isEmpty {
                    self.error = error.localizedDescription
                } else {
                    print("[ProjectConversationsView] Failed to refresh chats: \(error)")
                }
            }
        }
    }
    
    private func deleteChats(at offsets: IndexSet) {
        guard let api = authManager.createAPIService() else { return }
        
        let chatsToDelete = offsets.map { filteredChats[$0] }
        
        Task {
            for chat in chatsToDelete {
                do {
                    try await api.deleteChatWindow(terminalId: chat.id)
                    await MainActor.run {
                        chats.removeAll { $0.id == chat.id }
                    }
                } catch {
                    print("[ProjectConversationsView] Failed to delete chat \(chat.id): \(error)")
                }
            }
        }
    }
}

// MARK: - Chat Window Row (uses ChatWindow from Conversation.swift)

struct ChatWindowRow: View {
    let chat: ChatWindow
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Tool icon
                ZStack {
                    Circle()
                        .fill(toolColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: chat.toolIcon)
                        .font(.title3)
                        .foregroundColor(toolColor)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(chat.displayTitle)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        // Tool badge
                        Text(toolName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(toolColor.opacity(0.15))
                            .foregroundColor(toolColor)
                            .cornerRadius(4)
                        
                        // Window name
                        Text(chat.windowName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Status indicator
                Circle()
                    .fill(chat.active ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private var toolColor: Color {
        chat.toolEnum?.color ?? .gray
    }
    
    private var toolName: String {
        chat.toolEnum?.displayName ?? chat.tool
    }
}

#Preview {
    NavigationStack {
        ProjectConversationsView(project: Project(id: "test", name: "Test Project", path: "/path/to/project"))
    }
    .environmentObject(AuthManager())
}
