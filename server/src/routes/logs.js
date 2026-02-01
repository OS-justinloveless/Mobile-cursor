import { Router } from 'express';
import { LogManager } from '../utils/LogManager.js';

const router = Router();
const logManager = LogManager.getInstance();

/**
 * GET /api/logs
 * Get recent logs from memory
 * 
 * Query params:
 * - limit: Number of logs to return (default 100, max 500)
 * - level: Minimum log level (debug, info, warn, error)
 * - category: Filter by category (partial match)
 * - since: ISO timestamp to filter logs after
 */
router.get('/', async (req, res) => {
  try {
    const { limit = 100, level, category, since } = req.query;
    
    const logs = logManager.getRecentLogs({
      limit: Math.min(parseInt(limit) || 100, 500),
      level,
      category,
      since
    });
    
    res.json({
      logs,
      count: logs.length,
      levels: ['debug', 'info', 'warn', 'error']
    });
  } catch (error) {
    logManager.error('LogsAPI', 'Failed to get logs', { error: error.message });
    res.status(500).json({ error: 'Failed to retrieve logs' });
  }
});

/**
 * GET /api/logs/dates
 * Get available log dates
 */
router.get('/dates', async (req, res) => {
  try {
    const dates = await logManager.getAvailableLogDates();
    res.json({ dates });
  } catch (error) {
    logManager.error('LogsAPI', 'Failed to get log dates', { error: error.message });
    res.status(500).json({ error: 'Failed to retrieve log dates' });
  }
});

/**
 * GET /api/logs/date/:date
 * Get logs for a specific date
 * 
 * Params:
 * - date: Date in YYYY-MM-DD format
 * 
 * Query params:
 * - limit: Number of logs to return (default 200, max 1000)
 * - level: Minimum log level
 * - category: Filter by category
 */
router.get('/date/:date', async (req, res) => {
  try {
    const { date } = req.params;
    const { limit = 200, level, category } = req.query;
    
    // Validate date format
    if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
      return res.status(400).json({ error: 'Invalid date format. Use YYYY-MM-DD' });
    }
    
    const logs = await logManager.getLogsForDate(date, {
      limit: Math.min(parseInt(limit) || 200, 1000),
      level,
      category
    });
    
    res.json({
      logs,
      count: logs.length,
      date
    });
  } catch (error) {
    logManager.error('LogsAPI', 'Failed to get logs for date', { date: req.params.date, error: error.message });
    res.status(500).json({ error: 'Failed to retrieve logs for date' });
  }
});

/**
 * DELETE /api/logs
 * Clear all logs (for debugging/testing)
 */
router.delete('/', async (req, res) => {
  try {
    await logManager.clearAllLogs();
    res.json({ success: true, message: 'All logs cleared' });
  } catch (error) {
    logManager.error('LogsAPI', 'Failed to clear logs', { error: error.message });
    res.status(500).json({ error: 'Failed to clear logs' });
  }
});

export { router as logsRoutes };
