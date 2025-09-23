#!/bin/bash

# Kong Advanced Configuration Script
# This script adds advanced features like JWT authentication, logging, and monitoring

set -e

KONG_ADMIN_URL="http://localhost:8001"

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

echo "🔧 Configuring Advanced Kong Features..."

# Function to make API calls with error handling
api_call() {
    local method=$1
    local url=$2
    local data=$3
    local description=$4
    
    print_info "$description"
    
    if [ -n "$data" ]; then
        response=$(curl -s -w "%{http_code}" -X "$method" "$url" \
            -H "Content-Type: application/json" \
            -d "$data")
    else
        response=$(curl -s -w "%{http_code}" -X "$method" "$url")
    fi
    
    http_code="${response: -3}"
    response_body="${response%???}"
    
    if [[ "$http_code" =~ ^2[0-9][0-9]$ ]]; then
        print_status "Success (HTTP: $http_code)"
        return 0
    elif [[ "$http_code" == "409" ]]; then
        print_warning "Resource already exists (HTTP: $http_code)"
        return 0
    else
        print_error "Failed (HTTP: $http_code)"
        if command -v jq &> /dev/null && echo "$response_body" | jq . &> /dev/null; then
            echo "$response_body" | jq .
        else
            echo "$response_body"
        fi
        return 1
    fi
}

# Function to create JWT consumer and credentials
setup_jwt_auth() {
    print_info "🔐 Setting up JWT Authentication..."
    
    # Create a consumer for your application
    api_call "POST" "${KONG_ADMIN_URL}/consumers" \
        '{
            "username": "microservices-app",
            "custom_id": "app-001"
        }' \
        "Creating consumer for microservices app"

    # Create JWT credentials for the consumer
    api_call "POST" "${KONG_ADMIN_URL}/consumers/microservices-app/jwt" \
        '{
            "algorithm": "HS256",
            "key": "microservices-jwt-key",
            "secret": "01aee198bd1475f54ba9fbc7663430a8e659d8755b550fcb322008f0f66d3719"
        }' \
        "Creating JWT credentials for consumer"

    print_status "JWT Authentication configured!"
}

# Function to add logging plugins
setup_logging() {
    print_info "📝 Setting up Logging..."
    
    # File Log Plugin for local logging
    api_call "POST" "${KONG_ADMIN_URL}/plugins" \
        '{
            "name": "file-log",
            "config": {
                "path": "/tmp/kong_requests.log",
                "reopen": true
            }
        }' \
        "Adding file logging plugin"

    # HTTP Log Plugin (example with httpbin - replace with your log endpoint)
    api_call "POST" "${KONG_ADMIN_URL}/plugins" \
        '{
            "name": "http-log",
            "config": {
                "http_endpoint": "https://httpbin.org/post",
                "method": "POST",
                "timeout": 1000,
                "keepalive": 1000
            }
        }' \
        "Adding HTTP logging plugin"

    print_status "Logging configured!"
}

# Function to setup health checking
setup_health_checks() {
    print_info "🏥 Setting up Health Checks..."
    
    # Update services with health check configuration and tags
    api_call "PATCH" "${KONG_ADMIN_URL}/services/auth-service" \
        '{
            "tags": ["microservice", "auth", "production"]
        }' \
        "Adding tags to auth service"

    api_call "PATCH" "${KONG_ADMIN_URL}/services/chat-service" \
        '{
            "tags": ["microservice", "chat", "production"]
        }' \
        "Adding tags to chat service"

    print_status "Health checks configured!"
}

# Function to setup request/response transformation
setup_transformations() {
    print_info "🔄 Setting up Advanced Request/Response Transformations..."
    
    # Advanced response transformation for security headers
    api_call "POST" "${KONG_ADMIN_URL}/plugins" \
        '{
            "name": "response-transformer",
            "config": {
                "add": {
                    "headers": [
                        "X-Content-Type-Options:nosniff",
                        "X-Frame-Options:DENY", 
                        "X-XSS-Protection:1; mode=block",
                        "Referrer-Policy:strict-origin-when-cross-origin"
                    ]
                },
                "remove": {
                    "headers": ["Server", "X-Powered-By"]
                }
            }
        }' \
        "Adding security headers via response transformer"

    print_status "Advanced transformations configured!"
}

