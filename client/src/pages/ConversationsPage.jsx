import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../context/AuthContext';
import styles from './ConversationsPage.module.css';

// Tool display information
const TOOL_INFO = {
  'cursor-agent': { icon: '🤖', name: 'Cursor Agent', color: '#007acc' },
  'claude': { icon: '🧠', name: 'Claude Code', color: '#a855f7' },
  'gemini': { icon: '✨', name: 'Gemini', color: '#f97316' },
  'default': { icon: '💻', name: 'Terminal', color: '#6b7280' }
};

export default function ConversationsPage() {
  const [chats, setChats] = useState([]);
  const [filteredChats, setFilteredChats] = useState([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  
  const { apiRequest } = useAuth();
  const navigate = useNavigate();

  useEffect(() => {
    loadChats();
  }, []);

  useEffect(() => {
    filterChats();
  }, [chats, searchQuery]);

  async function loadChats() {
    try {
      setIsLoading(true);
      setError(null);
      
      const response = await apiRequest('/api/conversations');
      const data = await response.json();
      
      // New API returns { chats: [...], total: number }
      setChats(data.chats || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setIsLoading(false);
    }
  }

  function filterChats() {
    let filtered = [...chats];
    
    // Apply search filter
    if (searchQuery.trim()) {
      const query = searchQuery.toLowerCase();
      filtered = filtered.filter(chat => 
        chat.windowName?.toLowerCase().includes(query) ||
        chat.tool?.toLowerCase().includes(query) ||
        chat.topic?.toLowerCase().includes(query) ||
        chat.title?.toLowerCase().includes(query)
      );
    }
    
    setFilteredChats(filtered);
  }

  function selectChat(chat) {
    // Navigate to chat detail page with terminal ID
    navigate(`/chat/${chat.id || chat.terminalId}`);
  }

  function getToolInfo(toolName) {
    return TOOL_INFO[toolName] || TOOL_INFO['default'];
  }

  function getDisplayTitle(chat) {
    if (chat.topic) return chat.topic;
    if (chat.title) return chat.title;
    return chat.windowName || 'Chat Window';
  }

  return (
    <div className={styles.container}>
      {/* Search Bar */}
      <div className={styles.searchBar}>
        <input
          type="text"
          placeholder="Search chat windows..."
          value={searchQuery}
          onChange={(e) => setSearchQuery(e.target.value)}
          className={styles.searchInput}
        />
        <button 
          className={styles.refreshButton}
          onClick={loadChats}
          title="Refresh"
        >
          ↻
        </button>
      </div>
      
      {/* Chat count */}
      <div className={styles.filterTabs}>
        <span className={styles.chatCount}>
          💬 {chats.length} Chat Window{chats.length !== 1 ? 's' : ''}
        </span>
      </div>

      {isLoading ? (
        <div className={styles.loading}>
          <div className={styles.spinner} />
          <p>Loading chat windows...</p>
        </div>
      ) : error ? (
        <div className={styles.error}>
          <p>{error}</p>
          <button onClick={loadChats}>Retry</button>
        </div>
      ) : filteredChats.length === 0 ? (
        <div className={styles.empty}>
          <span className={styles.emptyIcon}>💬</span>
          <h3>No chat windows found</h3>
          <p>
            {searchQuery 
              ? 'Try adjusting your search query' 
              : 'Chat windows are created from projects using AI CLI tools'}
          </p>
        </div>
      ) : (
        <div className={styles.conversationList}>
          {filteredChats.map((chat) => {
            const toolInfo = getToolInfo(chat.tool);
            return (
              <div 
                key={chat.id || chat.terminalId}
                className={styles.conversationCard}
                onClick={() => selectChat(chat)}
              >
                <span className={styles.conversationIcon}>
                  {toolInfo.icon}
                </span>
                <div className={styles.conversationInfo}>
                  <h3 className={styles.conversationName}>
                    {getDisplayTitle(chat)}
                  </h3>
                  <div className={styles.conversationMeta}>
                    <span 
                      className={styles.typeTag}
                      style={{ backgroundColor: `${toolInfo.color}20`, color: toolInfo.color }}
                    >
                      {toolInfo.name}
                    </span>
                    <span className={styles.projectName}>
                      {chat.windowName}
                    </span>
                  </div>
                  <div className={styles.conversationFooter}>
                    <span className={styles.messageCount}>
                      {chat.active ? '🟢 Active' : '⚫ Inactive'}
                    </span>
                    {chat.sessionName && (
                      <span className={styles.conversationDate}>
                        Session: {chat.sessionName}
                      </span>
                    )}
                  </div>
                </div>
                <span className={styles.arrow}>›</span>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
