// client-example.js - Frontend integration example

class ChatClient {
  constructor(authServiceUrl = 'http://localhost:3001', chatServiceUrl = 'http://localhost:3002') {
    this.authUrl = authServiceUrl;
    this.chatUrl = chatServiceUrl;
    this.token = localStorage.getItem('chat_token');
    this.socket = null;
    this.currentUser = null;
    this.listeners = new Map();
  }

  // ==================== Authentication ====================
  
  async register(userData) {
    try {
      const response = await fetch(`${this.authUrl}/api/v1/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(userData)
      });

      if (!response.ok) {
        throw new Error(`Registration failed: ${response.status}`);
      }

      const user = await response.json();
      console.log('User registered:', user);
      return user;
    } catch (error) {
      console.error('Registration error:', error);
      throw error;
    }
  }

  async login(email, password) {
    try {
      const response = await fetch(`${this.authUrl}/api/v1/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password })
      });

      if (!response.ok) {
        throw new Error(`Login failed: ${response.status}`);
      }

      const { token } = await response.json();
      this.token = token;
      localStorage.setItem('chat_token', token);

      // Get current user info
      await this.getCurrentUser();
      
      // Connect to chat service
      this.connectSocket();

      return { token, user: this.currentUser };
    } catch (error) {
      console.error('Login error:', error);
      throw error;
    }
  }

  async logout() {
    try {
      if (this.token) {
        await fetch(`${this.authUrl}/api/v1/auth/logout`, {
          method: 'POST',
          headers: { 
            'Authorization': `Bearer ${this.token}`,
            'Content-Type': 'application/json'
          }
        });
      }

      this.token = null;
      this.currentUser = null;
      localStorage.removeItem('chat_token');
      
      if (this.socket) {
        this.socket.disconnect();
        this.socket = null;
      }

      console.log('Logged out successfully');
    } catch (error) {
      console.error('Logout error:', error);
    }
  }

  async getCurrentUser() {
    try {
      const response = await fetch(`${this.chatUrl}/api/users/me`, {
        headers: { 'Authorization': `Bearer ${this.token}` }
      });

      if (!response.ok) {
        throw new Error(`Failed to get user: ${response.status}`);
      }

      const { user } = await response.json();
      this.currentUser = user;
      return user;
    } catch (error) {
      console.error('Get user error:', error);
      throw error;
    }
  }

  // ==================== Chat Messaging ====================

  async sendMessage(text, roomId = 'global') {
    try {
      const response = await fetch(`${this.chatUrl}/api/messages`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ text, roomId })
      });

      if (!response.ok) {
        throw new Error(`Failed to send message: ${response.status}`);
      }

      const { message } = await response.json();
      return message;
    } catch (error) {
      console.error('Send message error:', error);
      throw error;
    }
  }

  async getMessages(roomId, limit = 50, offset = 0) {
    try {
      const params = new URLSearchParams({
        ...(roomId && { roomId }),
        limit: limit.toString(),
        offset: offset.toString()
      });

      const response = await fetch(`${this.chatUrl}/api/messages?${params}`, {
        headers: { 'Authorization': `Bearer ${this.token}` }
      });

      if (!response.ok) {
        throw new Error(`Failed to get messages: ${response.status}`);
      }

      const { messages } = await response.json();
      return messages;
    } catch (error) {
      console.error('Get messages error:', error);
      throw error;
    }
  }

  async updateMessage(messageId, text) {
    try {
      const response = await fetch(`${this.chatUrl}/api/messages/${messageId}`, {
        method: 'PUT',
        headers: {
          'Authorization': `Bearer ${this.token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ text })
      });

      if (!response.ok) {
        throw new Error(`Failed to update message: ${response.status}`);
      }

      const { message } = await response.json();
      return message;
    } catch (error) {
      console.error('Update message error:', error);
      throw error;
    }
  }

  async deleteMessage(messageId) {
    try {
      const response = await fetch(`${this.chatUrl}/api/messages/${messageId}`, {
        method: 'DELETE',
        headers: { 'Authorization': `Bearer ${this.token}` }
      });

      if (!response.ok) {
        throw new Error(`Failed to delete message: ${response.status}`);
      }

      return true;
    } catch (error) {
      console.error('Delete message error:', error);
      throw error;
    }
  }

  // ==================== Room Management ====================

  async createRoom(name, description) {
    try {
      const response = await fetch(`${this.chatUrl}/api/rooms`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${this.token}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ name, description })
      });

      if (!response.ok) {
        throw new Error(`Failed to create room: ${response.status}`);
      }

      const { room } = await response.json();
      return room;
    } catch (error) {
      console.error('Create room error:', error);
      throw error;
    }
  }

  async getRooms(limit = 20, offset = 0) {
    try {
      const params = new URLSearchParams({
        limit: limit.toString(),
        offset: offset.toString()
      });

      const response = await fetch(`${this.chatUrl}/api/rooms?${params}`, {
        headers: { 'Authorization': `Bearer ${this.token}` }
      });

      if (!response.ok) {
        throw new Error(`Failed to get rooms: ${response.status}`);
      }

      const { rooms } = await response.json();
      return rooms;
    } catch (error) {
      console.error('Get rooms error:', error);
      throw error;
    }
  }

  async joinRoom(roomId) {
    if (this.socket && this.socket.connected) {
      this.socket.emit('join:room', roomId);
      return true;
    }
    throw new Error('Socket not connected');
  }

  async leaveRoom(roomId) {
    if (this.socket && this.socket.connected) {
      this.socket.emit('leave:room', roomId);
      return true;
    }
    throw new Error('Socket not connected');
  }

  // ==================== Real-time WebSocket ====================

  connectSocket() {
    if (!this.token) {
      throw new Error('No authentication token available');
    }

    // Import socket.io-client in your project
    // npm install socket.io-client
    this.socket = io(this.chatUrl, {
      auth: { token: this.token },
      transports: ['websocket', 'polling'],
      autoConnect: true
    });

    this.socket.on('connect', () => {
      console.log('Socket connected:', this.socket.id);
      this.emit('connected', this.socket.id);
      
      // Auto-join global room
      this.socket.emit('join:room', 'global');
    });

    this.socket.on('disconnect', (reason) => {
      console.log('Socket disconnected:', reason);
      this.emit('disconnected', reason);
    });

    this.socket.on('connect_error', (error) => {
      console.error('Socket connection error:', error);
      this.emit('connectionError', error);
    });

    // Message events
    this.socket.on('message:new', (message) => {
      console.log('New message received:', message);
      this.emit('messageNew', message);
    });

    this.socket.on('message:updated', (message) => {
      console.log('Message updated:', message);
      this.emit('messageUpdated', message);
    });

    this.socket.on('message:deleted', (data) => {
      console.log('Message deleted:', data);
      this.emit('messageDeleted', data);
    });

    // User events
    this.socket.on('user:joined', (data) => {
      console.log('User joined:', data);
      this.emit('userJoined', data);
    });

    this.socket.on('user:left', (data) => {
      console.log('User left:', data);
      this.emit('userLeft', data);
    });

    this.socket.on('user:status', (data) => {
      console.log('User status:', data);
      this.emit('userStatus', data);
    });

    this.socket.on('users:online:list', (data) => {
      console.log('Online users:', data);
      this.emit('onlineUsers', data);
    });

    // Typing events
    this.socket.on('typing:user', (data) => {
      console.log('User typing:', data);
      this.emit('userTyping', data);
    });

    // Error handling
    this.socket.on('error', (error) => {
      console.error('Socket error:', error);
      this.emit('error', error);
    });
  }

  // WebSocket messaging methods
  sendMessageViaSocket(text, roomId = 'global') {
    if (!this.socket || !this.socket.connected) {
      throw new Error('Socket not connected');
    }

    this.socket.emit('message:send', { text, roomId });
  }

  startTyping(roomId) {
    if (this.socket && this.socket.connected) {
      this.socket.emit('typing:start', { roomId });
    }
  }

  stopTyping(roomId) {
    if (this.socket && this.socket.connected) {
      this.socket.emit('typing:stop', { roomId });
    }
  }

  getOnlineUsers() {
    if (this.socket && this.socket.connected) {
      this.socket.emit('users:online');
    }
  }

  // ==================== Event Handling ====================

  on(event, callback) {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, []);
    }
    this.listeners.get(event).push(callback);
  }

  off(event, callback) {
    if (this.listeners.has(event)) {
      const callbacks = this.listeners.get(event);
      const index = callbacks.indexOf(callback);
      if (index > -1) {
        callbacks.splice(index, 1);
      }
    }
  }

  emit(event, data) {
    if (this.listeners.has(event)) {
      this.listeners.get(event).forEach(callback => {
        try {
          callback(data);
        } catch (error) {
          console.error(`Error in event listener for ${event}:`, error);
        }
      });
    }
  }

  // ==================== Utils ====================

  isAuthenticated() {
    return !!this.token && !!this.currentUser;
  }

  isSocketConnected() {
    return this.socket && this.socket.connected;
  }

  disconnect() {
    if (this.socket) {
      this.socket.disconnect();
      this.socket = null;
    }
  }
}

// ==================== Usage Example ====================

// Initialize client
const chatClient = new ChatClient();

// Example: Complete chat application flow
async function initializeChatApp() {
  try {
    // Check if already logged in
    if (chatClient.token) {
      await chatClient.getCurrentUser();
      chatClient.connectSocket();
    }

    // Set up event listeners
    chatClient.on('connected', (socketId) => {
      console.log('Chat connected!', socketId);
      updateConnectionStatus('Connected');
    });

    chatClient.on('disconnected', (reason) => {
      console.log('Chat disconnected:', reason);
      updateConnectionStatus('Disconnected');
    });

    chatClient.on('messageNew', (message) => {
      addMessageToUI(message);
    });

    chatClient.on('userTyping', (data) => {
      updateTypingIndicator(data.userId, data.isTyping);
    });

    chatClient.on('onlineUsers', (data) => {
      updateOnlineUsersList(data.users);
    });

    // Set up UI event handlers
    setupUIEventHandlers();

  } catch (error) {
    console.error('Failed to initialize chat:', error);
  }
}

// UI Event Handlers
function setupUIEventHandlers() {
  // Login form
  document.getElementById('loginForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;

    try {
      await chatClient.login(email, password);
      showChatInterface();
      hideLoginInterface();
    } catch (error) {
      showError('Login failed: ' + error.message);
    }
  });

  // Registration form
  document.getElementById('registerForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const formData = new FormData(e.target);
    const userData = {
      firstName: formData.get('firstName'),
      lastName: formData.get('lastName'),
      email: formData.get('email'),
      password: formData.get('password')
    };

    try {
      await chatClient.register(userData);
      showSuccess('Registration successful! Please login.');
      showLoginInterface();
    } catch (error) {
      showError('Registration failed: ' + error.message);
    }
  });

  // Message form
  document.getElementById('messageForm')?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const messageInput = document.getElementById('messageInput');
    const text = messageInput.value.trim();

    if (!text) return;

    const currentRoom = getCurrentRoomId();

    try {
      // Send via Socket.IO for real-time or REST API for reliability
      if (chatClient.isSocketConnected()) {
        chatClient.sendMessageViaSocket(text, currentRoom);
      } else {
        await chatClient.sendMessage(text, currentRoom);
      }
      
      messageInput.value = '';
      chatClient.stopTyping(currentRoom);
    } catch (error) {
      showError('Failed to send message: ' + error.message);
    }
  });

  // Typing indicator
  let typingTimer;
  document.getElementById('messageInput')?.addEventListener('input', (e) => {
    const currentRoom = getCurrentRoomId();
    
    if (e.target.value.trim()) {
      chatClient.startTyping(currentRoom);
      
      clearTimeout(typingTimer);
      typingTimer = setTimeout(() => {
        chatClient.stopTyping(currentRoom);
      }, 1000);
    } else {
      chatClient.stopTyping(currentRoom);
    }
  });

  // Room switching
  document.querySelectorAll('.room-item').forEach(item => {
    item.addEventListener('click', async (e) => {
      const roomId = e.target.dataset.roomId;
      await switchToRoom(roomId);
    });
  });

  // Logout button
  document.getElementById('logoutBtn')?.addEventListener('click', async () => {
    await chatClient.logout();
    showLoginInterface();
    hideChatInterface();
  });
}

// UI Helper Functions
function addMessageToUI(message) {
  const messagesContainer = document.getElementById('messagesContainer');
  const messageElement = document.createElement('div');
  messageElement.className = 'message';
  messageElement.innerHTML = `
    <div class="message-header">
      <span class="message-author">${message.user.email}</span>
      <span class="message-time">${new Date(message.createdAt).toLocaleTimeString()}</span>
    </div>
    <div class="message-content">${escapeHtml(message.text)}</div>
  `;
  
  messagesContainer.appendChild(messageElement);
  messagesContainer.scrollTop = messagesContainer.scrollHeight;
}

function updateTypingIndicator(userId, isTyping) {
  const indicator = document.getElementById('typingIndicator');
  if (isTyping) {
    indicator.textContent = `${userId} is typing...`;
    indicator.style.display = 'block';
  } else {
    indicator.style.display = 'none';
  }
}

function updateOnlineUsersList(users) {
  const onlineList = document.getElementById('onlineUsers');
  onlineList.innerHTML = users.map(userId => 
    `<div class="online-user">${userId}</div>`
  ).join('');
}

function updateConnectionStatus(status) {
  const statusElement = document.getElementById('connectionStatus');
  statusElement.textContent = status;
  statusElement.className = status === 'Connected' ? 'status-connected' : 'status-disconnected';
}

async function switchToRoom(roomId) {
  try {
    // Leave current room
    const currentRoom = getCurrentRoomId();
    if (currentRoom !== roomId) {
      await chatClient.leaveRoom(currentRoom);
    }

    // Join new room
    await chatClient.joinRoom(roomId);
    
    // Load room messages
    const messages = await chatClient.getMessages(roomId);
    displayMessages(messages);
    
    // Update UI
    document.querySelectorAll('.room-item').forEach(item => {
      item.classList.toggle('active', item.dataset.roomId === roomId);
    });
    
    localStorage.setItem('currentRoom', roomId);
  } catch (error) {
    showError('Failed to switch room: ' + error.message);
  }
}

function getCurrentRoomId() {
  return localStorage.getItem('currentRoom') || 'global';
}

function displayMessages(messages) {
  const container = document.getElementById('messagesContainer');
  container.innerHTML = '';
  messages.forEach(message => addMessageToUI(message));
}

function showError(message) {
  // Implement your error display logic
  console.error(message);
  alert(message); // Replace with better UI
}

function showSuccess(message) {
  // Implement your success display logic
  console.log(message);
  alert(message); // Replace with better UI
}

function showLoginInterface() {
  document.getElementById('loginInterface').style.display = 'block';
  document.getElementById('chatInterface').style.display = 'none';
}

function hideChatInterface() {
  document.getElementById('chatInterface').style.display = 'none';
}

function showChatInterface() {
  document.getElementById('loginInterface').style.display = 'none';
  document.getElementById('chatInterface').style.display = 'block';
}

function hideLoginInterface() {
  document.getElementById('loginInterface').style.display = 'none';
}

function escapeHtml(text) {
  const div = document.createElement('div');
  div.textContent = text;
  return div.innerHTML;
}

// Initialize the app
document.addEventListener('DOMContentLoaded', initializeChatApp);

// Export for module usage
if (typeof module !== 'undefined' && module.exports) {
  module.exports = ChatClient;
}