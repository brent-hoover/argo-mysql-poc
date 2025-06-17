#!/bin/bash
# cleanup.sh - Remove all components of the Argo MySQL POC

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Parse command line arguments
REMOVE_ARGO=false
REMOVE_NAMESPACES=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --remove-argo)
            REMOVE_ARGO=true
            shift
            ;;
        --remove-namespaces)
            REMOVE_NAMESPACES=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --remove-argo         Also remove Argo Workflows and Events installations"
            echo "  --remove-namespaces   Also remove the argo and argo-events namespaces"
            echo "  --force               Skip confirmation prompts"
            echo "  --help                Show this help message"
            echo ""
            echo "By default, this script only removes the POC application components,"
            echo "leaving Argo Workflows and Events installed for potential reuse."
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

echo -e "${RED}=== Argo MySQL Operations POC Cleanup Script ===${NC}"
echo ""

if [ "$FORCE" = false ]; then
    echo "This will remove the following components:"
    echo "- API deployment and service"
    echo "- MySQL database and data"
    echo "- Workflow templates and operations"
    echo "- Argo Events components (EventBus, EventSource, Sensor)"
    echo "- RBAC configurations"
    
    if [ "$REMOVE_ARGO" = true ]; then
        echo "- Argo Workflows installation"
        echo "- Argo Events installation"
    fi
    
    if [ "$REMOVE_NAMESPACES" = true ]; then
        echo "- argo namespace"
        echo "- argo-events namespace"
    fi
    
    echo ""
    read -p "Are you sure you want to continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
fi

# Step 1: Remove application components
log "Removing application components..."

# Remove API
kubectl delete -f api-deployment.yaml --ignore-not-found=true

# Remove Argo Events components
kubectl delete -f argo-events-rbac.yaml --ignore-not-found=true
kubectl delete -f argo-events-sensor.yaml --ignore-not-found=true
kubectl delete -f argo-events-eventsource.yaml --ignore-not-found=true
kubectl delete -f argo-events-eventbus-local.yaml --ignore-not-found=true

# Remove Kubernetes resources
kubectl delete -f rbac.yaml --ignore-not-found=true
kubectl delete -f operation-templates.yaml --ignore-not-found=true
kubectl delete -f argo-mysql-ops-workflows.yaml --ignore-not-found=true
kubectl delete -f mysql-deployment.yaml --ignore-not-found=true
kubectl delete -f mysql-secrets.yaml --ignore-not-found=true

# Wait a moment for resources to be deleted
sleep 5

# Step 2: Remove any remaining workflows
log "Cleaning up any remaining workflows..."
if kubectl get workflows -n argo >/dev/null 2>&1; then
    kubectl delete workflows --all -n argo --ignore-not-found=true
fi

# Step 3: Remove Argo installations if requested
if [ "$REMOVE_ARGO" = true ]; then
    log "Removing Argo Workflows..."
    if command -v helm >/dev/null 2>&1; then
        helm uninstall argo-workflows -n argo --ignore-not-found >/dev/null 2>&1 || true
    fi
    
    log "Removing Argo Events..."
    kubectl delete -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml --ignore-not-found=true || true
fi

# Step 4: Remove namespaces if requested
if [ "$REMOVE_NAMESPACES" = true ]; then
    log "Removing namespaces..."
    kubectl delete namespace argo --ignore-not-found=true &
    kubectl delete namespace argo-events --ignore-not-found=true &
    wait
fi

# Step 5: Clean up Docker images
log "Cleaning up Docker images..."
docker rmi argo-mysql-ops-combined:latest >/dev/null 2>&1 || true
docker rmi argo-mysql-ops:latest >/dev/null 2>&1 || true

# Show remaining resources
echo ""
log "Cleanup completed!"
echo ""

if [ "$REMOVE_NAMESPACES" = false ]; then
    echo -e "${BLUE}Remaining resources in argo namespace:${NC}"
    kubectl get all -n argo 2>/dev/null || echo "No resources found"
    echo ""
    
    echo -e "${BLUE}Remaining resources in argo-events namespace:${NC}"
    kubectl get all -n argo-events 2>/dev/null || echo "No resources found"
    echo ""
fi

if [ "$REMOVE_ARGO" = false ]; then
    info "Argo Workflows and Events are still installed."
    info "Use --remove-argo flag to remove them as well."
fi

if [ "$REMOVE_NAMESPACES" = false ]; then
    info "Namespaces 'argo' and 'argo-events' are still present."
    info "Use --remove-namespaces flag to remove them as well."
fi

echo ""
echo -e "${GREEN}Cleanup script completed successfully!${NC}"