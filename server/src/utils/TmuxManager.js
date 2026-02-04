import * as pty from 'node-pty';
import { execSync, exec } from 'child_process';
import path from 'path';
import fs from 'fs';
import os from 'os';

/**
 * Manages tmux sessions for mobile terminal access
 * 
 * Architecture: One session per project, multiple windows per session
 * 
 * Sessions are named: mobile-{projectDirName}
 * Terminal IDs are: tmux-{sessionName}:{windowIndex}
 * 
 * Benefits:
 * - Clean organization (one session per project)
 * - Sessions persist even when mobile app disconnects
 * - Sessions can be accessed from desktop via `tmux attach -t mobile-{project}`
 * - Multiple windows per project (like tabs)
 * - Desktop users can switch windows with Ctrl+B n/p
 */
export class TmuxManager {
  constructor() {
    // Map of "sessionName:windowIndex" to attached PTY processes
    this.attachedWindows = new Map(); // "session:window" -> { ptyProcess, handlers, buffer }
    
    // Event handlers for terminal output
    this.outputHandlers = new Map(); // "session:window" -> Set of callbacks
    
    // Output buffer for each attached window
    this.outputBuffers = new Map(); // "session:window" -> string
    this.maxBufferSize = 64 * 1024; // 64KB max buffer
    
    console.log('[TmuxManager] Initialized with window-based architecture');
  }

