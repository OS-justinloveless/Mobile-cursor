import SwiftUI

/// List of chat windows with create/delete/clone actions
struct ChatListView: View {
    let project: Project
    @Binding var selectedChat: ChatWindow?
    @Binding var showNewChatSheet: Bool

    @EnvironmentObject var chatManager: ChatManager

    @State private var showManagementSheet = false
    @State private var chatToManage: ChatWindow?
    @State private var showDeleteConfirmation = false
    @State private var chatToDelete: ChatWindow?

    var body: some View {
        Group {
            if chatManager.isLoadingChats && chatManager.chats.isEmpty {
                loadingView
            } else if chatManager.chats.isEmpty {
                emptyStateView
            } else {
                chatsList
            }
        }
        .refreshable {
            await chatManager.fetchChats(projectPath: project.path)
        }
        .confirmationDialog(
            "Delete Chat",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let chat = chatToDelete {
                    deleteChat(chat)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete this chat and its history.")
        }
        .sheet(item: $chatToManage) { chat in
            ConversationManagementSheet(chat: chat, project: project)
                .environmentObject(chatManager)
        }
    }

    // MARK: - Subviews

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading chats...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("No Chats Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Start a conversation with an AI assistant")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showNewChatSheet = true
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("New Chat")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .cornerRadius(12)
            }

            Spacer()
        }
        .padding()
    }

    private var chatsList: some View {
        List {
            // Show chats chronologically
            ForEach(sortedChats) { chat in
                ChatRowView(chat: chat)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedChat = chat
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            chatToDelete = chat
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            chatToManage = chat
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                        .tint(.blue)
                    }
                    .contextMenu {
                        Button {
                            selectedChat = chat
                        } label: {
                            Label("Open", systemImage: "bubble.left")
                        }

                        Button {
                            chatToManage = chat
                        } label: {
                            Label("Manage", systemImage: "ellipsis.circle")
                        }

                        Divider()

                        Button(role: .destructive) {
                            chatToDelete = chat
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Helpers

    /// Sort chats chronologically by timestamp (newest first)
    private var sortedChats: [ChatWindow] {
        chatManager.chats.sorted { chat1, chat2 in
            let timestamp1 = chat1.timestamp ?? chat1.createdAt ?? 0
            let timestamp2 = chat2.timestamp ?? chat2.createdAt ?? 0
            return timestamp1 > timestamp2
        }
    }

    private func deleteChat(_ chat: ChatWindow) {
        Task {
            do {
                try await chatManager.deleteChat(
                    terminalId: chat.effectiveTerminalId,
                    projectPath: project.path
                )
            } catch {
                print("[ChatListView] Failed to delete chat: \(error)")
            }
        }
    }
}

// MARK: - Chat Row View

struct ChatRowView: View {
    let chat: ChatWindow

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(chat.displayTitle)
                    .font(.body)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    // Agent tag
                    HStack(spacing: 4) {
                        Image(systemName: chat.toolIcon)
                            .font(.caption2)
                        Text(agentDisplayName)
                            .font(.caption2)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(toolColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(toolColor.opacity(0.15))
                    .cornerRadius(6)

                    if chat.isActive {
                        Text("Active")
                            .font(.caption2)
                            .foregroundColor(.green)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    }

                    if let timestamp = chat.timestamp {
                        Text(formatDate(timestamp))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    private var toolColor: Color {
        switch chat.tool.lowercased() {
        case "claude": return .purple
        case "cursor-agent": return .blue
        case "gemini": return .orange
        default: return .secondary
        }
    }

    private var agentDisplayName: String {
        switch chat.tool.lowercased() {
        case "claude": return "Claude"
        case "cursor-agent": return "Cursor"
        case "gemini": return "Gemini"
        default: return chat.tool.capitalized
        }
    }

    private func formatDate(_ timestamp: Double) -> String {
        let date = Date(timeIntervalSince1970: timestamp / 1000.0)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NavigationStack {
        ChatListView(
            project: Project(
                id: "test",
                name: "Test Project",
                path: "/test/path",
                lastOpened: Date()
            ),
            selectedChat: .constant(nil),
            showNewChatSheet: .constant(false)
        )
        .environmentObject(ChatManager())
    }
}
