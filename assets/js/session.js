// Session management for game reconnection
class SessionManager {
  constructor() {
    this.storageKey = 'rachel_game_session';
  }
  
  // Save session information
  saveSession(sessionToken, gameId, playerId) {
    const sessionData = {
      token: sessionToken,
      gameId: gameId,
      playerId: playerId,
      timestamp: Date.now()
    };
    
    localStorage.setItem(this.storageKey, JSON.stringify(sessionData));
  }
  
  // Get saved session
  getSession() {
    const data = localStorage.getItem(this.storageKey);
    if (!data) return null;
    
    try {
      const session = JSON.parse(data);
      
      // Check if session is less than 5 minutes old
      const fiveMinutes = 5 * 60 * 1000;
      if (Date.now() - session.timestamp > fiveMinutes) {
        this.clearSession();
        return null;
      }
      
      return session;
    } catch (e) {
      console.error('Failed to parse session data:', e);
      this.clearSession();
      return null;
    }
  }
  
  // Clear session
  clearSession() {
    localStorage.removeItem(this.storageKey);
  }
  
  // Update session timestamp (for activity tracking)
  updateTimestamp() {
    const session = this.getSession();
    if (session) {
      session.timestamp = Date.now();
      localStorage.setItem(this.storageKey, JSON.stringify(session));
    }
  }
}

// Reconnection hooks for Phoenix LiveView
export const ReconnectionHooks = {
  // Hook to handle session persistence
  SessionPersistence: {
    mounted() {
      this.sessionManager = new SessionManager();
      
      // Listen for session creation
      this.handleEvent("session_created", ({token, gameId, playerId}) => {
        this.sessionManager.saveSession(token, gameId, playerId);
      });
      
      // Listen for session clear
      this.handleEvent("session_cleared", () => {
        this.sessionManager.clearSession();
      });
      
      // Send existing session on mount
      const session = this.sessionManager.getSession();
      if (session) {
        this.pushEvent("restore_session", session);
      }
      
      // Update timestamp on activity
      window.addEventListener('click', () => {
        this.sessionManager.updateTimestamp();
      });
      
      window.addEventListener('keypress', () => {
        this.sessionManager.updateTimestamp();
      });
    },
    
    destroyed() {
      // Clean up event listeners if needed
    }
  },
  
  // Visual indicator for connection status
  ConnectionStatus: {
    mounted() {
      this.handleEvent("connection_status", ({status}) => {
        this.updateStatusDisplay(status);
      });
      
      // Monitor Phoenix socket connection
      window.addEventListener("phx:page-loading-start", () => {
        this.updateStatusDisplay('connecting');
      });
      
      window.addEventListener("phx:page-loading-stop", () => {
        this.updateStatusDisplay('connected');
      });
      
      // Handle offline/online events
      window.addEventListener('online', () => {
        this.pushEvent("connection_restored", {});
      });
      
      window.addEventListener('offline', () => {
        this.updateStatusDisplay('disconnected');
      });
    },
    
    updateStatusDisplay(status) {
      const statusEl = this.el;
      
      // Remove all status classes
      statusEl.classList.remove('connected', 'disconnected', 'connecting', 'reconnecting');
      
      // Add current status class
      statusEl.classList.add(status);
      
      // Update text
      const textEl = statusEl.querySelector('.status-text');
      if (textEl) {
        switch(status) {
          case 'connected':
            textEl.textContent = '🟢 Connected';
            break;
          case 'disconnected':
            textEl.textContent = '🔴 Disconnected';
            break;
          case 'connecting':
            textEl.textContent = '🟡 Connecting...';
            break;
          case 'reconnecting':
            textEl.textContent = '🟡 Reconnecting...';
            break;
          default:
            textEl.textContent = '⚪ Unknown';
        }
      }
    }
  },
  
  // Auto-reconnect handler
  AutoReconnect: {
    mounted() {
      this.reconnectAttempts = 0;
      this.maxReconnectAttempts = 5;
      this.reconnectDelay = 1000; // Start with 1 second
      
      // Listen for disconnect events
      this.handleEvent("disconnected", () => {
        this.attemptReconnect();
      });
      
      // Listen for successful reconnection
      this.handleEvent("reconnected", () => {
        this.reconnectAttempts = 0;
        this.reconnectDelay = 1000;
      });
    },
    
    attemptReconnect() {
      if (this.reconnectAttempts >= this.maxReconnectAttempts) {
        console.error('Max reconnection attempts reached');
        this.pushEvent("reconnect_failed", {});
        return;
      }
      
      this.reconnectAttempts++;
      
      setTimeout(() => {
        console.log(`Reconnection attempt ${this.reconnectAttempts}...`);
        this.pushEvent("attempt_reconnect", {});
        
        // Exponential backoff
        this.reconnectDelay = Math.min(this.reconnectDelay * 2, 30000);
      }, this.reconnectDelay);
    }
  }
};

export default SessionManager;