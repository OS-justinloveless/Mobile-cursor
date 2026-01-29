import Foundation

/// Settings for filtering, sorting, and searching git repositories
struct GitFilterSettings: Codable, Equatable {
    
    // MARK: - Sort Options
    
    enum SortOption: String, CaseIterable, Codable {
        case alphabetical = "alphabetical"
        case chronological = "chronological"
        case changeCount = "changeCount"
        
        var displayName: String {
            switch self {
            case .alphabetical: return "A-Z"
            case .chronological: return "Recent"
            case .changeCount: return "Changes"
            }
        }
        
        var icon: String {
            switch self {
            case .alphabetical: return "textformat.abc"
            case .chronological: return "clock"
            case .changeCount: return "number"
            }
        }
    }
    
    // MARK: - Properties
    
    /// Current sort option
    var sortOption: SortOption = .alphabetical
    
    /// Hide repositories with no changes (clean working tree)
    var hideCleanRepos: Bool = false
    
    /// Hide repositories that are synced (nothing to push/pull)
    var hideSyncedRepos: Bool = false
    
    /// Glob patterns to exclude repositories by path
    /// Example: ["external/**", "vendor/**", "node_modules/**"]
    var excludedPaths: [String] = []
    
    // MARK: - Computed Properties
    
    /// Whether any filters are active
    var hasActiveFilters: Bool {
        hideCleanRepos || hideSyncedRepos || !excludedPaths.isEmpty
    }
    
    /// Number of active filters
    var activeFilterCount: Int {
        var count = 0
        if hideCleanRepos { count += 1 }
        if hideSyncedRepos { count += 1 }
        count += excludedPaths.count
        return count
    }
    
    // MARK: - Methods
    
    /// Reset all filters to default values
    mutating func reset() {
        sortOption = .alphabetical
        hideCleanRepos = false
        hideSyncedRepos = false
        excludedPaths = []
    }
    
    /// Check if a repository should be visible based on current filter settings
    func shouldShow(_ repo: GitRepositoryWithStatus) -> Bool {
        // Check clean repo filter
        if hideCleanRepos && !repo.hasChanges {
            return false
        }
        
        // Check synced repo filter
        if hideSyncedRepos && !repo.needsPushPull {
            return false
        }
        
        // Check excluded paths
        for pattern in excludedPaths {
            if repo.matchesGlobPattern(pattern) {
                return false
            }
        }
        
        return true
    }
    
    /// Sort an array of repositories based on current sort settings
    func sorted(_ repos: [GitRepositoryWithStatus]) -> [GitRepositoryWithStatus] {
        switch sortOption {
        case .alphabetical:
            return repos.sorted { $0.repository.name.lowercased() < $1.repository.name.lowercased() }
        case .chronological:
            return repos.sorted { 
                ($0.lastCommitDate ?? .distantPast) > ($1.lastCommitDate ?? .distantPast) 
            }
        case .changeCount:
            return repos.sorted { $0.totalChanges > $1.totalChanges }
        }
    }
}

// MARK: - Default Settings

extension GitFilterSettings {
    /// Default settings with no filters active
    static let `default` = GitFilterSettings()
}
