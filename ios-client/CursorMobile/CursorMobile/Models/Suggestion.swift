import Foundation

/// Types of suggestions available for @ and / autocomplete
enum SuggestionType: String, Codable, CaseIterable {
    case rule
    case file
    case skill
    case agent
    case command
    
    /// Display name for grouping in UI
    var displayName: String {
        switch self {
        case .rule: return "Rules"
        case .file: return "Files"
        case .skill: return "Skills"
        case .agent: return "Agents"
        case .command: return "Commands"
        }
    }
}

/// Trigger type for suggestion detection
enum TriggerType: Equatable {
    case at      // @ - for rules, files, skills, agents
    case slash   // / - for commands
    
    var character: Character {
        switch self {
        case .at: return "@"
        case .slash: return "/"
        }
    }
    
    var prefix: String {
        String(character)
    }
}

/// A suggestion item for autocomplete
struct Suggestion: Identifiable, Codable, Equatable {
    let id: String
    let type: SuggestionType
    let name: String
    let description: String?
    let path: String?
    let relativePath: String?
    let scope: String?         // "project" or "user" for agents
    let alwaysApply: Bool?     // For rules
    let globs: String?         // For rules
    let model: String?         // For agents
    let readonly: Bool?        // For agents
    
    /// SF Symbol icon name for this suggestion type
    var icon: String {
        switch type {
        case .rule: return "doc.text.fill"
        case .file: return "doc.fill"
        case .skill: return "wand.and.stars"
        case .agent: return "person.circle.fill"
        case .command: return "terminal.fill"
        }
    }
    
    /// The trigger prefix for this suggestion type
    var triggerPrefix: String {
        type == .command ? "/" : "@"
    }
    
    /// Text to insert when this suggestion is selected
    var insertText: String {
        "\(triggerPrefix)\(name) "
    }
    
    /// Display subtitle combining description and path info
    var subtitle: String? {
        if let desc = description, !desc.isEmpty {
            return desc
        }
        if let relPath = relativePath {
            return relPath
        }
        return nil
    }
    
    // Coding keys to handle optional fields
    enum CodingKeys: String, CodingKey {
        case id, type, name, description, path, relativePath, scope
        case alwaysApply, globs, model, readonly
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        type = try container.decode(SuggestionType.self, forKey: .type)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        path = try container.decodeIfPresent(String.self, forKey: .path)
        relativePath = try container.decodeIfPresent(String.self, forKey: .relativePath)
        scope = try container.decodeIfPresent(String.self, forKey: .scope)
        alwaysApply = try container.decodeIfPresent(Bool.self, forKey: .alwaysApply)
        globs = try container.decodeIfPresent(String.self, forKey: .globs)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        readonly = try container.decodeIfPresent(Bool.self, forKey: .readonly)
    }
    
    init(
        id: String,
        type: SuggestionType,
        name: String,
        description: String? = nil,
        path: String? = nil,
        relativePath: String? = nil,
        scope: String? = nil,
        alwaysApply: Bool? = nil,
        globs: String? = nil,
        model: String? = nil,
        readonly: Bool? = nil
    ) {
        self.id = id
        self.type = type
        self.name = name
        self.description = description
        self.path = path
        self.relativePath = relativePath
        self.scope = scope
        self.alwaysApply = alwaysApply
        self.globs = globs
        self.model = model
        self.readonly = readonly
    }
}

/// Response from the suggestions API
struct SuggestionsResponse: Codable {
    let suggestions: [Suggestion]
    let total: Int?
    let projectPath: String?
}
