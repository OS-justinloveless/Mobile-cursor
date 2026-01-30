import SwiftUI

/// Sheet for creating a new chat conversation with an initial message
struct NewChatSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    @State private var message = ""
    @State private var isCreating = false
    @State private var error: String?
    
    // Model and mode selection
    @State private var availableModels: [AIModel] = []
    @State private var isLoadingModels = true
    @State private var selectedModelId: String? = nil
    @State private var selectedMode: ChatMode
    @State private var showOptions = false

    // Tool selection
    @State private var selectedTool: ChatTool = .cursorAgent
    @State private var toolAvailability: [ChatTool: Bool] = [:]
    @State private var isLoadingTools = true

    @FocusState private var isMessageFocused: Bool

    let project: Project
    let onChatCreated: (String, String, String?, ChatMode) -> Void  // (chatId, initialMessage, model, mode)
    
    init(project: Project, onChatCreated: @escaping (String, String, String?, ChatMode) -> Void) {
        self.project = project
        self.onChatCreated = onChatCreated
        // Initialize with defaults from ChatSettingsManager
        let settings = ChatSettingsManager.shared
        _selectedMode = State(initialValue: settings.defaultMode)
        _selectedModelId = State(initialValue: settings.defaultModelId)
    }
    
    /// Selected model object based on selectedModelId
    private var selectedModel: AIModel? {
        if let id = selectedModelId {
            return availableModels.first { $0.id == id }
        }
        return availableModels.first { $0.isCurrent } ?? availableModels.first { $0.isDefault } ?? availableModels.first
    }
    
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
                
                // Options section (collapsible)
                VStack(spacing: 0) {
                    // Options header
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showOptions.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gearshape")
                                .foregroundColor(.secondary)
                            Text("Options")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: showOptions ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                    }
                    .buttonStyle(.plain)
                    
                    // Options content (when expanded)
                    if showOptions {
                        VStack(spacing: 12) {
                            // Tool picker
                            HStack {
                                Text("Tool")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if isLoadingTools {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Menu {
                                        ForEach(ChatTool.allCases) { tool in
                                            Button {
                                                if toolAvailability[tool] != false {
                                                    selectedTool = tool
                                                }
                                            } label: {
                                                HStack {
                                                    Image(systemName: tool.icon)
                                                    Text(tool.displayName)
                                                    if toolAvailability[tool] == false {
                                                        Text("(unavailable)")
                                                            .foregroundColor(.secondary)
                                                    }
                                                    if selectedTool == tool {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                            .disabled(toolAvailability[tool] == false)
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: selectedTool.icon)
                                                .font(.caption)
                                                .foregroundColor(selectedTool.color)
                                            Text(selectedTool.displayName)
                                                .font(.subheadline)
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.primary)
                                    }
                                }
                            }
                            .padding(.horizontal)

                            // Model picker
                            HStack {
                                Text("Model")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if isLoadingModels {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Menu {
                                        ForEach(availableModels) { model in
                                            Button {
                                                selectedModelId = model.id
                                            } label: {
                                                HStack {
                                                    Text(model.name)
                                                    if model.isDefault {
                                                        Text("(default)")
                                                            .foregroundColor(.secondary)
                                                    }
                                                    if model.isCurrent {
                                                        Text("(current)")
                                                            .foregroundColor(.secondary)
                                                    }
                                                    if selectedModelId == model.id || (selectedModelId == nil && model == selectedModel) {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Text(selectedModel?.name ?? "Select Model")
                                                .font(.subheadline)
                                            Image(systemName: "chevron.up.chevron.down")
                                                .font(.caption2)
                                        }
                                        .foregroundColor(.primary)
                                    }
                                }
                            }
                            .padding(.horizontal)

                            // Mode picker (segmented)
                            HStack {
                                Text("Mode")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Picker("Mode", selection: $selectedMode) {
                                    ForEach(ChatMode.allCases) { mode in
                                        Text(mode.displayName).tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .fixedSize()
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 12)
                        .background(Color(.secondarySystemBackground))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
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
            loadModels()
            loadToolAvailability()
        }
    }

    private func loadToolAvailability() {
        Task {
            guard let api = authManager.createAPIService() else {
                await MainActor.run {
                    isLoadingTools = false
                }
                return
            }

            do {
                let availability = try await api.getToolAvailability()
                await MainActor.run {
                    toolAvailability = availability
                    // If current selection is unavailable, switch to first available tool
                    if toolAvailability[selectedTool] == false {
                        if let firstAvailable = ChatTool.allCases.first(where: { toolAvailability[$0] != false }) {
                            selectedTool = firstAvailable
                        }
                    }
                    isLoadingTools = false
                }
            } catch {
                await MainActor.run {
                    // Default to cursor-agent if we can't check availability
                    isLoadingTools = false
                    print("[NewChatSheet] Failed to load tool availability: \(error)")
                }
            }
        }
    }

    private func loadModels() {
        Task {
            guard let api = authManager.createAPIService() else {
                await MainActor.run {
                    isLoadingModels = false
                }
                return
            }
            
            do {
                let models = try await api.getAvailableModels()
                await MainActor.run {
                    availableModels = models
                    // Priority for initial model selection:
                    // 1. User's saved default from settings (already set in init)
                    // 2. Current model from server
                    // 3. Server's default model
                    if selectedModelId == nil {
                        if let current = models.first(where: { $0.isCurrent }) {
                            selectedModelId = current.id
                        } else if let defaultModel = models.first(where: { $0.isDefault }) {
                            selectedModelId = defaultModel.id
                        }
                    }
                    isLoadingModels = false
                }
            } catch {
                await MainActor.run {
                    // Silently fail - user can still create chat without model selection
                    isLoadingModels = false
                    print("[NewChatSheet] Failed to load models: \(error)")
                }
            }
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
                // Create the conversation with tool, model, and mode
                let chatId = try await api.createConversation(
                    workspaceId: project.id,
                    model: selectedModelId,
                    mode: selectedMode,
                    tool: selectedTool.rawValue
                )
                
                await MainActor.run {
                    isCreating = false
                    dismiss()
                    // Pass chatId, initial message, model, and mode
                    onChatCreated(chatId, trimmedMessage, selectedModelId, selectedMode)
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
        onChatCreated: { _, _, _, _ in }
    )
    .environmentObject(AuthManager())
}
