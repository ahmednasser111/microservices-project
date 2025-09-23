#!/bin/bash

# Kong API Gateway Basic Setup Script
# This script configures Kong with services, routes, and basic plugins

set -e

KONG_ADMIN_URL="http://localhost:8001"
AUTH_SERVICE_URL="http://auth-service:3001"
CHAT_SERVICE_URL="http://chat-service:3002"

echo "🚀 Setting up Kong API Gateway for Microservices..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Function to wait for Kong to be ready
wait_for_kong() {
    print_info "Waiting for Kong to be ready..."
    local retries=0
    local max_retries=30
    
    until curl -f ${KONG_ADMIN_URL}/status &>/dev/null; do
        if [ $retries -ge $max_retries ]; then
            print_error "Kong did not become ready after ${max_retries} attempts"
            exit 1
        fi
        print_info "Kong is not ready yet. Waiting... (attempt $((retries+1))/${max_retries})"
        sleep 5
        retries=$((retries+1))
    done
    print_status "Kong is ready!"
}

# Function to create or update a service
create_service() {
    local name=$1
    local url=$2
    local retries=${3:-5}
    local connect_timeout=${4:-5000}
    local read_timeout=${5:-60000}
    local write_timeout=${6:-60000}

    print_info "Creating service: $name"
    
    # Check if service exists
    if curl -s "${KONG_ADMIN_URL}/services/${name}" | grep -q '"name"'; then
        print_info "Updating existing service: $name"
        response=$(curl -s -w "%{http_code}" -X PATCH "${KONG_ADMIN_URL}/services/${name}" \
            -H "Content-Type: application/json" \
            -d "{
                \"url\": \"${url}\",
                \"retries\": ${retries},
                \"connect_timeout\": ${connect_timeout},
                \"read_timeout\": ${read_timeout},
                \"write_timeout\": ${write_timeout}
            }")
    else
        print_info "Creating new service: $name"
        response=$(curl -s -w "%{http_code}" -X POST "${KONG_ADMIN_URL}/services" \
            -H "Content-Type: application/json" \
            -d "{
                \"name\": \"${name}\",
                \"url\": \"${url}\",
                \"retries\": ${retries},
                \"connect_timeout\": ${connect_timeout},
                \"read_timeout\": ${read_timeout},
                \"write_timeout\": ${write_timeout}
            }")
    fi
    
    http_code="${response: -3}"
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        print_status "Service $name configured successfully"
    else
        print_error "Failed to configure service $name (HTTP: $http_code)"
    fi
}

# Function to create or update a route
create_route() {
    local service_name=$1
    local route_name=$2
    local paths=$3
    local methods=${4:-"GET,POST,PUT,DELETE,PATCH,OPTIONS"}
    local strip_path=${5:-true}
    local preserve_host=${6:-false}

    print_info "Creating route: $route_name for service: $service_name"
    
    # Check if route exists
    if curl -s "${KONG_ADMIN_URL}/routes/${route_name}" | grep -q '"name"'; then
        print_info "Updating existing route: $route_name"
        response=$(curl -s -w "%{http_code}" -X PATCH "${KONG_ADMIN_URL}/routes/${route_name}" \
            -H "Content-Type: application/json" \
            -d "{
                \"paths\": [${paths}],
                \"methods\": [\"$(echo ${methods} | sed 's/,/","/g')\"],
                \"strip_path\": ${strip_path},
                \"preserve_host\": ${preserve_host}
            }")
    else
        print_info "Creating new route: $route_name"
        response=$(curl -s -w "%{http_code}" -X POST "${KONG_ADMIN_URL}/services/${service_name}/routes" \
            -H "Content-Type: application/json" \
            -d "{
                \"name\": \"${route_name}\",
                \"paths\": [${paths}],
                \"methods\": [\"$(echo ${methods} | sed 's/,/","/g')\"],
                \"strip_path\": ${strip_path},
                \"preserve_host\": ${preserve_host}
            }")
    fi
    
    http_code="${response: -3}"
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        print_status "Route $route_name configured successfully"
    else
        print_error "Failed to configure route $route_name (HTTP: $http_code)"
    fi
}

