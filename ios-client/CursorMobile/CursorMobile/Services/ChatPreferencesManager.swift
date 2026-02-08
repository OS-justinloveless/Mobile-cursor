import Foundation
import SwiftUI

/// Manages persistent user preferences for new chat creation
class ChatPreferencesManager {
    static let shared = ChatPreferencesManager()

    private let defaults = UserDefaults.standard

    // Keys for UserDefaults
    private enum Keys {
        static let lastAgentId = "lastSelectedAgentId"
        static let lastModelId = "lastSelectedModelId"
        static let lastMode = "lastSelectedMode"
        static let lastPermissionMode = "lastSelectedPermissionMode"
    }

    private init() {}

    // MARK: - Save Preferences

    func savePreferences(
        agentId: String?,
        modelId: String?,
        mode: ChatMode,
        permissionMode: PermissionMode
    ) {
        if let agentId = agentId {
            defaults.set(agentId, forKey: Keys.lastAgentId)
        }
        if let modelId = modelId {
            defaults.set(modelId, forKey: Keys.lastModelId)
        }
        defaults.set(mode.rawValue, forKey: Keys.lastMode)
        defaults.set(permissionMode.rawValue, forKey: Keys.lastPermissionMode)
    }

    // MARK: - Load Preferences

    func lastAgentId() -> String? {
        return defaults.string(forKey: Keys.lastAgentId)
    }

    func lastModelId() -> String? {
        return defaults.string(forKey: Keys.lastModelId)
    }

    func lastMode() -> ChatMode? {
        guard let rawValue = defaults.string(forKey: Keys.lastMode) else {
            return nil
        }
        return ChatMode(rawValue: rawValue)
    }

    func lastPermissionMode() -> PermissionMode? {
        guard let rawValue = defaults.string(forKey: Keys.lastPermissionMode) else {
            return nil
        }
        return PermissionMode(rawValue: rawValue)
    }

    // MARK: - Clear Preferences

    func clearAllPreferences() {
        defaults.removeObject(forKey: Keys.lastAgentId)
        defaults.removeObject(forKey: Keys.lastModelId)
        defaults.removeObject(forKey: Keys.lastMode)
        defaults.removeObject(forKey: Keys.lastPermissionMode)
    }
}
