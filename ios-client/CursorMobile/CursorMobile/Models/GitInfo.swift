import Foundation

// MARK: - Git Status

/// Represents the current git status of a repository
struct GitStatus: Codable {
    let branch: String
    let ahead: Int
    let behind: Int
    let staged: [GitFileChange]
    let unstaged: [GitFileChange]
    let untracked: [String]
    let lastCommitTimestamp: Int?  // Unix timestamp in milliseconds of the last commit
    
    /// Whether there are any changes (staged, unstaged, or untracked)
    var hasChanges: Bool {
        !staged.isEmpty || !unstaged.isEmpty || !untracked.isEmpty
    }
    
    /// Total number of changed files
    var totalChanges: Int {
        staged.count + unstaged.count + untracked.count
    }
    
    /// Date of the last commit
    var lastCommitDate: Date? {
        guard let timestamp = lastCommitTimestamp else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
    }
    
    /// Whether the repo needs to push or pull (has commits ahead or behind)
    var needsPushPull: Bool {
        ahead > 0 || behind > 0
    }
    
    /// Get all file paths (staged, unstaged, and untracked) for searching
    var allFilePaths: [String] {
        var paths: [String] = []
        paths.append(contentsOf: staged.map { $0.path })
        paths.append(contentsOf: unstaged.map { $0.path })
        paths.append(contentsOf: untracked)
        return paths
    }
}

/// Represents a changed file in git
struct GitFileChange: Codable, Identifiable, Hashable {
    let path: String
    let status: String  // "modified", "added", "deleted", "renamed", "copied", "unmerged"
    let oldPath: String?  // For renames/copies
    
    var id: String { path }
    
    /// Human-readable status
    var statusDisplay: String {
        switch status {
        case "modified": return "Modified"
        case "added": return "Added"
        case "deleted": return "Deleted"
        case "renamed": return "Renamed"
        case "copied": return "Copied"
        case "unmerged": return "Conflict"
        default: return status.capitalized
        }
    }
    
    /// SF Symbol for this status
    var statusIcon: String {
        switch status {
        case "modified": return "pencil"
        case "added": return "plus"
        case "deleted": return "minus"
        case "renamed": return "arrow.right"
        case "copied": return "doc.on.doc"
        case "unmerged": return "exclamationmark.triangle"
        default: return "questionmark"
        }
    }
    
    /// Color for this status
    var statusColorName: String {
        switch status {
        case "modified": return "orange"
        case "added": return "green"
        case "deleted": return "red"
        case "renamed": return "blue"
        case "copied": return "blue"
        case "unmerged": return "yellow"
        default: return "gray"
        }
    }
}

// MARK: - Git Branches

/// Represents a git branch
struct GitBranch: Codable, Identifiable, Hashable {
    let name: String
    let isRemote: Bool
    let isCurrent: Bool
    
    var id: String { name }
    
    /// Display name without remote prefix
    var displayName: String {
        if name.hasPrefix("origin/") {
            return String(name.dropFirst(7))
        }
        return name
    }
}

struct GitBranchesResponse: Codable {
    let branches: [GitBranch]
}

// MARK: - Git Diff

struct GitDiffResponse: Codable {
    let diff: String
    let truncated: Bool?
    let totalLines: Int?
    
    var isTruncated: Bool {
        truncated ?? false
    }
}

// MARK: - Git Commits

struct GitCommit: Codable, Identifiable, Hashable {
    let hash: String
    let shortHash: String
    let author: GitAuthor
    let timestamp: Int
    let subject: String
    
    var id: String { hash }
    
    var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
    }
}

struct GitAuthor: Codable, Hashable {
    let name: String
    let email: String
}

struct GitLogResponse: Codable {
    let commits: [GitCommit]
}

// MARK: - Git Remotes

struct GitRemote: Codable, Identifiable, Hashable {
    let name: String
    let fetchUrl: String?
    let pushUrl: String?
    
    var id: String { name }
}

struct GitRemotesResponse: Codable {
    let remotes: [GitRemote]
}

// MARK: - Git Repositories (Multi-repo support)

/// Represents a git repository discovered within a project
struct GitRepository: Codable, Identifiable, Hashable {
    let path: String      // Relative path ("." for root, "packages/sub" for sub-repos)
    let name: String      // Display name (usually the directory name)
    
