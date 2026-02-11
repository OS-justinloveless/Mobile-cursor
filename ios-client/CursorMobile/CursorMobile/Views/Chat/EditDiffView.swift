import SwiftUI

/// Git-style diff view for Edit tool calls showing old_string vs new_string
struct EditDiffView: View {
    let oldString: String
    let newString: String
    let filePath: String?

    @State private var showFullDiff = false

    private let maxPreviewLines = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "arrow.left.arrow.right")
                    .foregroundColor(.orange)
                Text("Changes")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)

                Spacer()

                if shouldShowExpandButton {
                    Button {
                        withAnimation {
                            showFullDiff.toggle()
                        }
                    } label: {
                        Text(showFullDiff ? "Show Less" : "Show More")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
            }

            // File path if available
            if let path = filePath {
                Text((path as NSString).lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundColor(.secondary)
                    .padding(.vertical, 2)
            }

            // Diff content
            diffContentView
        }
        .padding(10)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(8)
    }

    private var diffContentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Removed lines
                if !oldString.isEmpty {
                    ForEach(Array(displayOldLines.enumerated()), id: \.offset) { _, line in
                        HStack(spacing: 4) {
                            Text("-")
                                .font(.caption.monospaced())
                                .foregroundColor(.red)
                                .frame(width: 12)
                            Text(line)
                                .font(.caption.monospaced())
                                .foregroundColor(.red)
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.1))
                        .listRowInsets(EdgeInsets())
                    }
                }

                // Added lines
                if !newString.isEmpty {
                    ForEach(Array(displayNewLines.enumerated()), id: \.offset) { _, line in
                        HStack(spacing: 4) {
                            Text("+")
                                .font(.caption.monospaced())
                                .foregroundColor(.green)
                                .frame(width: 12)
                            Text(line)
                                .font(.caption.monospaced())
                                .foregroundColor(.green)
                                .textSelection(.enabled)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .listRowInsets(EdgeInsets())
                    }
                }

                // Truncation indicator
                if isTruncated && !showFullDiff {
                    Text("... \(truncatedLinesCount) more lines")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                }
            }
        }
        .frame(maxHeight: showFullDiff ? nil : 300)
    }

    // MARK: - Computed Properties

    private var oldLines: [String] {
        oldString.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private var newLines: [String] {
        newString.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private var totalLines: Int {
        oldLines.count + newLines.count
    }

    private var isTruncated: Bool {
        totalLines > maxPreviewLines
    }

    private var shouldShowExpandButton: Bool {
        isTruncated
    }

    private var truncatedLinesCount: Int {
        max(0, totalLines - maxPreviewLines)
    }

    private var displayOldLines: [String] {
        if showFullDiff {
            return oldLines
        }

        let availableLines = maxPreviewLines / 2
        if oldLines.count <= availableLines {
            return oldLines
        }
        return Array(oldLines.prefix(availableLines))
    }

    private var displayNewLines: [String] {
        if showFullDiff {
            return newLines
        }

        let availableLines = maxPreviewLines / 2
        if newLines.count <= availableLines {
            return newLines
        }
        return Array(newLines.prefix(availableLines))
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            // Simple string replacement
            EditDiffView(
                oldString: "const oldValue = 'old';",
                newString: "const newValue = 'new';",
                filePath: "/Users/test/project/src/main.js"
            )

            // Multi-line diff
            EditDiffView(
                oldString: """
                function oldFunction() {
                    console.log('old');
                    return 'old';
                }
                """,
                newString: """
                function newFunction() {
                    console.log('new');
                    return 'new';
                }
                """,
                filePath: "/Users/test/project/src/utils.js"
            )

            // Large diff
            EditDiffView(
                oldString: (1...20).map { "Line \($0) old content" }.joined(separator: "\n"),
                newString: (1...20).map { "Line \($0) new content" }.joined(separator: "\n"),
                filePath: "/Users/test/project/src/large.js"
            )
        }
        .padding()
    }
}
