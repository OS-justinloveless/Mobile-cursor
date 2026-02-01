import fs from 'fs/promises';
import { existsSync, mkdirSync, appendFileSync, createReadStream } from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

// Get the directory of this module for consistent path resolution
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * LogManager - Server-side logging with file persistence
 * 
 * Provides structured logging that writes to files and can be retrieved
 * via API for viewing in the mobile app.
 * 
 * Log Levels:
 * - debug: Verbose debugging information
 * - info: General informational messages
 * - warn: Warning conditions
 * - error: Error conditions
 * 
 * Features:
 * - Writes to daily rotating log files
 * - In-memory buffer for recent logs
 * - API-accessible log retrieval
 * - Structured JSON log entries
 */

// Singleton instance
let _instance = null;

// Configuration
const MAX_MEMORY_LOGS = 500; // Keep last 500 logs in memory
const MAX_LOG_FILES = 7; // Keep 7 days of log files
const LOG_LEVELS = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3
};

export class LogManager {
  constructor() {
    // Use the server directory (parent of utils) for consistent path
    const serverDir = path.resolve(__dirname, '../..');
    this.logsDir = path.join(serverDir, '.napp-trapp-data', 'logs');
    this.memoryLogs = [];
    this.minLevel = process.env.LOG_LEVEL || 'info';
    
    // Ensure logs directory exists
    if (!existsSync(this.logsDir)) {
      mkdirSync(this.logsDir, { recursive: true });
    }
    
    // Clean up old log files on startup
    this.cleanupOldLogs();
  }
  
  /**
   * Get the singleton instance of LogManager
   */
  static getInstance() {
    if (!_instance) {
      _instance = new LogManager();
    }
    return _instance;
  }
  
  /**
   * Get the current log file path (daily rotation)
   */
  getCurrentLogFile() {
    const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
    return path.join(this.logsDir, `server-${today}.log`);
  }
  
  /**
   * Check if a message should be logged based on level
   */
  shouldLog(level) {
    return LOG_LEVELS[level] >= LOG_LEVELS[this.minLevel];
  }
  
  /**
   * Create a log entry
   */
  createLogEntry(level, category, message, data = null) {
    const entry = {
      timestamp: new Date().toISOString(),
      level,
      category,
      message,
      data: data || undefined
    };
    return entry;
  }
  
  /**
   * Write a log entry
   */
  log(level, category, message, data = null) {
    if (!this.shouldLog(level)) {
      return;
    }
    
    const entry = this.createLogEntry(level, category, message, data);
    
    // Add to memory buffer
    this.memoryLogs.push(entry);
    if (this.memoryLogs.length > MAX_MEMORY_LOGS) {
      this.memoryLogs.shift(); // Remove oldest
    }
    
    // Write to file (synchronous for reliability)
    const logLine = JSON.stringify(entry) + '\n';
    try {
      appendFileSync(this.getCurrentLogFile(), logLine, 'utf-8');
    } catch (err) {
      console.error('Failed to write log:', err);
    }
    
    // Also write to console with formatting
    const consolePrefix = `[${entry.timestamp}] [${level.toUpperCase()}] [${category}]`;
    if (level === 'error') {
      console.error(consolePrefix, message, data || '');
    } else if (level === 'warn') {
      console.warn(consolePrefix, message, data || '');
    } else {
      console.log(consolePrefix, message, data || '');
    }
  }
  
  // Convenience methods
  debug(category, message, data = null) {
    this.log('debug', category, message, data);
  }
  
  info(category, message, data = null) {
    this.log('info', category, message, data);
  }
  
  warn(category, message, data = null) {
    this.log('warn', category, message, data);
  }
  
  error(category, message, data = null) {
    this.log('error', category, message, data);
  }
  
  /**
   * Get recent logs from memory
   */
  getRecentLogs(options = {}) {
    const { 
      limit = 100, 
      level = null, 
      category = null,
      since = null 
    } = options;
    
    let logs = [...this.memoryLogs];
    
    // Filter by level
    if (level) {
      const minLevel = LOG_LEVELS[level] || 0;
      logs = logs.filter(log => LOG_LEVELS[log.level] >= minLevel);
    }
    
    // Filter by category
    if (category) {
      logs = logs.filter(log => log.category.includes(category));
    }
    
    // Filter by time
    if (since) {
      const sinceDate = new Date(since);
      logs = logs.filter(log => new Date(log.timestamp) >= sinceDate);
    }
    
    // Return most recent, limited
    return logs.slice(-limit).reverse();
  }
  
  /**
   * Get logs from a specific date
   */
  async getLogsForDate(date, options = {}) {
    const { limit = 200, level = null, category = null } = options;
    
    const dateStr = date instanceof Date 
      ? date.toISOString().split('T')[0] 
      : date;
    
    const logFile = path.join(this.logsDir, `server-${dateStr}.log`);
    
    if (!existsSync(logFile)) {
      return [];
    }
    
    try {
      const content = await fs.readFile(logFile, 'utf-8');
      const lines = content.trim().split('\n').filter(Boolean);
      
      let logs = lines.map(line => {
        try {
          return JSON.parse(line);
        } catch {
          return null;
        }
      }).filter(Boolean);
      
      // Apply filters
      if (level) {
        const minLevel = LOG_LEVELS[level] || 0;
        logs = logs.filter(log => LOG_LEVELS[log.level] >= minLevel);
      }
      
      if (category) {
        logs = logs.filter(log => log.category.includes(category));
      }
      
      // Return most recent, limited
      return logs.slice(-limit).reverse();
    } catch (err) {
      this.error('LogManager', 'Failed to read log file', { file: logFile, error: err.message });
      return [];
    }
  }
  
  /**
   * Get available log dates
   */
  async getAvailableLogDates() {
    try {
      const files = await fs.readdir(this.logsDir);
      const logFiles = files.filter(f => f.startsWith('server-') && f.endsWith('.log'));
      
      return logFiles.map(f => {
        const match = f.match(/server-(\d{4}-\d{2}-\d{2})\.log/);
        return match ? match[1] : null;
      }).filter(Boolean).sort().reverse();
    } catch {
      return [];
    }
  }
  
  /**
   * Clean up old log files
   */
  async cleanupOldLogs() {
    try {
      const files = await fs.readdir(this.logsDir);
      const logFiles = files
        .filter(f => f.startsWith('server-') && f.endsWith('.log'))
        .sort()
        .reverse();
      
      // Keep only MAX_LOG_FILES recent files
      if (logFiles.length > MAX_LOG_FILES) {
        const toDelete = logFiles.slice(MAX_LOG_FILES);
        for (const file of toDelete) {
          await fs.unlink(path.join(this.logsDir, file));
          console.log(`[LogManager] Deleted old log file: ${file}`);
        }
      }
    } catch (err) {
      console.error('[LogManager] Failed to cleanup old logs:', err);
    }
  }
  
  /**
   * Clear all logs (for testing/debug)
   */
  async clearAllLogs() {
    this.memoryLogs = [];
    
    try {
      const files = await fs.readdir(this.logsDir);
      for (const file of files) {
        if (file.endsWith('.log')) {
          await fs.unlink(path.join(this.logsDir, file));
        }
      }
    } catch (err) {
      console.error('[LogManager] Failed to clear logs:', err);
    }
  }
}

// Export singleton getter for convenience
export const logger = LogManager.getInstance();
