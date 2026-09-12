# Makefile for Kong API Gateway Management
# Usage: make <target>

.PHONY: help setup start stop restart logs health config test clean prod-up prod-down prod-logs

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31ml
BLUE := \033[0;34m
NC := \033[0m # No Color

# Default target
help:
	@echo "$(GREEN)🚀 Kong API Gateway Management Commands$(NC)"
	@echo ""
	@echo "$(BLUE)Setup Commands:$(NC)"
	@echo "  setup          - Complete Kong setup (first time)"
	@echo "  setup-basic    - Basic Kong configuration"
	@echo "  setup-advanced - Advanced Kong configuration"
	@echo "  dev-setup      - Create development directories"
	@echo ""
	@echo "$(BLUE)Control Commands:$(NC)"
	@echo "  start          - Start all services with Kong"
	@echo "  start-dev      - Start with development tools"
	@echo "  stop           - Stop all services"
	@echo "  restart        - Restart Kong gateway"
	@echo "  restart-all    - Restart all services"
	@echo ""
	@echo "$(BLUE)Monitoring Commands:$(NC)"
	@echo "  logs           - Show Kong logs"
	@echo "  logs-auth      - Show Auth service logs"
	@echo "  logs-chat      - Show Chat service logs"
	@echo "  health         - Check all services health"
	@echo "  status         - Show Kong status"
	@echo ""
	@echo "$(BLUE)Configuration Commands:$(NC)"
	@echo "  config         - Show Kong configuration"
	@echo "  services       - List Kong services"
	@echo "  routes         - List Kong routes"
	@echo "  plugins        - List Kong plugins"
	@echo "  consumers      - List Kong consumers"
	@echo ""
	@echo "$(BLUE)Testing Commands:$(NC)"
	@echo "  test           - Run all tests"
	@echo "  test-auth      - Test Auth service endpoints"
	@echo "  test-chat      - Test Chat service endpoints"
	@echo "  test-websocket - Test WebSocket connection"
	@echo ""
	@echo "$(BLUE)Maintenance Commands:$(NC)"
	@echo "  backup         - Backup Kong configuration"
	@echo "  restore        - Restore Kong configuration"
	@echo "  maintenance-on - Enable maintenance mode"
	@echo "  maintenance-off - Disable maintenance mode"
	@echo "  clean          - Clean up containers and volumes"
	@echo "  clean-all      - Clean everything including images"
	@echo ""
	@echo "$(BLUE)Production Commands (see deploy/README.md):$(NC)"
	@echo "  prod-up        - Build and start the trimmed prod stack (docker-compose.prod.yml)"
	@echo "  prod-down      - Stop the prod stack"
	@echo "  prod-logs      - Follow prod stack logs"

# Variables
KONG_ADMIN_URL := http://localhost:8001
KONG_PROXY_URL := http://localhost:8000
COMPOSE_FILE := docker-compose.yml

# Setup Commands
setup: dev-setup setup-basic setup-advanced
	@echo "$(GREEN)✅ Kong setup completed!$(NC)"
	@echo ""
	@echo "$(BLUE)📋 Service URLs:$(NC)"
	@echo "   🌐 Kong Proxy: $(KONG_PROXY_URL)"
	@echo "   🔧 Kong Admin: $(KONG_ADMIN_URL)"
	@echo "   🎛️  Konga UI: http://localhost:8002"
	@echo "   🔐 Auth API: $(KONG_PROXY_URL)/auth/docs"
	@echo "   💬 Chat API: $(KONG_PROXY_URL)/chat/docs"

setup-basic:
	@echo "$(BLUE)🔧 Starting basic Kong setup...$(NC)"
	@docker-compose up -d kong-database
	@echo "$(YELLOW)⏳ Waiting for database...$(NC)"
	@sleep 10
	@docker-compose up -d kong-migrations
	@docker-compose up -d kong
	@echo "$(YELLOW)⏳ Waiting for Kong to be ready...$(NC)"
	@sleep 20
	@chmod +x scripts/kong-setup.sh
	@./scripts/kong-setup.sh
	@echo "$(GREEN)✅ Basic Kong setup completed!$(NC)"

setup-advanced:
	@echo "$(BLUE)🚀 Starting advanced Kong configuration...$(NC)"
	@chmod +x scripts/kong-advanced.sh
	@./scripts/kong-advanced.sh
	@echo "$(GREEN)✅ Advanced Kong configuration completed!$(NC)"

dev-setup:
	@echo "$(BLUE)🛠️  Setting up development environment...$(NC)"
	@mkdir -p scripts logs backups ssl
	@echo "$(GREEN)✅ Development directories created!$(NC)"

# Control Commands
start:
	@echo "$(BLUE)🚀 Starting all services with Kong...$(NC)"
	@docker-compose up -d
	@echo "$(YELLOW)⏳ Waiting for services to start...$(NC)"
	@sleep 30
	@$(MAKE) health

start-dev:
	@echo "$(BLUE)🛠️  Starting services with development tools...$(NC)"
	@docker-compose --profile dev up -d
	@echo "$(YELLOW)⏳ Waiting for services to start...$(NC)"
	@sleep 30
	@$(MAKE) health

stop:
	@echo "$(BLUE)🛑 Stopping all services...$(NC)"
	@docker-compose down
	@echo "$(GREEN)✅ All services stopped!$(NC)"

restart:
	@echo "$(BLUE)🔄 Restarting Kong gateway...$(NC)"
	@docker-compose restart kong
	@echo "$(YELLOW)⏳ Waiting for Kong to be ready...$(NC)"
	@sleep 15
	@$(MAKE) health

restart-all:
	@echo "$(BLUE)🔄 Restarting all services...$(NC)"
	@docker-compose restart
	@echo "$(YELLOW)⏳ Waiting for services to be ready...$(NC)"
	@sleep 30
	@$(MAKE) health

# Production Deployment (see deploy/README.md) — trimmed, DB-less Kong, run on the VM
prod-up:
	@echo "$(BLUE)🚀 Starting production stack...$(NC)"
	@docker compose -f docker-compose.prod.yml up -d --build

prod-down:
	@echo "$(BLUE)🛑 Stopping production stack...$(NC)"
	@docker compose -f docker-compose.prod.yml down

prod-logs:
	@echo "$(BLUE)📋 Production stack logs:$(NC)"
	@docker compose -f docker-compose.prod.yml logs -f

# Monitoring Commands
logs:
	@echo "$(BLUE)📋 Kong Gateway logs:$(NC)"
	@docker-compose logs -f kong

logs-auth:
	@echo "$(BLUE)📋 Auth Service logs:$(NC)"
	@docker-compose logs -f auth-service

logs-chat:
	@echo "$(BLUE)📋 Chat Service logs:$(NC)"
	@docker-compose logs -f chat-service

health:
	@echo "$(BLUE)🏥 Checking services health...$(NC)"
	@echo ""
	@echo "$(BLUE)Kong Gateway:$(NC)"
	@curl -s $(KONG_ADMIN_URL)/status | jq '.' 2>/dev/null || curl -s $(KONG_ADMIN_URL)/status || echo "$(RED)❌ Kong not responding$(NC)"
	@echo ""
	@echo "$(BLUE)Auth Service:$(NC)"
	@curl -s $(KONG_PROXY_URL)/auth/health | jq '.' 2>/dev/null || curl -s $(KONG_PROXY_URL)/auth/health || echo "$(RED)❌ Auth service not responding$(NC)"
	@echo ""
	@echo "$(BLUE)Chat Service:$(NC)"
	@curl -s $(KONG_PROXY_URL)/chat/health | jq '.' 2>/dev/null || curl -s $(KONG_PROXY_URL)/chat/health || echo "$(RED)❌ Chat service not responding$(NC)"
	@echo ""

status:
	@echo "$(BLUE)📊 Kong Status:$(NC)"
	@curl -s $(KONG_ADMIN_URL)/status | jq '.' 2>/dev/null || curl -s $(KONG_ADMIN_URL)/status

# Configuration Commands
config:
	@echo "$(BLUE)⚙️  Kong Configuration:$(NC)"
	@curl -s $(KONG_ADMIN_URL) | jq '.' 2>/dev/null || curl -s $(KONG_ADMIN_URL)

services:
	@echo "$(BLUE)🌐 Kong Services:$(NC)"
	@curl -s $(KONG_ADMIN_URL)/services | jq '.data[] | {name: .name, host: .host, port: .port, path: .path}' 2>/dev/null || curl -s $(KONG_ADMIN_URL)/services

routes:
	@echo "$(BLUE)🛣️  Kong Routes:$(NC)"
	@curl -s $(KONG_ADMIN_URL)/routes | jq '.data[] | {name: .name, paths: .paths, methods: .methods, service: .service.name}' 2>/dev/null || curl -s $(KONG_ADMIN_URL)/routes

plugins:
	@echo "$(BLUE)🔌 Kong Plugins:$(NC)"
	@curl -s $(KONG_ADMIN_URL)/plugins | jq '.data[] | {name: .name, enabled: .enabled, service: (.service.name // "global"), route: (.route.name // "global")}' 2>/dev/null || curl -s $(KONG_ADMIN_URL)/plugins

consumers:
	@echo "$(BLUE)👥 Kong Consumers:$(NC)"
	@curl -s $(KONG_ADMIN_URL)/consumers | jq '.data[] | {username: .username, custom_id: .custom_id}' 2>/dev/null || curl -s $(KONG_ADMIN_URL)/consumers

# Testing Commands
test: test-auth test-chat
	@echo "$(GREEN)✅ All tests completed!$(NC)"

test-auth:
	@echo "$(BLUE)🧪 Testing Auth Service...$(NC)"
	@echo "Health check:"
	@curl -s $(KONG_PROXY_URL)/auth/health | jq '.' 2>/dev/null || curl -s $(KONG_PROXY_URL)/auth/health || echo "$(RED)❌ Health check failed$(NC)"
	@echo ""
	@echo "Registration test:"
	@curl -s -X POST $(KONG_PROXY_URL)/api/v1/auth/register \
		-H "Content-Type: application/json" \
		-d '{"firstName":"Test","lastName":"User","email":"test@example.com","password":"password123"}' \
		| jq '.' 2>/dev/null || echo "$(RED)❌ Registration test failed$(NC)"

test-chat:
	@echo "$(BLUE)🧪 Testing Chat Service...$(NC)"
	@echo "Health check:"
	@curl -s $(KONG_PROXY_URL)/chat/health | jq '.' 2>/dev/null || curl -s $(KONG_PROXY_URL)/chat/health || echo "$(RED)❌ Health check failed$(NC)"

test-websocket:
	@echo "$(BLUE)🧪 Testing WebSocket connection...$(NC)"
	@echo "$(YELLOW)Note: Use a WebSocket client to test ws://localhost:8000/socket.io/$(NC)"
	@echo "Example with wscat: wscat -c ws://localhost:8000/socket.io/"

# Maintenance Commands
backup:
	@echo "$(BLUE)💾 Backing up Kong configuration...$(NC)"
	@mkdir -p backups
	@curl -s $(KONG_ADMIN_URL)/services > backups/services-$(shell date +%Y%m%d-%H%M%S).json
	@curl -s $(KONG_ADMIN_URL)/routes > backups/routes-$(shell date +%Y%m%d-%H%M%S).json
	@curl -s $(KONG_ADMIN_URL)/plugins > backups/plugins-$(shell date +%Y%m%d-%H%M%S).json
	@curl -s $(KONG_ADMIN_URL)/consumers > backups/consumers-$(shell date +%Y%m%d-%H%M%S).json
	@echo "$(GREEN)✅ Backup completed in backups/ directory$(NC)"

restore:
	@echo "$(YELLOW)⚠️  Restore functionality needs manual implementation$(NC)"
	@echo "Please check the backups/ directory for available backups"
	@ls -la backups/ 2>/dev/null || echo "No backups found"

maintenance-on:
	@echo "$(YELLOW)🚧 Enabling maintenance mode...$(NC)"
	@PLUGIN_ID=$$(curl -s $(KONG_ADMIN_URL)/plugins | jq -r '.data[] | select(.name=="request-termination") | .id' 2>/dev/null); \
	if [ "$$PLUGIN_ID" != "null" ] && [ -n "$$PLUGIN_ID" ]; then \
		curl -s -X PATCH $(KONG_ADMIN_URL)/plugins/$$PLUGIN_ID -H "Content-Type: application/json" -d '{"enabled":true}' > /dev/null; \
		echo "$(GREEN)✅ Maintenance mode enabled$(NC)"; \
	else \
		echo "$(RED)❌ Maintenance plugin not found$(NC)"; \
	fi

maintenance-off:
	@echo "$(BLUE)🔧 Disabling maintenance mode...$(NC)"
	@PLUGIN_ID=$$(curl -s $(KONG_ADMIN_URL)/plugins | jq -r '.data[] | select(.name=="request-termination") | .id' 2>/dev/null); \
	if [ "$$PLUGIN_ID" != "null" ] && [ -n "$$PLUGIN_ID" ]; then \
		curl -s -X PATCH $(KONG_ADMIN_URL)/plugins/$$PLUGIN_ID -H "Content-Type: application/json" -d '{"enabled":false}' > /dev/null; \
		echo "$(GREEN)✅ Maintenance mode disabled$(NC)"; \
	else \
		echo "$(RED)❌ Maintenance plugin not found$(NC)"; \
	fi

clean:
	@echo "$(BLUE)🧹 Cleaning up containers and volumes...$(NC)"
	@docker-compose down -v
	@docker system prune -f
	@echo "$(GREEN)✅ Cleanup completed!$(NC)"

clean-all:
	@echo "$(BLUE)🧹 Cleaning everything including images...$(NC)"
	@docker-compose down -v --rmi all
	@docker system prune -af
	@echo "$(GREEN)✅ Complete cleanup done!$(NC)"

# Development helpers
kong-shell:
	@echo "$(BLUE)🐚 Opening Kong container shell...$(NC)"
	@docker-compose exec kong sh

db-shell:
	@echo "$(BLUE)🗄️  Opening Kong database shell...$(NC)"
	@docker-compose exec kong-database psql -U kong -d kong

auth-db-shell:
	@echo "$(BLUE)🗄️  Opening Auth database shell...$(NC)"
	@docker-compose exec auth-postgres psql -U postgres -d authdb

chat-db-shell:
	@echo "$(BLUE)🗄️  Opening Chat database shell...$(NC)"
	@docker-compose exec chat-postgres psql -U postgres -d chatdb

# Metrics and monitoring
metrics:
	@echo "$(BLUE)📈 Kong Metrics (Prometheus format):$(NC)"
	@curl -s $(KONG_ADMIN_URL)/metrics

admin-api:
	@echo "$(BLUE)🔧 Kong Admin API endpoints:$(NC)"
	@echo "Status: curl $(KONG_ADMIN_URL)/status"
	@echo "Services: curl $(KONG_ADMIN_URL)/services"
	@echo "Routes: curl $(KONG_ADMIN_URL)/routes"
	@echo "Plugins: curl $(KONG_ADMIN_URL)/plugins"
	@echo "Consumers: curl $(KONG_ADMIN_URL)/consumers"
	@echo "Metrics: curl $(KONG_ADMIN_URL)/metrics"

# Useful development commands
quick-start: dev-setup start setup
	@echo "$(GREEN)🚀 Quick start completed!$(NC)"
	@echo ""
	@echo "$(BLUE)📋 Service URLs:$(NC)"
	@echo "   🌐 Kong Proxy: $(KONG_PROXY_URL)"
	@echo "   🔧 Kong Admin: $(KONG_ADMIN_URL)"
	@echo "   🎛️  Konga UI: http://localhost:8002"
	@echo "   🔐 Auth API: $(KONG_PROXY_URL)/auth/docs"
	@echo "   💬 Chat API: $(KONG_PROXY_URL)/chat/docs"
	@echo ""
	@echo "$(BLUE)🧪 Quick Tests:$(NC)"
	@echo "   curl $(KONG_PROXY_URL)/auth/health"
	@echo "   curl $(KONG_PROXY_URL)/chat/health"

# Information commands
info:
	@echo "$(BLUE)ℹ️  Kong Microservices Information$(NC)"
	@echo ""
	@echo "$(BLUE)Service Endpoints:$(NC)"
	@echo "  Kong Gateway: $(KONG_PROXY_URL)"
	@echo "  Kong Admin:   $(KONG_ADMIN_URL)"
	@echo "  Konga UI:     http://localhost:8002"
	@echo ""
	@echo "$(BLUE)Health Checks:$(NC)"
	@echo "  Kong:         $(KONG_ADMIN_URL)/status"
	@echo "  Auth Service: $(KONG_PROXY_URL)/auth/health"
	@echo "  Chat Service: $(KONG_PROXY_URL)/chat/health"
	@echo ""
	@echo "$(BLUE)Documentation:$(NC)"
	@echo "  Auth API:     $(KONG_PROXY_URL)/auth/docs"
	@echo "  Chat API:     $(KONG_PROXY_URL)/chat/docs"

# Debugging commands
debug:
	@echo "$(BLUE)🔍 Kong Debug Information$(NC)"
	@echo ""
	@echo "$(BLUE)Container Status:$(NC)"
	@docker-compose ps
	@echo ""
	@echo "$(BLUE)Kong Configuration:$(NC)"
	@docker-compose exec kong kong config || echo "Kong not running"
	@echo ""
	@echo "$(BLUE)Network Connectivity:$(NC)"
	@docker-compose exec kong ping -c 3 auth-service || echo "Auth service unreachable"
	@docker-compose exec kong ping -c 3 chat-service || echo "Chat service unreachable"