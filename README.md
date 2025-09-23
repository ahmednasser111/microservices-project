# 🚀 Kong API Gateway for Microservices

A production-ready Kong API Gateway setup for managing Auth and Chat microservices with advanced features like JWT authentication, rate limiting, monitoring, and more.

## 🏗️ Architecture Overview

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Frontend  │    │   Mobile    │    │   3rd Party │
│  (React)    │    │    Apps     │    │    APIs     │
└─────────────┘    └─────────────┘    └─────────────┘
       │                   │                   │
       └───────────────────┼───────────────────┘
                           │
                    ┌─────────────┐
                    │    Kong     │
                    │ API Gateway │
                    │   :8000     │
                    └─────────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
      ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
      │ Auth Service│ │Chat Service │ │   Future    │
      │   :3001     │ │   :3002     │ │  Services   │
      └─────────────┘ └─────────────┘ └─────────────┘
```

## 🎯 Features

### Core Kong Features

- ✅ **API Gateway**: Single entry point for all microservices
- ✅ **Load Balancing**: Distribute traffic across service instances
- ✅ **Rate Limiting**: Protect services from abuse
- ✅ **Authentication**: JWT, API Key, OAuth2 support
- ✅ **SSL/TLS Termination**: Handle HTTPS encryption
- ✅ **Request/Response Transformation**: Modify requests and responses
- ✅ **Logging & Monitoring**: Comprehensive observability
- ✅ **Health Checks**: Monitor service availability
- ✅ **CORS Support**: Handle cross-origin requests
- ✅ **WebSocket Support**: Real-time communication proxy

### Advanced Features

- ✅ **Prometheus Metrics**: Performance monitoring
- ✅ **Custom Error Pages**: Branded error responses
- ✅ **IP Restrictions**: Whitelist/blacklist IP addresses
- ✅ **Request Size Limiting**: Prevent large payload attacks
- ✅ **Maintenance Mode**: Graceful service maintenance
- ✅ **Admin UI**: Konga web interface for management

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- curl and jq (for testing)
- Make (optional, for convenience commands)

### 1. Clone and Setup

```bash
# Create project directory
mkdir kong-microservices && cd kong-microservices

# Create directory structure
mkdir -p scripts ssl logs backups

# Copy Kong files (docker-compose.yml, scripts, etc.)
```

### 2. Start Kong with Microservices

```bash
# Using Make (recommended)
make quick-start

# Or manually
docker-compose up -d
sleep 30
chmod +x scripts/kong-setup.sh && ./scripts/kong-setup.sh
chmod +x scripts/kong-advanced.sh && ./scripts/kong-advanced.sh
```

### 3. Verify Setup

```bash
# Check all services
make health

# Or manually check
curl http://localhost:8000/gateway/health
curl http://localhost:8001/status
curl http://localhost:8000/auth/health
curl http://localhost:8000/chat/health
```

## 🌐 Service URLs

| Service                | URL                             | Description              |
| ---------------------- | ------------------------------- | ------------------------ |
| **Kong Proxy**         | http://localhost:8000           | Main gateway endpoint    |
| **Kong Admin API**     | http://localhost:8001           | Configuration API        |
| **Konga Admin UI**     | http://localhost:8002           | Web management interface |
| **Auth Service**       | http://localhost:8000/auth      | Authentication API       |
| **Chat Service**       | http://localhost:8000/chat      | Chat API                 |
| **Auth Docs**          | http://localhost:8000/auth/docs | API documentation        |
| **Chat Docs**          | http://localhost:8000/chat/docs | API documentation        |
| **Prometheus Metrics** | http://localhost:8001/metrics   | Performance metrics      |

## 📡 API Routes

### Authentication Routes

```http
POST /api/v1/auth/register     # User registration
POST /api/v1/auth/login        # User login
POST /api/v1/auth/logout       # User logout
GET  /auth/health              # Service health
GET  /auth/docs                # API documentation
```

### Chat Service Routes

```http
# Messages
GET    /api/messages                    # Get messages
POST   /api/messages                    # Send message
PUT    /api/messages/{id}               # Update message
DELETE /api/messages/{id}               # Delete message