  /**
   * Check if tmux is installed and available
   * @returns {boolean}
   */
  isTmuxAvailable() {
    try {
      execSync('which tmux', { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] });
      return true;
    } catch (e) {
      return false;
    }
  }

  /**
   * Get tmux version
   * @returns {string|null}
   */
  getTmuxVersion() {
    try {
      const output = execSync('tmux -V', { encoding: 'utf-8' }).trim();
      return output;
    } catch (e) {
      return null;
    }
  }

  /**
   * Generate a session name from a project path
   * Format: mobile-{projectDirName}
   * @param {string} projectPath - The project path
   * @returns {string}
   */
  generateSessionName(projectPath) {
    const projectDirName = path.basename(projectPath)
      .replace(/[^a-zA-Z0-9_-]/g, '-') // Sanitize for tmux
      .substring(0, 30); // Keep it reasonable length
    return `mobile-${projectDirName}`;
  }

  /**
   * Extract project name from a session name
   * @param {string} sessionName - The tmux session name
   * @returns {string|null}
   */
  extractProjectName(sessionName) {
    if (!sessionName.startsWith('mobile-')) {
      return null;
    }
    return sessionName.substring(7); // Remove 'mobile-' prefix
  }

  /**
   * Check if a session belongs to a project
   * @param {string} sessionName - The tmux session name
   * @param {string} projectPath - The project path
   * @returns {boolean}
   */
  sessionBelongsToProject(sessionName, projectPath) {
    const expectedName = this.generateSessionName(projectPath);
    return sessionName === expectedName;
  }

  /**
   * List all tmux sessions
   * @returns {Array<object>} - Array of session info
   */
  listAllSessions() {
    if (!this.isTmuxAvailable()) {
      console.log('[TmuxManager] tmux not available');
      return [];
    }

    try {
      const output = execSync(
        'tmux list-sessions -F "#{session_name}|#{session_created}|#{session_windows}|#{session_attached}"',
        { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }
      ).trim();

      if (!output) {
        console.log('[TmuxManager] No output from tmux list-sessions');
        return [];
      }

      const sessions = output.split('\n').map(line => {
        const parts = line.split('|');
        const name = parts[0];
        const created = parts[1];
        const windows = parts[2];
        const attached = parts[3];
        
        return {
          name,
          createdAt: parseInt(created, 10) * 1000,
          windowCount: parseInt(windows, 10),
          attached: attached === '1',
          isMobileSession: name.startsWith('mobile-'),
          projectName: this.extractProjectName(name)
        };
      });

      console.log(`[TmuxManager] Found ${sessions.length} total sessions:`, sessions.map(s => s.name));
      return sessions;
    } catch (e) {
      const errorMsg = e.stderr?.toString() || e.message || '';
      
      if (errorMsg.includes('no server running') || 
          errorMsg.includes('no sessions') ||
          errorMsg.includes('error connecting')) {
        console.log('[TmuxManager] No tmux server or sessions');
        return [];
      }
      
      console.error('[TmuxManager] Error listing sessions:', errorMsg);
      return [];
    }
  }

  /**
   * List windows in a tmux session
   * @param {string} sessionName - The session name
   * @returns {Array<object>} - Array of window info
   */
  listWindows(sessionName) {
    if (!this.isTmuxAvailable()) {
      return [];
    }

    try {
      const output = execSync(
        `tmux list-windows -t "${sessionName}" -F "#{window_index}|#{window_name}|#{window_active}|#{pane_current_path}"`,
        { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }
      ).trim();

      if (!output) {
        return [];
      }

      const windows = output.split('\n').map(line => {
        const parts = line.split('|');
        return {
          index: parseInt(parts[0], 10),
          name: parts[1],
          active: parts[2] === '1',
          currentPath: parts[3] || null
        };
      });

      return windows;
    } catch (e) {
      const errorMsg = e.stderr?.toString() || e.message || '';
      if (errorMsg.includes("session not found") || errorMsg.includes("can't find session")) {
        return [];
      }
      console.error(`[TmuxManager] Error listing windows for ${sessionName}:`, errorMsg);
      return [];
    }
  }

  /**
   * Check if a session exists
   * @param {string} sessionName - The session name
   * @returns {boolean}
   */
  sessionExists(sessionName) {
    const sessions = this.listAllSessions();
    return sessions.some(s => s.name === sessionName);
  }

  /**
   * Get the session for a project
   * @param {string} projectPath - The project path
   * @returns {object|null} - Session info or null
   */
  getSessionForProject(projectPath) {
    const sessionName = this.generateSessionName(projectPath);
    const sessions = this.listAllSessions();
    return sessions.find(s => s.name === sessionName) || null;
  }

  /**
   * Get or create a session for a project
   * @param {string} projectPath - The project path
   * @param {object} options - Options
   * @returns {object} - Session info with { name, isNew }
   */
  getOrCreateSession(projectPath, options = {}) {
    if (!this.isTmuxAvailable()) {
      throw new Error('tmux is not installed or not available in PATH');
    }

    const sessionName = this.generateSessionName(projectPath);
    const cwd = options.cwd || projectPath;

    // Check if session already exists
    if (this.sessionExists(sessionName)) {
      console.log(`[TmuxManager] Session ${sessionName} already exists`);
      return { name: sessionName, isNew: false };
    }

    // Verify cwd exists
    if (!fs.existsSync(cwd)) {
      throw new Error(`Working directory does not exist: ${cwd}`);
    }

    // Create the tmux session
    try {
      execSync(
        `tmux new-session -d -s "${sessionName}" -c "${cwd}"`,
        { encoding: 'utf-8', cwd }
      );
      console.log(`[TmuxManager] Created session: ${sessionName} in ${cwd}`);
      return { name: sessionName, isNew: true };
    } catch (e) {
      if (e.message.includes('duplicate session')) {
        // Race condition - session was created between check and create
        return { name: sessionName, isNew: false };
      }
      throw new Error(`Failed to create tmux session: ${e.message}`);
    }
  }

  /**
   * Create a new window in a session
   * @param {string} sessionName - The session name
   * @param {object} options - Options
   * @param {string} options.cwd - Working directory
   * @param {string} options.name - Window name (optional)
   * @returns {object} - Window info { sessionName, windowIndex, windowName }
   */
  createWindow(sessionName, options = {}) {
    if (!this.isTmuxAvailable()) {
      throw new Error('tmux is not installed');
    }

    if (!this.sessionExists(sessionName)) {
      throw new Error(`Session ${sessionName} does not exist`);
    }

    const cwd = options.cwd || os.homedir();
    const windowName = options.name || '';

    // Build command
    let cmd = `tmux new-window -t "${sessionName}" -c "${cwd}"`;
    if (windowName) {
      cmd += ` -n "${windowName}"`;
    }
    // Add -P to print window info
    cmd += ' -P -F "#{window_index}"';

    try {
      const output = execSync(cmd, { encoding: 'utf-8' }).trim();
      const windowIndex = parseInt(output, 10);
      
      console.log(`[TmuxManager] Created window ${windowIndex} in session ${sessionName}`);
      
      return {
        sessionName,
        windowIndex,
        windowName: windowName || `window-${windowIndex}`,
        cwd
      };
    } catch (e) {
      throw new Error(`Failed to create window: ${e.message}`);
    }
  }

  /**
   * Create a new terminal (session + window if needed, or just window)
   * This is the main entry point for creating terminals
   * @param {object} options - Options
   * @param {string} options.projectPath - Project path (required)
   * @param {string} options.cwd - Working directory (defaults to projectPath)
   * @param {string} options.windowName - Name for the window (optional)
   * @returns {object} - Terminal info
   */
  createTerminal(options = {}) {
    if (!options.projectPath) {
      throw new Error('projectPath is required');
    }

    const projectPath = options.projectPath;
    const cwd = options.cwd || projectPath;
    const windowName = options.windowName || '';

    // Get or create the session for this project
    const { name: sessionName, isNew: isNewSession } = this.getOrCreateSession(projectPath, { cwd });

    let windowIndex;
    
    if (isNewSession) {
      // New session already has window 0
      windowIndex = 0;
      // Rename window if name provided
      if (windowName) {
        this.renameWindow(sessionName, 0, windowName);
      }
    } else {
      // Create a new window in the existing session
      const windowInfo = this.createWindow(sessionName, { cwd, name: windowName });
      windowIndex = windowInfo.windowIndex;
    }

    const terminalId = this.buildTerminalId(sessionName, windowIndex);

    return {
      id: terminalId,
      sessionName,
      windowIndex,
      windowName: windowName || `window-${windowIndex}`,
      cwd,
      projectPath,
      createdAt: Date.now(),
      active: true,
      source: 'tmux',
      attached: false
    };
  }

  /**
   * Rename a window
   * @param {string} sessionName - Session name
   * @param {number} windowIndex - Window index
   * @param {string} newName - New window name
   */
  renameWindow(sessionName, windowIndex, newName) {
    try {
      execSync(
        `tmux rename-window -t "${sessionName}:${windowIndex}" "${newName}"`,
        { encoding: 'utf-8', stdio: ['pipe', 'pipe', 'pipe'] }
      );
    } catch (e) {
      console.error(`[TmuxManager] Failed to rename window: ${e.message}`);
    }
  }

  /**
   * Build a terminal ID from session name and window index
   * Format: tmux-{sessionName}:{windowIndex}
   */
  buildTerminalId(sessionName, windowIndex) {
    return `tmux-${sessionName}:${windowIndex}`;
  }

  /**
   * Parse a terminal ID into session name and window index
   * @param {string} terminalId - Terminal ID
   * @returns {object} - { sessionName, windowIndex }
   */
  parseTerminalId(terminalId) {
    if (!this.isTmuxTerminal(terminalId)) {
      throw new Error(`Not a tmux terminal ID: ${terminalId}`);
    }
    
    // Remove 'tmux-' prefix
    const rest = terminalId.substring(5);
    
    // Find the last colon (window index separator)
    const lastColonIndex = rest.lastIndexOf(':');
    
    if (lastColonIndex === -1) {
      // Legacy format without window index - assume window 0
      return { sessionName: rest, windowIndex: 0 };
    }
    
    const sessionName = rest.substring(0, lastColonIndex);
    const windowIndex = parseInt(rest.substring(lastColonIndex + 1), 10);
    
    return { sessionName, windowIndex };
  }

  /**
   * Check if a terminal ID is a tmux terminal
   * @param {string} terminalId - Terminal ID
   * @returns {boolean}
   */
  isTmuxTerminal(terminalId) {
    return terminalId && terminalId.startsWith('tmux-');
  }

  /**
   * Get the window key for maps (sessionName:windowIndex)
   */
  getWindowKey(sessionName, windowIndex) {
    return `${sessionName}:${windowIndex}`;
  }

  /**
   * Attach to a specific window via PTY
   * @param {string} sessionName - The session name
   * @param {number} windowIndex - The window index
   * @param {object} options - Options (cols, rows)
   * @returns {object} - Attached window info
   */
  attachToWindow(sessionName, windowIndex, options = {}) {
    if (!this.isTmuxAvailable()) {
      throw new Error('tmux is not installed');
    }

    // Check if session exists
    if (!this.sessionExists(sessionName)) {
      throw new Error(`Session ${sessionName} not found`);
    }

    // Check if window exists
    const windows = this.listWindows(sessionName);
    const window = windows.find(w => w.index === windowIndex);
    if (!window) {
      throw new Error(`Window ${windowIndex} not found in session ${sessionName}`);
    }

    const windowKey = this.getWindowKey(sessionName, windowIndex);

    // Check if already attached
    if (this.attachedWindows.has(windowKey)) {
      console.log(`[TmuxManager] Already attached to ${windowKey}, returning existing`);
      return this.attachedWindows.get(windowKey);
    }

    const cols = options.cols || 80;
    const rows = options.rows || 24;

    // Spawn PTY with tmux attach to specific window
    // Use select-window first, then attach
    const ptyProcess = pty.spawn('tmux', ['attach', '-t', `${sessionName}:${windowIndex}`], {
      name: 'xterm-256color',
      cols,
      rows,
      cwd: window.currentPath || os.homedir(),
      env: {
        ...process.env,
        TERM: 'xterm-256color',
        COLORTERM: 'truecolor'
      }
    });

    const attachedWindow = {
      sessionName,
      windowIndex,
      windowKey,
      ptyProcess,
      cols,
      rows,
      attachedAt: Date.now()
    };

    this.attachedWindows.set(windowKey, attachedWindow);
    this.outputHandlers.set(windowKey, new Set());
    this.outputBuffers.set(windowKey, '');

    // Handle PTY output
    ptyProcess.onData((data) => {
      this.appendToBuffer(windowKey, data);
      
      const handlers = this.outputHandlers.get(windowKey);
      if (handlers) {
        for (const handler of handlers) {
          try {
            handler(data);
          } catch (error) {
            console.error(`[TmuxManager] Error in output handler for ${windowKey}:`, error);
          }
        }
      }
    });

    // Handle PTY exit
    ptyProcess.onExit(({ exitCode, signal }) => {
      console.log(`[TmuxManager] Detached from ${windowKey}, exit: ${exitCode}, signal: ${signal}`);
      this.attachedWindows.delete(windowKey);
    });

    console.log(`[TmuxManager] Attached to window: ${windowKey}`);

    const terminalId = this.buildTerminalId(sessionName, windowIndex);

    return {
      id: terminalId,
      sessionName,
      windowIndex,
      windowName: window.name,
      pid: ptyProcess.pid,
      cols,
      rows,
      attached: true,
      source: 'tmux'
    };
  }

  /**
   * Detach from a window
   * @param {string} sessionName - Session name
   * @param {number} windowIndex - Window index
   */
  detachFromWindow(sessionName, windowIndex) {
    const windowKey = this.getWindowKey(sessionName, windowIndex);
    const attached = this.attachedWindows.get(windowKey);
    
    if (!attached) {
      console.log(`[TmuxManager] Not attached to ${windowKey}`);
      return;
    }

    // Send Ctrl+B, D to detach gracefully
    attached.ptyProcess.write('\x02d');
    
    setTimeout(() => {
      if (this.attachedWindows.has(windowKey)) {
        attached.ptyProcess.kill();
        this.attachedWindows.delete(windowKey);
      }
    }, 500);

    console.log(`[TmuxManager] Detached from window: ${windowKey}`);
  }

  /**
   * Write data to an attached window
   * @param {string} sessionName - Session name
   * @param {number} windowIndex - Window index
   * @param {string} data - Data to write
   */
  writeToWindow(sessionName, windowIndex, data) {
    const windowKey = this.getWindowKey(sessionName, windowIndex);
    const attached = this.attachedWindows.get(windowKey);
    
    if (!attached) {
      throw new Error(`Not attached to ${windowKey}`);
    }
    
    attached.ptyProcess.write(data);
  }

  /**
   * Resize an attached window
   * @param {string} sessionName - Session name
   * @param {number} windowIndex - Window index
   * @param {number} cols - Columns
   * @param {number} rows - Rows
   */
  resizeWindow(sessionName, windowIndex, cols, rows) {
    const windowKey = this.getWindowKey(sessionName, windowIndex);
    const attached = this.attachedWindows.get(windowKey);
    
    if (!attached) {
      throw new Error(`Not attached to ${windowKey}`);
    }
    
    attached.ptyProcess.resize(cols, rows);
    attached.cols = cols;
    attached.rows = rows;
  }

  /**
   * Kill a specific window
   * @param {string} sessionName - Session name
   * @param {number} windowIndex - Window index
   */
  killWindow(sessionName, windowIndex) {
    const windowKey = this.getWindowKey(sessionName, windowIndex);
    
    // Detach first if attached
    if (this.attachedWindows.has(windowKey)) {
      const attached = this.attachedWindows.get(windowKey);
      attached.ptyProcess.kill();
      this.attachedWindows.delete(windowKey);
    }

    // Kill the tmux window
    try {
      execSync(`tmux kill-window -t "${sessionName}:${windowIndex}"`, {
        encoding: 'utf-8',
        stdio: ['pipe', 'pipe', 'pipe']
      });
      console.log(`[TmuxManager] Killed window: ${windowKey}`);
    } catch (e) {
      const errorMsg = e.stderr?.toString() || e.message || '';
      if (!errorMsg.includes("window not found") && !errorMsg.includes("no server running")) {
        throw new Error(`Failed to kill window: ${e.message}`);
      }
    }

    // Clean up handlers and buffer
    this.outputHandlers.delete(windowKey);
    this.outputBuffers.delete(windowKey);

    // Check if this was the last window - if so, session will auto-close
    const windows = this.listWindows(sessionName);
    if (windows.length === 0) {
      console.log(`[TmuxManager] Session ${sessionName} has no more windows, it will close`);
    }
  }

  /**
   * Kill an entire session (all windows)
   * @param {string} sessionName - Session name
   */
  killSession(sessionName) {
    // Detach from all windows in this session
    for (const [windowKey, attached] of this.attachedWindows) {
      if (windowKey.startsWith(sessionName + ':')) {
        attached.ptyProcess.kill();
        this.attachedWindows.delete(windowKey);
        this.outputHandlers.delete(windowKey);
        this.outputBuffers.delete(windowKey);
      }
    }

    // Kill the tmux session
    try {
      execSync(`tmux kill-session -t "${sessionName}"`, {
        encoding: 'utf-8',
        stdio: ['pipe', 'pipe', 'pipe']
      });
      console.log(`[TmuxManager] Killed session: ${sessionName}`);
    } catch (e) {
      const errorMsg = e.stderr?.toString() || e.message || '';
      if (!errorMsg.includes("session not found") && !errorMsg.includes("no server running")) {
        throw new Error(`Failed to kill session: ${e.message}`);
      }
    }
  }

  /**
   * Append data to output buffer
   */
  appendToBuffer(windowKey, data) {
    let buffer = this.outputBuffers.get(windowKey) || '';
    buffer += data;
    
    if (buffer.length > this.maxBufferSize) {
      buffer = buffer.slice(-this.maxBufferSize);
    }
    
    this.outputBuffers.set(windowKey, buffer);
  }

  /**
   * Get buffered output
   */
  getBuffer(sessionName, windowIndex) {
    const windowKey = this.getWindowKey(sessionName, windowIndex);
    return this.outputBuffers.get(windowKey) || '';
  }

  /**
   * Clear output buffer
   */
  clearBuffer(sessionName, windowIndex) {
    const windowKey = this.getWindowKey(sessionName, windowIndex);
    this.outputBuffers.set(windowKey, '');
  }

  /**
   * Add output handler
   */
  addOutputHandler(sessionName, windowIndex, handler) {
    const windowKey = this.getWindowKey(sessionName, windowIndex);
    if (!this.outputHandlers.has(windowKey)) {
      this.outputHandlers.set(windowKey, new Set());
    }
    this.outputHandlers.get(windowKey).add(handler);
    console.log(`[TmuxManager] Added handler for ${windowKey}`);
  }

  /**
   * Remove output handler
   */
  removeOutputHandler(sessionName, windowIndex, handler) {
    const windowKey = this.getWindowKey(sessionName, windowIndex);
    const handlers = this.outputHandlers.get(windowKey);
    if (handlers) {
      handlers.delete(handler);
      console.log(`[TmuxManager] Removed handler for ${windowKey}`);
    }
  }

  /**
   * Check if attached to a window
   */
  isAttached(sessionName, windowIndex) {
    const windowKey = this.getWindowKey(sessionName, windowIndex);
    return this.attachedWindows.has(windowKey);
  }

  /**
   * Get terminal info for API responses
   * @param {string} terminalId - Terminal ID
   * @param {string} projectPath - Project path for context
   * @returns {object|null}
   */
  getTerminalInfo(terminalId, projectPath) {
    const { sessionName, windowIndex } = this.parseTerminalId(terminalId);
    
    const sessions = this.listAllSessions();
    const session = sessions.find(s => s.name === sessionName);
    
    if (!session) {
      return null;
    }

    const windows = this.listWindows(sessionName);
    const window = windows.find(w => w.index === windowIndex);
    
    if (!window) {
      return null;
    }

    const windowKey = this.getWindowKey(sessionName, windowIndex);
    const attached = this.attachedWindows.get(windowKey);

    return {
      id: terminalId,
      sessionName,
      windowIndex,
      windowName: window.name,
      cwd: window.currentPath || projectPath,
      projectPath,
      createdAt: session.createdAt,
      active: true,
      source: 'tmux',
      attached: !!attached,
      windowCount: session.windowCount,
      pid: attached?.ptyProcess?.pid || null,
      cols: attached?.cols || 80,
      rows: attached?.rows || 24,
      projectName: this.extractProjectName(sessionName)
    };
  }

  /**
   * List all terminals (windows) for a project
   * @param {string} projectPath - Project path
   * @returns {Array<object>}
   */
  listTerminals(projectPath) {
    console.log(`[TmuxManager] listTerminals called with projectPath="${projectPath}"`);
    
    try {
      const sessionName = this.generateSessionName(projectPath);
      const session = this.listAllSessions().find(s => s.name === sessionName);
      
      if (!session) {
        console.log(`[TmuxManager] No session found for project`);
        return [];
      }

      const windows = this.listWindows(sessionName);
      
      const terminals = windows.map(window => {
        const terminalId = this.buildTerminalId(sessionName, window.index);
        const windowKey = this.getWindowKey(sessionName, window.index);
        const attached = this.attachedWindows.get(windowKey);

        return {
          id: terminalId,
          name: window.name || `Terminal ${window.index}`,
          sessionName,
          windowIndex: window.index,
          cwd: window.currentPath || projectPath,
          projectPath,
          createdAt: session.createdAt,
          active: true,
          source: 'tmux',
          attached: !!attached,
          windowCount: session.windowCount,
          pid: attached?.ptyProcess?.pid || null,
          cols: attached?.cols || 80,
          rows: attached?.rows || 24,
          projectName: session.projectName,
          activeCommand: null,
          lastCommand: null,
          exitCode: null
        };
      });
      
      console.log(`[TmuxManager] Returning ${terminals.length} terminals`);
      return terminals;
    } catch (error) {
      console.error(`[TmuxManager] Error in listTerminals:`, error);
      return [];
    }
  }

  /**
   * List all mobile terminals across all projects
   * @returns {Array<object>}
   */
  listAllMobileTerminals() {
    const allTerminals = [];
    const sessions = this.listAllSessions().filter(s => s.isMobileSession);
    
    for (const session of sessions) {
      const windows = this.listWindows(session.name);
      
      for (const window of windows) {
        const terminalId = this.buildTerminalId(session.name, window.index);
        const windowKey = this.getWindowKey(session.name, window.index);
        const attached = this.attachedWindows.get(windowKey);

        allTerminals.push({
          id: terminalId,
          name: window.name || `Terminal ${window.index}`,
          sessionName: session.name,
          windowIndex: window.index,
          cwd: window.currentPath || null,
          createdAt: session.createdAt,
          active: true,
          source: 'tmux',
          attached: !!attached,
          windowCount: session.windowCount,
          pid: attached?.ptyProcess?.pid || null,
          cols: attached?.cols || 80,
          rows: attached?.rows || 24,
          projectName: session.projectName
        });
      }
    }
    
    return allTerminals;
  }

  /**
   * Clean up all attached windows
   */
  cleanup() {
    for (const [windowKey, attached] of this.attachedWindows) {
      try {
        attached.ptyProcess.kill();
      } catch (error) {
        console.error(`[TmuxManager] Error killing attached PTY for ${windowKey}:`, error);
      }
    }
    this.attachedWindows.clear();
    this.outputHandlers.clear();
    this.outputBuffers.clear();
    console.log('[TmuxManager] Cleaned up all attached windows');
  }

  // ============ Legacy compatibility methods ============
  // These are kept for backward compatibility during migration

  /**
   * @deprecated Use parseTerminalId instead
   */
  getSessionNameFromId(terminalId) {
    const { sessionName } = this.parseTerminalId(terminalId);
    return sessionName;
  }

  /**
   * @deprecated Use createTerminal instead
   */
  createSession(options = {}) {
    console.warn('[TmuxManager] createSession is deprecated, use createTerminal instead');
    return this.createTerminal(options);
  }

  /**
   * @deprecated Use attachToWindow instead
   */
  attachToSession(sessionName, options = {}) {
    console.warn('[TmuxManager] attachToSession is deprecated, use attachToWindow instead');
    // Attach to window 0 of the session
    return this.attachToWindow(sessionName, 0, options);
  }

  /**
   * @deprecated Use detachFromWindow instead
   */
  detachFromSession(sessionName) {
    console.warn('[TmuxManager] detachFromSession is deprecated, use detachFromWindow instead');
    // Detach from window 0
    this.detachFromWindow(sessionName, 0);
  }

  /**
   * @deprecated Use writeToWindow instead
   */
  writeToSession(sessionName, data) {
    console.warn('[TmuxManager] writeToSession is deprecated, use writeToWindow instead');
    this.writeToWindow(sessionName, 0, data);
  }

  /**
   * @deprecated Use resizeWindow instead
   */
  resizeSession(sessionName, cols, rows) {
    console.warn('[TmuxManager] resizeSession is deprecated, use resizeWindow instead');
    this.resizeWindow(sessionName, 0, cols, rows);
  }
}

// Singleton instance
export const tmuxManager = new TmuxManager();
