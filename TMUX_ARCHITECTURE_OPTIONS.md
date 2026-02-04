# Tmux Session Management Architecture

> **Status: Option 2 Implemented** - One session per project with multiple windows

## Previous Implementation (Deprecated)

The old `TmuxManager` created **one tmux session per terminal**, named `mobile-{projectDirName}-{timestamp}`.

```
mobile-MyProject-1706800000
mobile-MyProject-1706800100
mobile-MyProject-1706800200
mobile-OtherProject-1706800050
```

Each time a user creates a new terminal for a project, a new session is created. When a mobile client attaches, it spawns a PTY running `tmux attach -t sessionName`.

---

## Tmux Terminology

| Concept | Description |
|---------|-------------|
| **Session** | A collection of windows (like a workspace) |
| **Window** | A single screen within a session (like a tab) |
| **Pane** | A split within a window |
| **Client** | A terminal that's attached/viewing a session (your mobile app is a client) |

> **Note:** "Clients" are just viewers/connections to sessions. They're not something you create or manage - they're created when you run `tmux attach`. Your mobile app becomes a client when it attaches.

---

## Option 1: Current Approach - One Session Per Terminal

### Structure
```
tmux list-sessions:
  mobile-MyProject-1706800000: 1 windows
  mobile-MyProject-1706800100: 1 windows
  mobile-MyProject-1706800200: 1 windows
  mobile-OtherProject-1706800050: 1 windows
```

### Pros
- Simple implementation
- Each terminal is completely isolated
- Easy mental model

### Cons
- Cluttered `tmux ls` output
- No logical grouping by project
- Sessions accumulate over time (need manual cleanup)
- Desktop users have to know which timestamp corresponds to which terminal
- Can't easily see "all terminals for this project"

---

## Option 2: One Session Per Project, Multiple Windows (Recommended)

### Structure
```
tmux list-sessions:
  mobile-MyProject: 3 windows
  mobile-OtherProject: 1 windows

tmux list-windows -t mobile-MyProject:
  0: zsh ~/Code/MyProject (active)
  1: npm-dev ~/Code/MyProject
  2: build ~/Code/MyProject
```

### How It Works

| Action | tmux Command |
|--------|-------------|
| First terminal for project | `tmux new-session -d -s mobile-MyProject -c /path/to/project` |
| Additional terminal | `tmux new-window -t mobile-MyProject -c /path/to/project` |
| Attach to specific window | `tmux attach -t mobile-MyProject:1` |
| Name a window | `tmux rename-window -t mobile-MyProject:1 "npm-dev"` |
| List windows in session | `tmux list-windows -t mobile-MyProject` |
| Kill specific window | `tmux kill-window -t mobile-MyProject:1` |
| Kill entire project | `tmux kill-session -t mobile-MyProject` |

### Terminal ID Format Change
```
Current:  tmux-mobile-MyProject-1706800000
Proposed: tmux-mobile-MyProject:0, tmux-mobile-MyProject:1, etc.
```

### Pros
- Clean `tmux ls` (one entry per project)
- Natural grouping - all project terminals together
- Desktop users can `tmux attach -t mobile-MyProject` and switch between windows with `Ctrl+B n/p`
- Easier cleanup (kill session = kill all project terminals)
- Can name windows for clarity (e.g., "dev-server", "build", "tests")
- Matches how most developers use tmux

### Cons
- Slightly more complex code (window management)
- Need to track window indices
- Window indices can have gaps if windows are killed out of order

### Implementation Changes Required

1. **Session Management**
   - `createSession()` → `getOrCreateSession()` - reuse existing session if it exists
   - Session names: `mobile-{projectDirName}` (no timestamp)

2. **Window Management** (new)
   - `createWindow(sessionName, options)` - create new window in session
   - `listWindows(sessionName)` - list windows in a session
   - `killWindow(sessionName, windowIndex)` - kill specific window
   - `renameWindow(sessionName, windowIndex, name)` - name a window

