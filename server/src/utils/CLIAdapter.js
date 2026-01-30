import { execSync } from 'child_process';
import { randomUUID } from 'crypto';

/**
 * Base CLI Adapter - Abstract interface for AI CLI tools
 *
 * Provides a unified interface for interacting with different AI CLI tools:
 * - cursor-agent: Native Cursor CLI with built-in session management
 * - claude: Claude Code CLI (claude or claude-code)
 * - gemini: Google Gemini CLI
 *
 * Each adapter implements tool-specific command construction and output parsing.
 */
export class CLIAdapter {
  /**
   * Build arguments for creating a new chat session
   * @param {Object} options - Creation options
   * @param {string} options.workspacePath - Path to workspace directory
   * @returns {Array|Object} Command arguments or {needsGeneratedId: true}
   */
  buildCreateChatArgs(options) {
    throw new Error('buildCreateChatArgs must be implemented by subclass');
  }

  /**
   * Build arguments for sending a message to an existing chat
   * @param {Object} options - Message options
   * @param {string} options.chatId - Chat/session ID
   * @param {string} options.message - Message text
   * @param {string} options.workspacePath - Path to workspace directory
   * @param {string} options.model - Model to use (optional)
   * @param {string} options.mode - Chat mode (agent|plan|ask)
   * @returns {Array} Command arguments
   */
  buildSendMessageArgs(options) {
    throw new Error('buildSendMessageArgs must be implemented by subclass');
  }

  /**
   * Get the CLI executable name
   * @returns {string} Executable name (e.g., 'cursor-agent', 'claude')
   */
  getExecutable() {
    throw new Error('getExecutable must be implemented by subclass');
  }

  /**
   * Parse CLI output from chat creation command
   * @param {string} output - stdout from CLI
   * @returns {string} Chat/session ID
   */
  parseCreateChatOutput(output) {
    throw new Error('parseCreateChatOutput must be implemented by subclass');
  }

  /**
   * Check if this CLI tool is installed and available
   * @returns {Promise<boolean>} True if CLI is available
   */
  async isAvailable() {
    try {
      const executable = this.getExecutable();
      execSync(`which ${executable}`, { stdio: 'pipe' });
      return true;
    } catch (error) {
      return false;
    }
  }

  /**
   * Get display name for this tool
   * @returns {string} Human-readable tool name
   */
  getDisplayName() {
    throw new Error('getDisplayName must be implemented by subclass');
  }

  /**
   * Get installation instructions for this tool
   * @returns {string} Instructions for installing the CLI
   */
  getInstallInstructions() {
    throw new Error('getInstallInstructions must be implemented by subclass');
  }
}

/**
 * Cursor Agent CLI Adapter
 *
 * Uses the cursor-agent CLI which provides native session management.
 * Supports:
 * - create-chat command for new sessions
 * - --resume flag for continuing sessions
 * - --workspace flag for workspace context
 * - --model flag for model selection
 * - --mode flag for agent/plan/ask modes
 */
export class CursorAgentAdapter extends CLIAdapter {
  buildCreateChatArgs({ workspacePath }) {
    const args = ['create-chat'];
    if (workspacePath) {
      args.push('--workspace', workspacePath);
    }
    return args;
  }

  buildSendMessageArgs({ chatId, message, workspacePath, model, mode }) {
    const args = [
      '--resume', chatId,
      '-p',
      '-f', // Force flag for headless mode file edits
      '--output-format', 'stream-json'
    ];

    // Insert flags before the message
    if (workspacePath) {
      args.splice(2, 0, '--workspace', workspacePath);
    }
    if (model) {
      args.splice(2, 0, '--model', model);
    }
    if (mode && mode !== 'agent') {
      args.splice(2, 0, '--mode', mode);
    }

    // Message goes at the end
    args.push(message);
    return args;
  }

  getExecutable() {
    return 'cursor-agent';
  }

  parseCreateChatOutput(output) {
    // cursor-agent returns the chat ID directly
    return output.trim();
  }

  getDisplayName() {
    return 'Cursor Agent';
  }

  getInstallInstructions() {
    return 'Install cursor-agent: curl https://cursor.com/install -fsS | bash';
  }
}

/**
 * Claude Code CLI Adapter
 *
 * Uses the Claude Code CLI (claude or claude-code).
 * Key differences from cursor-agent:
 * - No explicit create-chat command (generates UUID instead)
 * - Uses --session-id flag for session management
 * - Uses --permission-mode plan instead of --mode plan
 */
