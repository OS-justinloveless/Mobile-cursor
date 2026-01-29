import fs from 'fs/promises';
import path from 'path';
import os from 'os';

/**
 * SuggestionsReader - Reads rules, agents, commands, and skills from the filesystem
 * for @ and / autocomplete suggestions in the iOS app.
 */
export class SuggestionsReader {
  constructor() {
    this.homeDir = os.homedir();
    this.cache = new Map();
    this.cacheTimeout = 30000; // 30 seconds
  }

  /**
   * Parse YAML frontmatter from markdown/mdc files
   * Returns { frontmatter: {...}, content: '...' }
   */
  parseFrontmatter(content) {
    const frontmatterRegex = /^---\s*\n([\s\S]*?)\n---\s*\n?([\s\S]*)$/;
    const match = content.match(frontmatterRegex);
    
    if (!match) {
      return { frontmatter: {}, content: content };
    }

    const frontmatterText = match[1];
    const bodyContent = match[2];
    const frontmatter = {};

    // Simple YAML parsing for key: value pairs
    const lines = frontmatterText.split('\n');
    for (const line of lines) {
      const colonIndex = line.indexOf(':');
      if (colonIndex > 0) {
        const key = line.substring(0, colonIndex).trim();
        let value = line.substring(colonIndex + 1).trim();
        
        // Handle quoted strings
        if ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'"))) {
          value = value.slice(1, -1);
        }
        
        // Handle booleans
        if (value === 'true') value = true;
        else if (value === 'false') value = false;
        
        frontmatter[key] = value;
      }
    }

