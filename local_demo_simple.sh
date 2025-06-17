#!/bin/bash
# local_demo_simple.sh - Simple, safe demo script that won't crash Docker Desktop

# NO set -e to avoid unexpected exits
# NO aggressive process killing

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Simple cleanup function - only kills processes we track
cleanup() {
    info "Cleaning up port forwards..."
    if [[ -f /tmp/simple_demo.pids ]]; then
        while read -r pid; do
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                info "Stopping port forward process $pid"
                kill "$pid" 2>/dev/null || true
            fi
        done < /tmp/simple_demo.pids
        rm -f /tmp/simple_demo.pids
    fi
    echo "Demo stopped."
    exit 0
}

# Set up signal handling for clean shutdown
trap cleanup INT TERM

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              🎬 Simple Argo MySQL Demo                         ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check cluster connectivity
info "Checking cluster connectivity..."
if ! kubectl cluster-info >/dev/null 2>&1; then
    error "Cannot connect to Kubernetes cluster"
    echo "Please ensure Docker Desktop Kubernetes is running"
    exit 1
fi
success "Connected to cluster: $(kubectl config current-context)"

# Check if services exist
info "Checking services..."
if ! kubectl get svc argo-mysql-ops-api -n argo >/dev/null 2>&1; then
    error "Service argo-mysql-ops-api not found in argo namespace"
    echo "Please run ./deploy.sh first"
    exit 1
fi
success "Services are available"

# Initialize PID tracking
rm -f /tmp/simple_demo.pids
touch /tmp/simple_demo.pids

# Start API port forward
info "Starting API port forward (8080 -> 80)..."
kubectl port-forward svc/argo-mysql-ops-api -n argo 8080:80 >/dev/null 2>&1 &
api_pid=$!
echo "$api_pid" >> /tmp/simple_demo.pids

# Give it a moment to start
sleep 3

# Check if it started successfully
if kill -0 "$api_pid" 2>/dev/null; then
    success "API available at http://localhost:8080"
else
    error "Failed to start API port forward"
    exit 1
fi

# Test the API
info "Testing API..."
sleep 2
if curl -s http://localhost:8080/health >/dev/null 2>&1; then
    success "API health check: OK"
else
    warning "API health check failed (may still be starting)"
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    🚀 DEMO READY 🚀                            ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${BLUE}📱 Frontend & API:${NC}"
echo "   🌐 http://localhost:8080"
echo ""

echo -e "${BLUE}🎯 Quick Test Commands:${NC}"
echo ""
echo -e "${YELLOW}# Test API status:${NC}"
echo "curl http://localhost:8080/api/v1/kubernetes/status | jq"
echo ""
echo -e "${YELLOW}# Test health:${NC}"
echo "curl http://localhost:8080/health"
echo ""

echo -e "${BLUE}🛑 To stop: Press Ctrl+C${NC}"
echo ""

# Keep running until interrupted
info "Demo is running. Press Ctrl+C to stop..."
while true; do
    sleep 30
    # Simple health check - if port forward dies, restart it
    if ! kill -0 "$api_pid" 2>/dev/null; then
        warning "API port forward died, restarting..."
        kubectl port-forward svc/argo-mysql-ops-api -n argo 8080:80 >/dev/null 2>&1 &
        api_pid=$!
        # Update PID file
        echo "$api_pid" > /tmp/simple_demo.pids
    fi
done