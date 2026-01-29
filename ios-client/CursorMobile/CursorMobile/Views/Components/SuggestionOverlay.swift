import SwiftUI

/// Overlay view that shows autocomplete suggestions for @ and / triggers
struct SuggestionOverlay: View {
    let suggestions: [Suggestion]
    let query: String
    let triggerType: TriggerType
    let onSelect: (Suggestion) -> Void
    let onDismiss: () -> Void
    
    /// Suggestions filtered by trigger type and query
    var filteredSuggestions: [Suggestion] {
        let filtered = suggestions.filter { suggestion in
            // Filter by trigger type (@ vs /)
            if triggerType == .slash && suggestion.type != .command {
                return false
            }
            if triggerType == .at && suggestion.type == .command {
                return false
            }
            
            // Filter by query
            if query.isEmpty {
                return true
            }
            let lowerQuery = query.lowercased()
            return suggestion.name.lowercased().contains(lowerQuery) ||
                   (suggestion.description?.lowercased().contains(lowerQuery) ?? false)
        }
        return Array(filtered.prefix(8)) // Limit to 8 results
    }
    
    /// Group suggestions by type for display
    var groupedSuggestions: [(type: SuggestionType, items: [Suggestion])] {
        let grouped = Dictionary(grouping: filteredSuggestions) { $0.type }
        
        // Sort groups by type priority
        let order: [SuggestionType] = [.command, .rule, .agent, .skill, .file]
        return order.compactMap { type in
            if let items = grouped[type], !items.isEmpty {
                return (type: type, items: items)
            }
            return nil
        }
    }
    
    var body: some View {
        if !filteredSuggestions.isEmpty {
            VStack(spacing: 0) {
                // Header with dismiss button
                HStack {
                    Text(triggerType == .slash ? "Commands" : "Mentions")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                Divider()
                
                // Suggestions list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groupedSuggestions, id: \.type) { group in
                            if groupedSuggestions.count > 1 {
                                // Show section header if multiple types
                                HStack {
                                    Text(group.type.displayName)
                                        .font(.caption2)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color(.tertiarySystemBackground))
                            }
                            
                            ForEach(group.items) { suggestion in
                                SuggestionRow(
                                    suggestion: suggestion,
                                    query: query,
                                    onSelect: onSelect
                                )
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
            }
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: -4)
        }
    }
}

/// Individual suggestion row
struct SuggestionRow: View {
    let suggestion: Suggestion
    let query: String
    let onSelect: (Suggestion) -> Void
    
    var body: some View {
        Button {
            onSelect(suggestion)
        } label: {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: suggestion.icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                
                // Name and description
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(suggestion.triggerPrefix)
                            .foregroundColor(.secondary)
                        
                        // Highlight matching query
                        highlightedName
                    }
                    .font(.system(size: 15, weight: .medium))
                    
                    if let subtitle = suggestion.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Scope badge for agents
                if let scope = suggestion.scope {
                    Text(scope)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.tertiarySystemFill))
                        .cornerRadius(4)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(.secondarySystemBackground))
    }
    
    /// Color for the suggestion icon based on type
    var iconColor: Color {
        switch suggestion.type {
        case .rule:
            return .orange
        case .file:
            return .blue
        case .skill:
            return .purple
        case .agent:
            return .green
        case .command:
            return .cyan
        }
    }
    
    /// Highlight the matching part of the name
    var highlightedName: Text {
        let name = suggestion.name
        guard !query.isEmpty else {
            return Text(name).foregroundColor(.primary)
        }
        
        let lowerName = name.lowercased()
        let lowerQuery = query.lowercased()
        
        if let range = lowerName.range(of: lowerQuery) {
            let startIndex = lowerName.distance(from: lowerName.startIndex, to: range.lowerBound)
            let endIndex = lowerName.distance(from: lowerName.startIndex, to: range.upperBound)
            
            let before = String(name.prefix(startIndex))
            let match = String(name.dropFirst(startIndex).prefix(endIndex - startIndex))
            let after = String(name.dropFirst(endIndex))
            
            return Text(before).foregroundColor(.primary) +
                   Text(match).foregroundColor(.accentColor).bold() +
                   Text(after).foregroundColor(.primary)
        }
        
        return Text(name).foregroundColor(.primary)
    }
}

/// Empty state when no suggestions match
struct NoSuggestionsView: View {
    let query: String
    let triggerType: TriggerType
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("No \(triggerType == .slash ? "commands" : "matches") found")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !query.isEmpty {
                Text("for \"\(query)\"")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack {
        Spacer()
        
        SuggestionOverlay(
            suggestions: [
                Suggestion(id: "rule:server", type: .rule, name: "server-management", description: "Agent must not start or stop the server"),
                Suggestion(id: "agent:researcher", type: .agent, name: "researcher", description: "Research specialist", scope: "project"),
                Suggestion(id: "command:query", type: .command, name: "query", description: "Query the codebase"),
                Suggestion(id: "skill:create-rule", type: .skill, name: "create-rule", description: "Create Cursor rules")
            ],
            query: "ser",
            triggerType: .at,
            onSelect: { print("Selected: \($0.name)") },
            onDismiss: { print("Dismissed") }
        )
        .padding()
    }
    .background(Color(.systemBackground))
}