3. **Terminal ID Format**
   - Change from `tmux-{sessionName}` to `tmux-{sessionName}:{windowIndex}`
   - Update `isTmuxTerminal()`, `getSessionNameFromId()` to parse new format
   - Add `getWindowIndexFromId()`

4. **Attach Logic**
   - `attachToSession()` → `attachToWindow(sessionName, windowIndex)`
   - Use `tmux attach -t mobile-MyProject:0` instead of `tmux attach -t mobile-MyProject-timestamp`

---

## Option 3: Separate Tmux Servers Per Project (Socket-based)

### Structure
```bash
# Each project gets its own tmux server via a socket
tmux -L mobile-MyProject new-session -d -s main
tmux -L mobile-OtherProject new-session -d -s main

# List sessions on a specific server
tmux -L mobile-MyProject list-sessions

# Attach
tmux -L mobile-MyProject attach
```

### Pros
- Complete isolation per project
- Separate server processes (one crash doesn't affect others)
- Clean separation of concerns

### Cons
- Overhead of multiple tmux server processes
- More complex to manage
- Socket files to clean up
- Overkill for most use cases

---

## Option 4: Hybrid - Session Groups

### Structure
Use tmux session groups to link related sessions:

```bash
tmux new-session -d -s mobile-MyProject-main
tmux new-session -d -t mobile-MyProject-main -s mobile-MyProject-dev
```

### Pros
- Sessions share window list but can have different "current window"
- Useful for multiple clients viewing different windows

### Cons
- Complex to manage
- Confusing mental model
- Not well suited for your use case

---

## Recommendation Summary

| Option | Complexity | Cleanliness | Best For |
|--------|-----------|-------------|----------|
| **1. Session per Terminal** | Low | Poor | Simple setups, few terminals |
| **2. Session per Project + Windows** | Medium | Excellent | Most use cases ✓ |
| **3. Server per Project** | High | Good | Extreme isolation needs |
| **4. Session Groups** | High | Medium | Multiple viewers, same project |

### I recommend Option 2 because:

1. **It's how developers naturally use tmux** - one session per project with multiple windows
2. **Clean organization** - `tmux ls` shows one line per project
3. **Desktop integration** - users can attach and see all project terminals
4. **Easy cleanup** - killing a session removes all project terminals
5. **Reasonable complexity** - not much harder to implement than current approach

---

## Implementation Complete

Option 2 has been implemented. The following changes were made:

### Files Modified

1. **`server/src/utils/TmuxManager.js`** - Complete refactor:
   - Session naming: `mobile-{projectDirName}` (no timestamp)
   - Terminal ID format: `tmux-{sessionName}:{windowIndex}`
   - New methods: `createTerminal()`, `createWindow()`, `listWindows()`, `killWindow()`, `renameWindow()`
   - Window-based attach/detach/write/resize methods
   - Legacy compatibility methods for migration

2. **`server/src/routes/terminals.js`** - Updated for window model:
   - `POST /api/terminals` uses `createTerminal()` for tmux
   - `DELETE /api/terminals/:id` kills window (not session)
   - New endpoint: `DELETE /api/terminals/tmux/sessions/:sessionName` to kill entire session
   - New endpoint: `GET /api/terminals/tmux/sessions/:sessionName/windows`

3. **`server/src/websocket/index.js`** - Updated handlers:
   - Terminal attach/detach uses `parseTerminalId()` for window-based operations
   - Input/resize uses window-based methods
   - Kill terminal kills window, not session

### Migration Notes

- Old terminals with format `tmux-mobile-project-timestamp` will still work (legacy compatibility)
- New terminals use format `tmux-mobile-project:0`, `tmux-mobile-project:1`, etc.
- You may want to kill old tmux sessions manually: `tmux kill-session -t mobile-project-timestamp`

### Usage Examples

```bash
# List all mobile sessions
tmux list-sessions | grep mobile-

# List windows in a project session
tmux list-windows -t mobile-MyProject

# Attach to a project (see all windows)
tmux attach -t mobile-MyProject

# Switch windows in tmux: Ctrl+B n (next) or Ctrl+B p (previous)
```