# Rooms
GET    /api/rooms                       # Get rooms
POST   /api/rooms                       # Create room
GET    /api/rooms/{id}                  # Get room details
PUT    /api/rooms/{id}                  # Update room
DELETE /api/rooms/{id}                  # Delete room

# Users
GET    /api/users/me                    # Get current user
GET    /api/users                       # Get all users
GET    /api/users/{id}                  # Get user by ID

# WebSocket
WS     /socket.io/                      # Real-time connection

# Health & Docs
GET    /chat/health                     # Service health
GET    /chat/docs                       # API documentation
```

## 🧪 Testing the Gateway

### 1. Test Auth Service

```bash
# Health check
curl http://localhost:8000/auth/health

# User registration
curl -X POST http://localhost:8000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "John",
    "lastName": "Doe",
    "email": "john@example.com",
    "password": "password123"
  }'

# User login
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "john@example.com",
    "password": "password123"
  }'
```

### 2. Test Chat Service

```bash
# Health check
curl http://localhost:8000/chat/health

# Get current user (requires JWT token)
curl http://localhost:8000/api/users/me \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# Send a message
curl -X POST http://localhost:8000/api/messages \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "text": "Hello from Kong Gateway!",
    "roomId": "global"
  }'
```

### 3. Test WebSocket Connection

```javascript
// Frontend JavaScript
const socket = io("http://localhost:8000", {
	auth: { token: "YOUR_JWT_TOKEN" },
});

socket.on("connect", () => {
	console.log("Connected via Kong Gateway!");

	// Join a room
	socket.emit("join:room", "global");

	// Send message
	socket.emit("message:send", {
		text: "Hello WebSocket via Kong!",
		roomId: "global",
	});
});
```

## ⚙️ Configuration Management

### Using Make Commands

```bash
# Show all available commands
make help

# Start services
make start              # Start all services
make start-dev          # Start with development tools

# Monitoring
make health             # Check all services health
make logs               # Show Kong logs
make status             # Show Kong status

# Configuration
make services           # List Kong services
make routes             # List Kong routes
make plugins            # List Kong plugins
make config             # Show Kong configuration

# Testing
make test               # Run all tests
make test-auth          # Test auth service
make test-chat          # Test chat service

# Maintenance
make backup             # Backup configuration
make clean              # Clean containers
make restart            # Restart Kong
```

### Using Kong Admin API

```bash
# List all services
curl http://localhost:8001/services

# List all routes
curl http://localhost:8001/routes

# List all plugins
curl http://localhost:8001/plugins

# Check Kong status
curl http://localhost:8001/status

# Get metrics
curl http://localhost:8001/metrics
```

## 🔧 Advanced Configuration

### 1. Enable JWT Authentication

```bash
# Create consumer
curl -X POST http://localhost:8001/consumers \
  -H "Content-Type: application/json" \
  -d '{"username": "my-app"}'

# Add JWT credentials
curl -X POST http://localhost:8001/consumers/my-app/jwt \
  -H "Content-Type: application/json" \
  -d '{
    "key": "my-jwt-key",
    "secret": "my-jwt-secret"
  }'

# Enable JWT plugin on a service
curl -X POST http://localhost:8001/services/auth-service/plugins \
  -H "Content-Type: application/json" \
  -d '{"name": "jwt"}'
```

### 2. Configure Rate Limiting

```bash
# Add rate limiting to auth service
curl -X POST http://localhost:8001/services/auth-service/plugins \
  -H "Content-Type: application/json" \
  -d '{
    "name": "rate-limiting",
    "config": {
      "minute": 20,
      "hour": 500,
      "policy": "local"
    }
  }'