    return { frontmatter, content: bodyContent };
  }

  /**
   * Extract description from markdown content (first paragraph or heading)
   */
  extractDescription(content) {
    const lines = content.trim().split('\n');
    for (const line of lines) {
      const trimmed = line.trim();
      // Skip empty lines and headings
      if (!trimmed || trimmed.startsWith('#')) continue;
      // Return first non-empty, non-heading line as description
      return trimmed.substring(0, 200); // Limit to 200 chars
    }
    return null;
  }

  /**
   * Read project rules from .cursor/rules/*.mdc
   */
  async getProjectRules(projectPath) {
    const rules = [];
    const rulesDir = path.join(projectPath, '.cursor', 'rules');

    try {
      const files = await fs.readdir(rulesDir);
      
      for (const file of files) {
        if (!file.endsWith('.mdc')) continue;
        
        try {
          const filePath = path.join(rulesDir, file);
          const content = await fs.readFile(filePath, 'utf-8');
          const { frontmatter } = this.parseFrontmatter(content);
          
          const name = path.basename(file, '.mdc');
          rules.push({
            id: `rule:${name}`,
            type: 'rule',
            name: name,
            description: frontmatter.description || null,
            alwaysApply: frontmatter.alwaysApply || false,
            globs: frontmatter.globs || null,
            path: filePath
          });
        } catch (e) {
          // Skip files that can't be read
          console.error(`Error reading rule file ${file}:`, e.message);
        }
      }
    } catch (e) {
      // Rules directory doesn't exist
    }

    return rules;
  }

  /**
   * Read agents from .cursor/agents/*.md (project) + ~/.cursor/agents/*.md (user)
   */
  async getAgents(projectPath) {
    const agents = [];
    const locations = [
      { dir: path.join(projectPath, '.cursor', 'agents'), scope: 'project' },
      { dir: path.join(this.homeDir, '.cursor', 'agents'), scope: 'user' }
    ];

    for (const { dir, scope } of locations) {
      try {
        const files = await fs.readdir(dir);
        
        for (const file of files) {
          if (!file.endsWith('.md')) continue;
          
          try {
            const filePath = path.join(dir, file);
            const content = await fs.readFile(filePath, 'utf-8');
            const { frontmatter } = this.parseFrontmatter(content);
            
            const name = frontmatter.name || path.basename(file, '.md');
            
            // Check if we already have this agent (project takes priority)
            if (agents.find(a => a.name === name)) continue;
            
            agents.push({
              id: `agent:${name}`,
              type: 'agent',
              name: name,
              description: frontmatter.description || null,
              model: frontmatter.model || null,
              readonly: frontmatter.readonly || false,
              scope: scope,
              path: filePath
            });
          } catch (e) {
            console.error(`Error reading agent file ${file}:`, e.message);
          }
        }
      } catch (e) {
        // Agents directory doesn't exist
      }
    }

    return agents;
  }

  /**
   * Read commands from .cursor/commands/*.md
   */
  async getCommands(projectPath) {
    const commands = [];
    const commandsDir = path.join(projectPath, '.cursor', 'commands');

    try {
      const files = await fs.readdir(commandsDir);
      
      for (const file of files) {
        if (!file.endsWith('.md')) continue;
        
        try {
          const filePath = path.join(commandsDir, file);
          const content = await fs.readFile(filePath, 'utf-8');
          const { frontmatter, content: bodyContent } = this.parseFrontmatter(content);
          
          const name = path.basename(file, '.md');
          const description = frontmatter.description || this.extractDescription(bodyContent);
          
          commands.push({
            id: `command:${name}`,
            type: 'command',
            name: name,
            description: description,
            path: filePath
          });
        } catch (e) {
          console.error(`Error reading command file ${file}:`, e.message);
        }
      }
    } catch (e) {
      // Commands directory doesn't exist
    }

    return commands;
  }

  /**
   * Read skills from ~/.cursor/skills-cursor/ and ~/.codex/skills/
   */
  async getSkills() {
    const skills = [];
    const skillsLocations = [
      path.join(this.homeDir, '.cursor', 'skills-cursor'),
      path.join(this.homeDir, '.codex', 'skills')
    ];

    for (const skillsDir of skillsLocations) {
      try {
        const entries = await fs.readdir(skillsDir, { withFileTypes: true });
        
        for (const entry of entries) {
          if (!entry.isDirectory()) continue;
          if (entry.name.startsWith('.')) continue; // Skip hidden directories
          
          const skillFile = path.join(skillsDir, entry.name, 'SKILL.md');
          
          try {
            const content = await fs.readFile(skillFile, 'utf-8');
            const { frontmatter } = this.parseFrontmatter(content);
            
            const name = frontmatter.name || entry.name;
            
            // Skip if we already have this skill
            if (skills.find(s => s.name === name)) continue;
            
            skills.push({
              id: `skill:${name}`,
              type: 'skill',
              name: name,
              description: frontmatter.description || null,
              path: skillFile
            });
          } catch (e) {
            // SKILL.md doesn't exist in this directory
          }
        }
      } catch (e) {
        // Skills directory doesn't exist
      }
    }

    return skills;
  }

  /**
   * Search project files for @ file mentions
   */
  async searchFiles(projectPath, query, maxResults = 20) {
    const files = [];
    const skipDirs = ['node_modules', '.git', '.next', 'dist', 'build', '__pycache__', '.venv', 'venv', 'Pods'];
    
    const searchDir = async (dirPath, relativePath = '') => {
      if (files.length >= maxResults) return;
      
      try {
        const entries = await fs.readdir(dirPath, { withFileTypes: true });
        
        for (const entry of entries) {
          if (files.length >= maxResults) break;
          
          // Skip hidden and common large directories
          if (entry.name.startsWith('.')) continue;
          if (skipDirs.includes(entry.name)) continue;
          
          const fullPath = path.join(dirPath, entry.name);
          const relPath = path.join(relativePath, entry.name);
          
          if (entry.isDirectory()) {
            await searchDir(fullPath, relPath);
          } else if (entry.isFile()) {
            // Filter by query if provided
            if (query && !entry.name.toLowerCase().includes(query.toLowerCase()) &&
                !relPath.toLowerCase().includes(query.toLowerCase())) {
              continue;
            }
            
            files.push({
              id: `file:${relPath}`,
              type: 'file',
              name: entry.name,
              description: relPath,
              path: fullPath,
              relativePath: relPath
            });
          }
        }
      } catch (e) {
        // Can't read directory
      }
    };

    await searchDir(projectPath);
    return files;
  }

  /**
   * Get all suggestions for a project
   */
  async getAllSuggestions(projectPath, query = '', types = null) {
    const cacheKey = `${projectPath}:${query}:${types?.join(',') || 'all'}`;
    const cached = this.cache.get(cacheKey);
    
    if (cached && Date.now() - cached.timestamp < this.cacheTimeout) {
      return cached.data;
    }

    const allTypes = types || ['rules', 'agents', 'commands', 'skills', 'files'];
    let suggestions = [];

    // Fetch all types in parallel
    const promises = [];
    
    if (allTypes.includes('rules')) {
      promises.push(this.getProjectRules(projectPath).then(items => suggestions.push(...items)));
    }
    if (allTypes.includes('agents')) {
      promises.push(this.getAgents(projectPath).then(items => suggestions.push(...items)));
    }
    if (allTypes.includes('commands')) {
      promises.push(this.getCommands(projectPath).then(items => suggestions.push(...items)));
    }
    if (allTypes.includes('skills')) {
      promises.push(this.getSkills().then(items => suggestions.push(...items)));
    }
    if (allTypes.includes('files') && query) {
      // Only search files if there's a query (to avoid returning too many results)
      promises.push(this.searchFiles(projectPath, query).then(items => suggestions.push(...items)));
    }

    await Promise.all(promises);

    // Filter by query if provided
    if (query) {
      const lowerQuery = query.toLowerCase();
      suggestions = suggestions.filter(s => 
        s.name.toLowerCase().includes(lowerQuery) ||
        (s.description && s.description.toLowerCase().includes(lowerQuery))
      );
    }

    // Sort by type priority and name
    const typePriority = { rule: 1, agent: 2, command: 3, skill: 4, file: 5 };
    suggestions.sort((a, b) => {
      const priorityDiff = (typePriority[a.type] || 99) - (typePriority[b.type] || 99);
      if (priorityDiff !== 0) return priorityDiff;
      return a.name.localeCompare(b.name);
    });

    // Cache the results
    this.cache.set(cacheKey, { data: suggestions, timestamp: Date.now() });

    return suggestions;
  }

  /**
   * Clear the cache
   */
  clearCache() {
    this.cache.clear();
  }
}