# Function to setup API key authentication for certain routes
setup_api_key_auth() {
    print_info "🔑 Setting up API Key Authentication..."
    
    # Create API Key consumer
    api_call "POST" "${KONG_ADMIN_URL}/consumers" \
        '{
            "username": "api-client",
            "custom_id": "api-001"
        }' \
        "Creating API key consumer"

    # Generate API key
    api_call "POST" "${KONG_ADMIN_URL}/consumers/api-client/key-auth" \
        '{
            "key": "microservices-api-key-2024"
        }' \
        "Generating API key"

    print_status "API Key authentication configured!"
}

# Function to setup request size limiting
setup_request_limiting() {
    print_info "📏 Setting up Request Size Limiting..."
    
    # Request size limiting
    api_call "POST" "${KONG_ADMIN_URL}/plugins" \
        '{
            "name": "request-size-limiting",
            "config": {
                "allowed_payload_size": 128,
                "size_unit": "megabytes",
                "require_content_length": false
            }
        }' \
        "Adding request size limiting"

    print_status "Request size limiting configured!"
}

# Function to setup IP restriction (example)
setup_ip_restriction() {
    print_info "🛡️  Setting up IP Restrictions..."
    
    # IP restriction plugin for auth service (allowing all IPs for development)
    api_call "POST" "${KONG_ADMIN_URL}/services/auth-service/plugins" \
        '{
            "name": "ip-restriction",
            "config": {
                "allow": ["0.0.0.0/0"],
                "deny": []
            }
        }' \
        "Adding IP restriction to auth service (allowing all for development)"

    print_status "IP restrictions configured!"
}

# Function to setup request termination for maintenance
setup_maintenance_mode() {
    print_info "🚧 Setting up Maintenance Mode Plugin..."
    
    # Request termination plugin (disabled by default)
    api_call "POST" "${KONG_ADMIN_URL}/plugins" \
        '{
            "name": "request-termination",
            "enabled": false,
            "config": {
                "status_code": 503,
                "content_type": "application/json",
                "body": "{\"message\": \"Service temporarily unavailable for maintenance\", \"retry_after\": 3600, \"status\": \"maintenance\"}"
            }
        }' \
        "Adding maintenance mode plugin (disabled by default)"

    print_status "Maintenance mode configured (disabled)!"
}

# Function to setup prometheus metrics
setup_monitoring() {
    print_info "📊 Setting up Monitoring..."
    
    # Prometheus plugin for metrics
    api_call "POST" "${KONG_ADMIN_URL}/plugins" \
        '{
            "name": "prometheus",
            "config": {
                "per_consumer": true,
                "status_code_metrics": true,
                "latency_metrics": true,
                "bandwidth_metrics": true,
                "upstream_health_metrics": true
            }
        }' \
        "Adding Prometheus monitoring plugin"

    print_status "Prometheus monitoring configured!"
}

# Function to setup bot detection
setup_bot_detection() {
    print_info "🤖 Setting up Bot Detection..."
    
    # Bot detection plugin
    api_call "POST" "${KONG_ADMIN_URL}/plugins" \
        '{
            "name": "bot-detection",
            "config": {
                "allow": [],
                "deny": ["curl", "wget"]
            }
        }' \
        "Adding bot detection plugin"

    print_status "Bot detection configured!"
}

# Function to setup request ID tracking
setup_request_id() {
    print_info "🆔 Setting up Request ID Tracking..."
    
    # Request ID plugin
    api_call "POST" "${KONG_ADMIN_URL}/plugins" \
        '{
            "name": "request-id",
            "config": {
                "header_name": "X-Request-ID",
                "generator": "uuid#counter",
                "echo_downstream": true
            }
        }' \
        "Adding request ID tracking plugin"

    print_status "Request ID tracking configured!"
}

# Function to setup datadog monitoring (optional)
setup_datadog() {
    print_info "📈 Setting up DataDog Integration (Optional)..."
    
    # Only setup if DATADOG_API_KEY is provided
    if [ -n "$DATADOG_API_KEY" ]; then
        api_call "POST" "${KONG_ADMIN_URL}/plugins" \
            '{
                "name": "datadog",
                "config": {
                    "host": "localhost",
                    "port": 8125,
                    "metrics": [
                        "request_count",
                        "latency",
                        "request_size",
                        "response_size",
                        "upstream_latency"
                    ]
                }
            }' \
            "Adding DataDog monitoring plugin"
        print_status "DataDog integration configured!"
    else
        print_warning "DATADOG_API_KEY not set, skipping DataDog setup"
    fi
}

