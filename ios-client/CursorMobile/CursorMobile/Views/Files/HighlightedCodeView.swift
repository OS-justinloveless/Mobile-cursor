import SwiftUI
import SyntaxHighlight

struct HighlightedCodeView: View {
    let content: String
    let language: String
    
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var manager = SyntaxHighlightManager.shared
    
    init(content: String, language: String) {
        self.content = content
        self.language = language
        print("[HighlightedCodeView] Init with language: \(language), content length: \(content.count)")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let lines = content.components(separatedBy: .newlines)
            
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .top, spacing: 8) {
                    // Line number
                    Text("\(index + 1)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 40, alignment: .trailing)
                    
                    // Highlighted code line
                    highlightedLine(line)
                        .font(.system(.body, design: .monospaced))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(index % 2 == 0 ? Color.clear : Color(.systemGray6).opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private func highlightedLine(_ line: String) -> some View {
        let grammarResult = manager.grammar(for: language)
        let themeResult = manager.theme(for: colorScheme)
        
        if manager.syntaxHighlightingEnabled,
           let grammar = grammarResult,
           let theme = themeResult {
            // Use syntax highlighting
            let displayLine = line.isEmpty ? " " : line
            let highlighter = Highlighter(string: displayLine, theme: theme, grammar: grammar)
            Text(from: highlighter)
        } else {
            // Fallback to plain text - log why
            let _ = {
                if !manager.syntaxHighlightingEnabled {
                    print("Syntax highlighting disabled")
                } else if grammarResult == nil {
                    print("No grammar found for language: \(language)")
                } else if themeResult == nil {
                    print("No theme found for colorScheme: \(colorScheme)")
                }
            }()
            Text(line.isEmpty ? " " : line)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview

#Preview("Swift Code") {
    ScrollView {
        HighlightedCodeView(
            content: """
            import SwiftUI
            
            struct ContentView: View {
                @State private var count = 0
                
                var body: some View {
                    VStack {
                        Text("Count: \\(count)")
                        Button("Increment") {
                            count += 1
                        }
                    }
                }
            }
            """,
            language: "swift"
        )
    }
}

#Preview("JavaScript Code") {
    ScrollView {
        HighlightedCodeView(
            content: """
            // Express server setup
            const express = require('express');
            const app = express();
            
            app.get('/api/users', async (req, res) => {
                const users = await User.find();
                res.json({ success: true, data: users });
            });
            
            app.listen(3000, () => {
                console.log('Server running on port 3000');
            });
            """,
            language: "javascript"
        )
    }
}

#Preview("Python Code") {
    ScrollView {
        HighlightedCodeView(
            content: """
            import asyncio
            from typing import List, Optional
            
            class DataProcessor:
                def __init__(self, name: str):
                    self.name = name
                    self.items: List[str] = []
                
                async def process(self, data: Optional[dict] = None) -> bool:
                    \"\"\"Process the data asynchronously.\"\"\"
                    if data is None:
                        return False
                    
                    for key, value in data.items():
                        print(f"Processing {key}: {value}")
                    
                    return True
            """,
            language: "python"
        )
    }
}
