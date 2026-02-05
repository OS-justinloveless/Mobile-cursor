import SwiftUI

/// Displays chat windows (tmux windows running AI CLIs)
/// Chats are now simply tmux windows in project sessions
struct ConversationsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var webSocketManager: WebSocketManager
    
    @State private var chats: [ChatWindow] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedTerminalId: String?
    @State private var selectedProjectPath: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading chats...")
                } else if let error = error {
                    ErrorView(message: error) {
                        loadChats()
                    }
                } else if chats.isEmpty {
                    EmptyStateView(
                        icon: "terminal",
                        title: "No Chat Windows",
                        message: "Create a new chat from a project to start an AI conversation"
                    )
                } else {
                    chatsList
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        loadChats()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { selectedTerminalId != nil },
                set: { if !$0 { selectedTerminalId = nil; selectedProjectPath = nil } }
            )) {
                if let terminalId = selectedTerminalId, let projectPath = selectedProjectPath {
                    TerminalView(terminalId: terminalId, projectPath: projectPath)
                }
            }
        }
        .onAppear {
            // Always refresh when view appears (user might be returning from terminal)
            loadChats()
        }
    }
    
    private var chatsList: some View {
        List {
            ForEach(chats) { chat in
                ChatWindowRow(chat: chat) {
                    selectedTerminalId = chat.effectiveTerminalId
                    selectedProjectPath = chat.projectPath
                }
            }
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
            let fetchedChats = try await api.getChats()
            await MainActor.run {
                chats = fetchedChats
                error = nil
            }
        } catch {
            await MainActor.run {
                if chats.isEmpty {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

// ChatWindowRow is defined in ProjectConversationsView.swift

#Preview {
    ConversationsView()
        .environmentObject(AuthManager())
        .environmentObject(WebSocketManager())
}