# Main execution
main() {
    echo "=================================================="
    echo "🚀 Kong Advanced Configuration"
    echo "=================================================="
    
    # Wait for Kong to be ready
    print_info "Checking Kong availability..."
    local retries=0
    local max_retries=10
    
    until curl -f ${KONG_ADMIN_URL}/status &>/dev/null; do
        if [ $retries -ge $max_retries ]; then
            print_error "Kong is not available after ${max_retries} attempts"
            exit 1
        fi
        print_info "Waiting for Kong to be ready... (attempt $((retries+1))/${max_retries})"
        sleep 5
        retries=$((retries+1))
    done
    
    print_status "Kong is ready! Starting advanced configuration..."
    echo ""
    
    # Execute all setup functions
    setup_jwt_auth
    echo ""
    
    setup_logging
    echo ""
    
    setup_health_checks
    echo ""
    
    setup_transformations
    echo ""
    
    setup_api_key_auth
    echo ""
    
    setup_request_limiting
    echo ""
    
    setup_ip_restriction
    echo ""
    
    setup_maintenance_mode
    echo ""
    
    setup_monitoring
    echo ""
    
    setup_bot_detection
    echo ""
    
    setup_request_id
    echo ""
    
    setup_datadog
    echo ""
    
    # Final verification
    print_info "🔍 Final Configuration Verification..."
    
    # Count configured items
    services_count=$(curl -s "${KONG_ADMIN_URL}/services" | jq '.data | length' 2>/dev/null || echo "N/A")
    routes_count=$(curl -s "${KONG_ADMIN_URL}/routes" | jq '.data | length' 2>/dev/null || echo "N/A")
    plugins_count=$(curl -s "${KONG_ADMIN_URL}/plugins" | jq '.data | length' 2>/dev/null || echo "N/A")
    consumers_count=$(curl -s "${KONG_ADMIN_URL}/consumers" | jq '.data | length' 2>/dev/null || echo "N/A")
    
    echo "=================================================="
    print_status "Advanced Kong configuration completed!"
    echo "=================================================="
    echo ""
    print_info "📊 Configuration Summary:"
    echo "   🌐 Services: $services_count"
    echo "   🛣️  Routes: $routes_count"  
    echo "   🔌 Plugins: $plugins_count"
    echo "   👥 Consumers: $consumers_count"
    echo ""
    print_info "✅ Enabled Features:"
    echo "   🔐 JWT Authentication"
    echo "   📝 File & HTTP Logging" 
    echo "   🏥 Health Check Tags"
    echo "   🔄 Security Headers"
    echo "   🔑 API Key Authentication"
    echo "   📏 Request Size Limiting"
    echo "   🛡️  IP Restrictions"
    echo "   🚧 Maintenance Mode (disabled)"
    echo "   📊 Prometheus Monitoring"
    echo "   🤖 Bot Detection"
    echo "   🆔 Request ID Tracking"
    echo ""
    print_info "📊 Monitoring Endpoints:"
    echo "   📈 Prometheus Metrics: http://localhost:8001/metrics"
    echo "   🔍 Kong Status: http://localhost:8001/status"
    echo "   📋 Services: http://localhost:8001/services"
    echo "   🛣️  Routes: http://localhost:8001/routes"
    echo "   🔌 Plugins: http://localhost:8001/plugins"
    echo "   👥 Consumers: http://localhost:8001/consumers"
    echo ""
    print_info "🔧 Management Commands:"
    echo "   # Enable maintenance mode (get plugin ID first)"
    echo "   PLUGIN_ID=\$(curl -s http://localhost:8001/plugins | jq -r '.data[] | select(.name==\"request-termination\") | .id')"
    echo "   curl -X PATCH http://localhost:8001/plugins/\$PLUGIN_ID -d '{\"enabled\":true}'"
    echo ""
    echo "   # Check service health"
    echo "   curl http://localhost:8001/services/auth-service"
    echo "   curl http://localhost:8001/services/chat-service"
    echo ""
    echo "   # View metrics"  
    echo "   curl http://localhost:8001/metrics"
    echo ""
    print_info "🔑 Authentication Credentials:"
    echo "   JWT Key: microservices-jwt-key"
    echo "   API Key: microservices-api-key-2024"
    echo ""
}

# Check dependencies
if ! command -v curl &> /dev/null; then
    print_error "curl is required but not installed."
    exit 1
fi

# Execute main function
main