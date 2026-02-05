# Project Status

**Last Updated:** February 4, 2026

## Chat Redesign: Tmux-Based Chat Windows

### Status: COMPLETE ✅

The chat feature has been completely redesigned. Chats are no longer a fancy UI with custom message parsing and streaming - they are now simply **tmux windows running AI CLI tools**.

---

## What Changed

### Architecture Shift

| Before | After |
|--------|-------|
| Custom chat UI with message bubbles | Tmux terminal windows |
| PTY sessions managed by server | Tmux windows in project sessions |
| WebSocket streaming with SSE | Direct terminal I/O |
| Custom output parsing | Raw terminal output |
| Message persistence | Terminal scrollback |

### Naming Convention

Chat windows follow this naming pattern:
```
chat-{tool}-{topic}
```

Examples:
- `chat-cursor-refactor`
- `chat-claude-auth-bug`
- `chat-gemini-api-design`

---

## Completed Tasks

### 1. TmuxManager Updates ✅
- Added `createChatWindow()` method to spawn AI CLI in named tmux windows
- Added `buildCLICommand()` for constructing CLI commands with proper flags
- Added `sendInitialPrompt()` for sending initial prompts after CLI starts
- Added `listChatWindows()` to retrieve chat windows by project
- Added `isChatWindow()` utility to identify chat windows

### 2. Server Routes Refactoring ✅
- **`GET /api/conversations`** - Lists tmux chat windows
- **`POST /api/conversations`** - Creates a new chat window
- **`GET /api/conversations/:terminalId`** - Gets chat window details
- **`DELETE /api/conversations/:terminalId`** - Closes a chat window
- **`POST /api/conversations/:terminalId/prompt`** - Sends prompt to a chat window
- Removed all old conversation/message routes
- Removed WebSocket chat handlers (`chatAttach`, `chatDetach`, `chatMessage`)

### 3. Archived Deprecated Code ✅

**Server (`server/src/utils/archived/`):**
- `CLISessionManager.js` - PTY session management
- `OutputParser.js` - AI CLI output parsing
- `MobileChatStore.js` - Mobile conversation persistence
- `CursorChatReader.js` - Cursor chat file reading
- `CursorChatWriter.js` - Cursor chat file writing

**iOS (`ios-client/.../archived/`):**
- `ChatSessionView.swift` - Rich chat message UI
- `ContentBlockView.swift` - Content block rendering
- `ChatSessionManager.swift` - Chat session management

### 4. iOS Client Updates ✅
- `MainTabView` navigates to `TerminalView` for new chats
- `ConversationsView` lists `ChatWindow` objects with tmux info
- `ProjectConversationsView` fully rewritten for chat windows
- `NewChatSheet` creates tmux chat windows
- `Conversation.swift` simplified:
  - `ChatWindow` is the primary model
  - Legacy `Conversation` type marked deprecated
  - Helper types (`AnyCodableValue`, `ToolCall`, etc.) retained for other uses
- `TerminalView` has convenience initializer for string-based navigation
- Xcode project cleaned up (removed archived file references)
- **Build Status:** ✅ Successful

### 5. Web Client Updates ✅
- `ConversationsPage.jsx` lists tmux chat windows
- `ChatDetailPage.jsx` shows chat window info panel with:
  - Window/session details
  - Tool information
  - Prompt input to send commands
  - No full terminal (would require xterm.js)
- `ProjectDetailPage.jsx` creates and displays chat windows
- **Build Status:** ✅ Successful

---

## API Reference

### Create Chat Window
```http
POST /api/conversations
Content-Type: application/json

{
  "projectPath": "/path/to/project",
  "tool": "cursor-agent",      // or "claude", "gemini"
  "topic": "refactoring",      // optional
  "model": "sonnet-4",         // optional
  "mode": "agent",             // "agent", "plan", or "ask"
  "initialPrompt": "..."       // optional
}
```

### List Chat Windows
```http
GET /api/conversations?projectPath=/path/to/project
```

### Send Prompt
```http
POST /api/conversations/:terminalId/prompt
Content-Type: application/json

{
  "prompt": "Your message here"
}
```

### Close Chat Window
```http
DELETE /api/conversations/:terminalId
```

---

## Supported AI Tools

| Tool | CLI Command | Description |
|------|-------------|-------------|
| `cursor-agent` | `cursor-agent` | Cursor's AI agent |
| `claude` | `claude` | Anthropic Claude Code CLI |
| `gemini` | `gemini` | Google Gemini CLI |

---

## Usage Notes

1. **iOS App**: Full terminal experience with keyboard input and real-time output
2. **Web Client**: Basic info view with prompt sending capability
3. **Desktop**: Connect via SSH/tmux for full access

### Creating a New Chat

1. Navigate to a project
2. Go to the Chats tab
3. Tap "New Chat"
4. Select tool, mode, and optionally a topic
5. The chat window opens as a terminal

### Viewing Existing Chats

Chats appear as terminal windows with:
- Tool icon and name
- Topic/window name
- Active status indicator
- Session information

---

## File Structure

```
server/src/
├── routes/
│   └── conversations.js      # Tmux chat window API
├── utils/
│   ├── TmuxManager.js        # Chat window creation/management
│   └── archived/             # Deprecated chat code
│       ├── CLISessionManager.js
│       ├── OutputParser.js
│       ├── MobileChatStore.js
│       ├── CursorChatReader.js
│       └── CursorChatWriter.js

ios-client/.../
├── Models/
│   └── Conversation.swift    # ChatWindow model + legacy types
├── Views/
│   ├── Conversations/
│   │   ├── ConversationsView.swift
│   │   └── NewChatSheet.swift
│   ├── Projects/
│   │   └── ProjectConversationsView.swift
│   ├── Terminals/
│   │   └── TerminalView.swift
│   └── archived/
│       ├── ChatSessionView.swift
│       ├── ContentBlockView.swift
│       └── ChatSessionManager.swift

client/src/pages/
├── ConversationsPage.jsx     # Chat window list
├── ChatDetailPage.jsx        # Chat window details + prompt
└── ProjectDetailPage.jsx     # Project chats tab
```

---

## Next Steps (Optional Enhancements)

- [ ] Add xterm.js to web client for full terminal experience
- [ ] Implement chat window persistence across server restarts
- [ ] Add chat history/scrollback viewing
- [ ] Support additional AI CLI tools
- [ ] Add chat window filtering by tool type