    var id: String { path }
    
    /// Whether this is the root repository
    var isRoot: Bool { path == "." }
}

struct GitRepositoriesResponse: Codable {
    let repositories: [GitRepository]
}

/// A wrapper that combines a GitRepository with its status for display purposes
/// Used for filtering, sorting, and searching in the Git view
struct GitRepositoryWithStatus: Identifiable {
    let repository: GitRepository
    var status: GitStatus?
    
    var id: String { repository.id }
    
    /// Total number of changed files
    var totalChanges: Int { status?.totalChanges ?? 0 }
    
    /// Whether there are any changes (staged, unstaged, or untracked)
    var hasChanges: Bool { status?.hasChanges ?? false }
    
    /// Whether the repo needs to push or pull
    var needsPushPull: Bool { status?.needsPushPull ?? false }
    
    /// Date of the last commit for chronological sorting
    var lastCommitDate: Date? { status?.lastCommitDate }
    
    /// Check if the repository matches a search query
    /// Searches repo name, file paths in staged/unstaged/untracked
    func matchesSearch(_ query: String) -> Bool {
        guard !query.isEmpty else { return true }
        
        let lowercasedQuery = query.lowercased()
        
        // Search repo name
        if repository.name.lowercased().contains(lowercasedQuery) {
            return true
        }
        
        // Search repo path
        if repository.path.lowercased().contains(lowercasedQuery) {
            return true
        }
        
        // Search file paths in status
        if let status = status {
            for filePath in status.allFilePaths {
                if filePath.lowercased().contains(lowercasedQuery) {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// Check if the repository path matches a glob pattern for exclusion
    func matchesGlobPattern(_ pattern: String) -> Bool {
        return repository.path.matchesGlob(pattern) || repository.name.matchesGlob(pattern)
    }
}

// MARK: - API Request Types

struct GitStageRequest: Codable {
    let files: [String]
}

struct GitCommitRequest: Codable {
    let message: String
    let files: [String]?
}

struct GitPushPullRequest: Codable {
    let remote: String?
    let branch: String?
}

struct GitCheckoutRequest: Codable {
    let branch: String
}

struct GitCreateBranchRequest: Codable {
    let name: String
    let checkout: Bool?
}

struct GitFetchRequest: Codable {
    let remote: String?
}

// MARK: - API Response Types

struct GitOperationResponse: Codable {
    let success: Bool
    let output: String?
    let message: String?
    let hash: String?
    let branch: String?
}

/// Response from generate-commit-message endpoint
struct GenerateCommitMessageResponse: Codable {
    let message: String
    let stagedFiles: Int?
    let truncated: Bool?
}

// MARK: - Glob Pattern Matching

extension String {
    /// Check if the string matches a simple glob pattern
    /// Supports * (any characters) and ** (any path segments)
    func matchesGlob(_ pattern: String) -> Bool {
        // Convert glob pattern to regex
        var regexPattern = "^"
        var i = pattern.startIndex
        
        while i < pattern.endIndex {
            let char = pattern[i]
            
            if char == "*" {
                // Check for **
                let nextIndex = pattern.index(after: i)
                if nextIndex < pattern.endIndex && pattern[nextIndex] == "*" {
                    // ** matches any path segments
                    regexPattern += ".*"
                    i = pattern.index(after: nextIndex)
                    continue
                } else {
                    // * matches any characters except /
                    regexPattern += "[^/]*"
                }
            } else if char == "?" {
                // ? matches any single character
                regexPattern += "."
            } else if char == "/" {
                regexPattern += "/"
            } else if "[]().+^${}|\\".contains(char) {
                // Escape special regex characters
                regexPattern += "\\\(char)"
            } else {
                regexPattern += String(char)
            }
            
            i = pattern.index(after: i)
        }
        
        regexPattern += "$"
        
        do {
            let regex = try NSRegularExpression(pattern: regexPattern, options: .caseInsensitive)
            let range = NSRange(self.startIndex..., in: self)
            return regex.firstMatch(in: self, options: [], range: range) != nil
        } catch {
            // If regex fails, fall back to simple contains check
            return self.lowercased().contains(pattern.lowercased().replacingOccurrences(of: "*", with: ""))
        }
    }
}