export class ClaudeAdapter extends CLIAdapter {
  constructor() {
    super();
    // Try to detect which variant is installed (claude vs claude-code)
    this._executable = null;
  }

  buildCreateChatArgs({ workspacePath }) {
    // Claude CLI doesn't have explicit create command
    // Return marker that we need to generate a session ID
    return { needsGeneratedId: true };
  }

  buildSendMessageArgs({ chatId, message, workspacePath, model, mode }) {
    const args = [
      '--print',
      '--output-format', 'stream-json',
      '--session-id', chatId
    ];

    if (workspacePath) {
      args.push('--workspace', workspacePath);
    }
    if (model) {
      args.push('--model', model);
    }
    if (mode === 'plan') {
      args.push('--permission-mode', 'plan');
    }

    // Message goes at the end
    args.push(message);
    return args;
  }

  getExecutable() {
    // Cache the detected executable
    if (this._executable) {
      return this._executable;
    }

    // Try both variants
    try {
      execSync('which claude', { stdio: 'pipe' });
      this._executable = 'claude';
      return 'claude';
    } catch (e) {
      try {
        execSync('which claude-code', { stdio: 'pipe' });
        this._executable = 'claude-code';
        return 'claude-code';
      } catch (e2) {
        // Default to 'claude' for error messages
        this._executable = 'claude';
        return 'claude';
      }
    }
  }

  parseCreateChatOutput(output) {
    // Session ID is generated externally, this shouldn't be called
    return output.trim();
  }

  getDisplayName() {
    return 'Claude Code';
  }

  getInstallInstructions() {
    return 'Install Claude Code CLI: https://github.com/anthropics/claude-code';
  }
}

/**
 * Google Gemini CLI Adapter
 *
 * Uses the gemini CLI tool.
 * Note: The exact CLI flags should be verified against actual Gemini CLI documentation.
 * This implementation assumes a similar structure to other AI CLIs.
 */
export class GeminiAdapter extends CLIAdapter {
  buildCreateChatArgs({ workspacePath }) {
    // Gemini CLI may not have explicit create command
    // Return marker that we need to generate a session ID
    return { needsGeneratedId: true };
  }

  buildSendMessageArgs({ chatId, message, workspacePath, model, mode }) {
    const args = ['--prompt', message];

    if (workspacePath) {
      args.push('--workspace', workspacePath);
    }
    if (model) {
      args.push('--model', model);
    }
    if (chatId) {
      args.push('--session-id', chatId);
    }

    return args;
  }

  getExecutable() {
    return 'gemini';
  }

  parseCreateChatOutput(output) {
    // Session ID is generated externally, this shouldn't be called
    return output.trim();
  }

  getDisplayName() {
    return 'Google Gemini';
  }

  getInstallInstructions() {
    return 'Install Gemini CLI: Check Google AI documentation for installation instructions';
  }
}

/**
 * Factory function to get the appropriate CLI adapter
 * @param {string} tool - Tool name ('cursor-agent', 'claude', 'gemini')
 * @returns {CLIAdapter} Adapter instance for the specified tool
 */
export function getCLIAdapter(tool) {
  switch (tool) {
    case 'cursor-agent':
      return new CursorAgentAdapter();
    case 'claude':
      return new ClaudeAdapter();
    case 'gemini':
      return new GeminiAdapter();
    default:
      throw new Error(`Unknown tool: ${tool}. Valid tools: cursor-agent, claude, gemini`);
  }
}

/**
 * Get list of all supported tools
 * @returns {Array<string>} Array of tool names
 */
export function getSupportedTools() {
  return ['cursor-agent', 'claude', 'gemini'];
}

/**
 * Check availability of all CLI tools
 * @returns {Promise<Object>} Map of tool names to availability status
 */
export async function checkAllToolsAvailability() {
  const tools = getSupportedTools();
  const availability = {};

  for (const tool of tools) {
    try {
      const adapter = getCLIAdapter(tool);
      availability[tool] = {
        available: await adapter.isAvailable(),
        displayName: adapter.getDisplayName(),
        installInstructions: adapter.getInstallInstructions()
      };
    } catch (error) {
      availability[tool] = {
        available: false,
        displayName: tool,
        installInstructions: 'Unknown tool',
        error: error.message
      };
    }
  }

  return availability;
}
