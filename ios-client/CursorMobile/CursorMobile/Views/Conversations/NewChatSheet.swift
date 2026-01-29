import SwiftUI

/// Sheet for creating a new chat conversation with an initial message
struct NewChatSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @State private var message = ""
    @State private var isCreating = false
    @State private var error: String?
    
    @FocusState private var isMessageFocused: Bool
    
    let project: Project
    let onChatCreated: (String, String) -> Void  // (chatId, initialMessage)
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Message input area
                TextEditor(text: $message)
                    .focused($isMessageFocused)
                    .padding()
                    .scrollContentBackground(.hidden)
                    .background(Color(.systemBackground))
                
                // Error message if any
                if let error = error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .background(Color(.systemBackground))
                }
                
                Divider()
                
                // Bottom bar with project info
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.secondary)
                    Text(project.name)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemBackground))
            }
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
                
                ToolbarItem(placement: .primaryAction) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("Send") {
                            createChat()
                        }
                        .fontWeight(.semibold)
                        .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .interactiveDismissDisabled(isCreating)
        }
        .onAppear {
            isMessageFocused = true
        }
    }
    
    private func createChat() {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        isCreating = true
        error = nil
        
        Task {
            guard let api = authManager.createAPIService() else {
                await MainActor.run {
                    error = "Not authenticated"
                    isCreating = false
                }
                return
            }
            
            do {
                // Create the conversation
                let chatId = try await api.createConversation(workspaceId: project.id)
                
                await MainActor.run {
                    isCreating = false
                    dismiss()
                    // Pass both chatId and the initial message to be sent
                    onChatCreated(chatId, trimmedMessage)
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to create chat: \(error.localizedDescription)"
                    isCreating = false
                }
            }
        }
    }
}

#Preview {
    NewChatSheet(
        project: Project(
            id: "test-project",
            name: "Test Project",
            path: "/path/to/project",
            lastOpened: Date()
        ),
        onChatCreated: { _, _ in }
    )
    .environmentObject(AuthManager())
}