# Function to add plugin to service or route
add_plugin() {
    local target_type=$1  # "services" or "routes"
    local target_name=$2
    local plugin_name=$3
    local config=$4

    print_info "Adding plugin: $plugin_name to $target_type: $target_name"
    
    response=$(curl -s -w "%{http_code}" -X POST "${KONG_ADMIN_URL}/${target_type}/${target_name}/plugins" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"${plugin_name}\",
            \"config\": ${config}
        }")
    
    http_code="${response: -3}"
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        print_status "Plugin $plugin_name added successfully"
    else
        print_warning "Plugin $plugin_name might already exist or failed to create (HTTP: $http_code)"
    fi
}

# Function to add global plugin
add_global_plugin() {
    local plugin_name=$1
    local config=$2

    print_info "Adding global plugin: $plugin_name"
    
    response=$(curl -s -w "%{http_code}" -X POST "${KONG_ADMIN_URL}/plugins" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"${plugin_name}\",
            \"config\": ${config}
        }")
    
    http_code="${response: -3}"
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        print_status "Global plugin $plugin_name added successfully"
    else
        print_warning "Global plugin $plugin_name might already exist or failed to create (HTTP: $http_code)"
    fi
}

# Main setup function
main() {
    echo "=================================================="
    echo "🚀 Kong API Gateway Basic Setup"
    echo "=================================================="
    
    # Wait for Kong to be ready
    wait_for_kong

    print_info "Kong Status:"
    curl -s "${KONG_ADMIN_URL}/status" | jq '.' 2>/dev/null || curl -s "${KONG_ADMIN_URL}/status"
    echo ""

    # ==================== CREATE SERVICES ====================
    echo ""
    print_info "🏗️  Creating Services..."
    echo ""

    # Auth Service
    create_service "auth-service" "${AUTH_SERVICE_URL}" 5 5000 60000 60000

    # Chat Service  
    create_service "chat-service" "${CHAT_SERVICE_URL}" 5 5000 60000 60000

    print_status "All services created successfully!"

    # ==================== CREATE ROUTES ====================
    echo ""
    print_info "🛤️  Creating Routes..."
    echo ""

    # Auth Service Routes
    create_route "auth-service" "auth-api" "\"/api/v1/auth\"" "GET,POST,PUT,DELETE,OPTIONS" true false
    create_route "auth-service" "auth-health" "\"/auth/health\"" "GET" true false
    create_route "auth-service" "auth-docs" "\"/auth/docs\"" "GET" true false
    create_route "auth-service" "auth-root" "\"/auth\"" "GET" true false

    # Chat Service Routes
    create_route "chat-service" "chat-api" "\"/api\"" "GET,POST,PUT,DELETE,OPTIONS" true false
    create_route "chat-service" "chat-health" "\"/chat/health\"" "GET" true false
    create_route "chat-service" "chat-docs" "\"/chat/docs\"" "GET" true false
    create_route "chat-service" "chat-root" "\"/chat\"" "GET" true false

    # WebSocket Route for Socket.IO
    create_route "chat-service" "websocket" "\"/socket.io\"" "GET,POST" false false

    print_status "All routes created successfully!"

    # ==================== ADD BASIC PLUGINS ====================
    echo ""
    print_info "🔌 Adding Basic Plugins..."
    echo ""

    # Global CORS Plugin
    add_global_plugin "cors" '{
        "origins": ["*"],
        "methods": ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
        "headers": ["Accept", "Accept-Version", "Content-Length", "Content-MD5", "Content-Type", "Date", "Authorization", "X-Auth-Token"],
        "exposed_headers": ["X-Auth-Token"],
        "credentials": true,
        "max_age": 3600,
        "preflight_continue": false
    }'

    # Rate Limiting for Auth Service (more restrictive)
    add_plugin "services" "auth-service" "rate-limiting" '{
        "minute": 60,
        "hour": 1000,
        "policy": "local",
        "fault_tolerant": true,
        "hide_client_headers": false
    }'

    # Rate Limiting for Chat Service (more permissive)
    add_plugin "services" "chat-service" "rate-limiting" '{
        "minute": 200,
        "hour": 10000,
        "policy": "local",
        "fault_tolerant": true,
        "hide_client_headers": false
    }'

    # Request Transformer for Auth Service (add headers)
    add_plugin "services" "auth-service" "request-transformer" '{
        "add": {
            "headers": ["X-Gateway:Kong", "X-Service:auth-service"]
        }
    }'

    # Request Transformer for Chat Service (add headers)  
    add_plugin "services" "chat-service" "request-transformer" '{
        "add": {
            "headers": ["X-Gateway:Kong", "X-Service:chat-service"]
        }
    }'

    # Response Transformer for better error handling
    add_global_plugin "response-transformer" '{
        "add": {
            "headers": ["X-Powered-By:Kong-Gateway", "X-Response-Time:$upstream_response_time"]
        }
    }'

    print_status "All plugins configured successfully!"

    # ==================== VERIFICATION ====================
    echo ""
    print_info "🔍 Verifying Configuration..."
    echo ""

    print_info "📊 Services:"
    curl -s "${KONG_ADMIN_URL}/services" | jq '.data[] | {name: .name, host: .host, port: .port, path: .path}' 2>/dev/null || echo "jq not available, raw output:"

    echo ""
    print_info "🛣️  Routes:"
    curl -s "${KONG_ADMIN_URL}/routes" | jq '.data[] | {name: .name, paths: .paths, methods: .methods}' 2>/dev/null || echo "jq not available, raw output:"

    echo ""
    print_info "🔌 Plugins:"
    curl -s "${KONG_ADMIN_URL}/plugins" | jq '.data[] | {name: .name, service: .service.name, route: .route.name}' 2>/dev/null || echo "jq not available, raw output:"

    # ==================== SUCCESS MESSAGE ====================
    echo ""
    echo "=================================================="
    print_status "Kong API Gateway setup completed successfully!"
    echo "=================================================="
    echo ""
    print_info "📋 Gateway Information:"
    echo "   🌐 Proxy URL: http://localhost:8000"
    echo "   🔧 Admin API: http://localhost:8001"
    echo "   🎛️  Admin UI (Konga): http://localhost:8002"
    echo ""
    print_info "🧪 Test Commands:"
    echo "   # Test Auth Service"
    echo "   curl http://localhost:8000/auth/health"
    echo "   curl -X POST http://localhost:8000/api/v1/auth/register \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{\"firstName\":\"Test\",\"lastName\":\"User\",\"email\":\"test@example.com\",\"password\":\"password123\"}'"
    echo ""
    echo "   # Test Chat Service"
    echo "   curl http://localhost:8000/chat/health"
    echo "   curl http://localhost:8000/api/users/me -H 'Authorization: Bearer YOUR_TOKEN'"
    echo ""
    print_info "📚 Documentation:"
    echo "   🔐 Auth API: http://localhost:8000/auth/docs"
    echo "   💬 Chat API: http://localhost:8000/chat/docs"
    echo ""
    print_info "📊 Monitoring:"
    echo "   📈 Kong Status: http://localhost:8001/status"
    echo "   🔍 Kong Services: http://localhost:8001/services"
    echo "   🛣️  Kong Routes: http://localhost:8001/routes"
    echo ""
}

# Check if curl is available
if ! command -v curl &> /dev/null; then
    print_error "curl is required but not installed."
    exit 1
fi

# Run main function
main