```

### 3. Enable Maintenance Mode

```bash
# Get maintenance plugin ID
PLUGIN_ID=$(curl -s http://localhost:8001/plugins | jq -r '.data[] | select(.name=="request-termination") | .id')

# Enable maintenance mode
curl -X PATCH http://localhost:8001/plugins/$PLUGIN_ID \
  -H "Content-Type: application/json" \
  -d '{"enabled": true}'

# Disable maintenance mode
curl -X PATCH http://localhost:8001/plugins/$PLUGIN_ID \
  -H "Content-Type: application/json" \
  -d '{"enabled": false}'
```

## 📊 Monitoring & Observability

### 1. Prometheus Metrics

```bash
# Get all metrics
curl http://localhost:8001/metrics

# Specific metrics
curl http://localhost:8001/metrics | grep kong_http_requests_total
curl http://localhost:8001/metrics | grep kong_latency
```

### 2. Health Monitoring

```bash
# Kong health
curl http://localhost:8001/status

# Service health through gateway
curl http://localhost:8000/auth/health
curl http://localhost:8000/chat/health

# Gateway health endpoint
curl http://localhost:8000/gateway/health
```

### 3. Log Analysis

```bash
# Kong logs
docker-compose logs -f kong

# Service logs
docker-compose logs -f auth-service chat-service

# Access logs (if file logging is enabled)
docker-compose exec kong tail -f /tmp/kong_requests.log
```

## 🔐 Security Features

### 1. CORS Configuration

- Configured globally with secure defaults
- Allows credentials for authenticated requests
- Configurable origins per environment

### 2. Security Headers

- X-Frame-Options: DENY
- X-Content-Type-Options: nosniff
- X-XSS-Protection: 1; mode=block
- Strict-Transport-Security (HTTPS)

### 3. Rate Limiting

- Different limits for auth vs chat services
- IP-based limiting with Redis backend
- Configurable burst and sustained rates

### 4. IP Restrictions

- Whitelist/blacklist support
- Configurable per service or globally
- Development mode allows all IPs

## 🚀 Production Deployment

### 1. Environment Variables

```bash
# Copy production environment
cp .env.kong .env.production

# Update for production
KONG_LOG_LEVEL=warn
KONG_ADMIN_LISTEN=127.0.0.1:8001
KONG_ADMIN_GUI_AUTH=basic-auth
```

### 2. SSL Configuration

```bash
# Generate production certificates
openssl req -x509 -newkey rsa:4096 \
  -keyout ssl/kong-prod.key \
  -out ssl/kong-prod.crt \
  -days 365 -nodes

# Update docker-compose for SSL
```

### 3. Database Security

```bash
# Use strong passwords
KONG_PG_PASSWORD=secure-random-password

# Enable SSL for database
KONG_PG_SSL=on
KONG_PG_SSL_VERIFY=on
```

### 4. Scaling Configuration

```bash
# Scale Kong instances
docker-compose up -d --scale kong=3

# Use external load balancer
# Configure Kong behind nginx/ALB/etc
```

## 🛠️ Troubleshooting

### Common Issues

1. **Kong not starting**

   ```bash
   # Check database connection
   docker-compose logs kong-database

   # Check migrations
   docker-compose logs kong-migrations

   # Verify Kong configuration
   docker-compose exec kong kong config
   ```

2. **Services not responding**

   ```bash
   # Check service health
   make health

   # Verify Kong routes
   curl http://localhost:8001/routes

   # Check service connectivity
   docker-compose exec kong ping auth-service
   ```

3. **WebSocket issues**

   ```bash
   # Check WebSocket route
   curl http://localhost:8001/routes | jq '.data[] | select(.name=="websocket")'

   # Verify upstream connection
   docker-compose logs chat-service | grep socket
   ```

### Debug Commands

```bash
# Kong configuration check
docker-compose exec kong kong config

# Test service connectivity
docker-compose exec kong curl http://auth-service:3001/health

# Check plugin configuration
curl http://localhost:8001/plugins | jq '.data[] | {name, enabled, config}'

# Verify route matching
curl -I http://localhost:8000/api/users/me
```

## 📚 Additional Resources

- [Kong Documentation](https://docs.konghq.com/)
- [Kong Plugin Hub](https://docs.konghq.com/hub/)
- [Konga Admin UI](https://github.com/pantsel/konga)
- [Kong Docker Images](https://hub.docker.com/_/kong)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 👨‍💻 Author

**Ahmed Nasser**

- GitHub: [@ahmednasser111](https://github.com/ahmednasser111)
- Email: ahmednaser7707@gmail.com

---

## 🆘 Support

For issues and questions:

- Create an issue in the GitHub repository
- Check Kong documentation
- Review the troubleshooting section above
- Contact the development team
