#!/bin/bash
# deploy.sh - Build and deploy the Argo MySQL POC to a Kubernetes cluster

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

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for pod to be ready
wait_for_pod() {
    local namespace=$1
    local label=$2
    local timeout=${3:-300}
    
    log "Waiting for pod with label $label in namespace $namespace to be ready..."
    kubectl wait --for=condition=ready pod -l "$label" -n "$namespace" --timeout="${timeout}s" || {
        error "Pod with label $label in namespace $namespace failed to become ready within ${timeout} seconds"
    }
}

# Function to check if namespace exists
namespace_exists() {
    kubectl get namespace "$1" >/dev/null 2>&1
}

# Parse command line arguments
SKIP_PREREQ_CHECK=false
SKIP_ARGO_INSTALL=false
BUILD_ONLY=false
DEPLOY_ONLY=false
IMAGE_TAG="latest"

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-prereq-check)
            SKIP_PREREQ_CHECK=true
            shift
            ;;
        --skip-argo-install)
            SKIP_ARGO_INSTALL=true
            shift
            ;;
        --build-only)
            BUILD_ONLY=true
            shift
            ;;
        --deploy-only)
            DEPLOY_ONLY=true
            shift
            ;;
        --image-tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --skip-prereq-check    Skip prerequisite checking"
            echo "  --skip-argo-install    Skip Argo Workflows and Events installation"
            echo "  --build-only          Only build Docker images, don't deploy"
            echo "  --deploy-only         Only deploy, don't build images"
            echo "  --image-tag TAG       Docker image tag (default: latest)"
            echo "  --help                Show this help message"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

echo -e "${GREEN}=== Argo MySQL Operations POC Deployment Script ===${NC}"
echo ""

# Step 1: Check prerequisites
if [ "$SKIP_PREREQ_CHECK" = false ]; then
    log "Checking prerequisites..."
    
    # Check for required commands
    for cmd in kubectl docker helm; do
        if ! command_exists "$cmd"; then
            error "$cmd is not installed. Please install $cmd and try again."
        fi
    done
    
    # Check kubectl connection
    if ! kubectl cluster-info >/dev/null 2>&1; then
        error "kubectl is not connected to a cluster. Please configure kubectl and try again."
    fi
    
    info "Connected to cluster: $(kubectl config current-context)"
    
    # Detect Kubernetes environment
    if kubectl get nodes -o wide | grep -q "docker-desktop"; then
        K8S_ENV="docker-desktop"
        info "Detected Docker Desktop Kubernetes"
    elif minikube status >/dev/null 2>&1; then
        K8S_ENV="minikube"
        info "Detected Minikube"
    elif kind get clusters >/dev/null 2>&1 && [ -n "$(kind get clusters)" ]; then
        K8S_ENV="kind"
        info "Detected Kind"
    else
        K8S_ENV="other"
        warning "Could not detect Kubernetes environment. Assuming remote cluster."
    fi
else
    log "Skipping prerequisite check..."
    K8S_ENV="${K8S_ENV:-other}"
fi

# Step 2: Build Docker image
if [ "$DEPLOY_ONLY" = false ]; then
    log "Building Docker image..."
    
    # Build the combined image with both API and scripts
    docker build -t "argo-mysql-ops-combined:${IMAGE_TAG}" -f Dockerfile . || error "Failed to build Docker image"
    
    # Also tag as latest for compatibility
    if [ "$IMAGE_TAG" != "latest" ]; then
        docker tag "argo-mysql-ops-combined:${IMAGE_TAG}" "argo-mysql-ops-combined:latest"
    fi
    
    # Load image into cluster based on environment
    case $K8S_ENV in
        minikube)
            log "Loading image into Minikube..."
            minikube image load "argo-mysql-ops-combined:${IMAGE_TAG}"
            ;;
        kind)
            log "Loading image into Kind..."
            # Get the first kind cluster name
            CLUSTER_NAME=$(kind get clusters | head -1)
            kind load docker-image "argo-mysql-ops-combined:${IMAGE_TAG}" --name "$CLUSTER_NAME"
            ;;
        docker-desktop)
            info "Image is automatically available in Docker Desktop"
            ;;
        *)
            warning "For remote clusters, you need to push the image to a registry"
            warning "Run: docker tag argo-mysql-ops-combined:${IMAGE_TAG} <your-registry>/argo-mysql-ops-combined:${IMAGE_TAG}"
            warning "Run: docker push <your-registry>/argo-mysql-ops-combined:${IMAGE_TAG}"
            warning "Then update the image references in the YAML files"
            ;;
    esac
fi

if [ "$BUILD_ONLY" = true ]; then
    log "Build complete. Exiting (--build-only flag set)"
    exit 0
fi

# Step 3: Install Argo Workflows
if [ "$SKIP_ARGO_INSTALL" = false ]; then
    log "Installing Argo Workflows..."
    
    # Create namespace if it doesn't exist
    if ! namespace_exists argo; then
        kubectl create namespace argo
    fi
    
    # Add Helm repository
    helm repo add argo https://argoproj.github.io/argo-helm >/dev/null 2>&1
    helm repo update >/dev/null 2>&1
    
    # Check if Argo Workflows is already installed
    if helm list -n argo | grep -q argo-workflows; then
        info "Argo Workflows is already installed, upgrading..."
        helm upgrade argo-workflows argo/argo-workflows \
            --namespace argo \
            --set server.serviceType=LoadBalancer \
            --set executor.resources.requests.cpu=100m \
            --set executor.resources.requests.memory=64Mi \
            --set controller.resources.requests.cpu=100m \
            --set controller.resources.requests.memory=64Mi
    else
        helm install argo-workflows argo/argo-workflows \
            --namespace argo \
            --set server.serviceType=LoadBalancer \
            --set executor.resources.requests.cpu=100m \
            --set executor.resources.requests.memory=64Mi \
            --set controller.resources.requests.cpu=100m \
            --set controller.resources.requests.memory=64Mi
    fi
    
    # Wait for Argo Workflows to be ready
    wait_for_pod argo "app.kubernetes.io/name=argo-workflows-server" 180
    wait_for_pod argo "app.kubernetes.io/name=argo-workflows-workflow-controller" 180
fi

# Step 4: Deploy Kubernetes resources
log "Deploying Kubernetes resources..."

# Deploy in order
kubectl apply -f mysql-secrets.yaml
kubectl apply -f mysql-deployment.yaml
kubectl apply -f argo-mysql-ops-workflows.yaml
kubectl apply -f operation-templates.yaml
kubectl apply -f rbac.yaml

# Wait for MySQL to be ready
wait_for_pod argo "app=mysql" 120

# Fix MySQL authentication for MariaDB client compatibility
log "Configuring MySQL authentication for MariaDB client compatibility..."
sleep 5  # Give MySQL a moment to fully initialize
for i in {1..3}; do
    if kubectl exec -n argo deployment/mysql -- mysql -u root -ppassword123 -e "ALTER USER 'root'@'%' IDENTIFIED WITH mysql_native_password BY 'password123'; FLUSH PRIVILEGES;" 2>/dev/null; then
        log "MySQL authentication configured successfully"
        break
    else
        warning "Attempt $i/3: MySQL not ready for authentication config, retrying in 5 seconds..."
        sleep 5
    fi
done

# Step 5: Install Argo Events
if [ "$SKIP_ARGO_INSTALL" = false ]; then
    log "Installing Argo Events..."
    
    # Create namespace if it doesn't exist
    if ! namespace_exists argo-events; then
        kubectl create namespace argo-events
    fi
    
    # Install Argo Events
    kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml
    
    # Wait for controller to be ready
    wait_for_pod argo-events "app=controller-manager" 120
fi

# Step 6: Deploy Argo Events components
log "Deploying Argo Events components..."

kubectl apply -f argo-events-eventbus-local.yaml
kubectl apply -f argo-events-eventsource.yaml
kubectl apply -f argo-events-sensor.yaml
kubectl apply -f argo-events-rbac.yaml

# Wait for EventBus to be ready
sleep 5
wait_for_pod argo-events "eventbus-name=default" 60

# Wait for EventSource to be ready
wait_for_pod argo-events "eventsource-name=mysql-ops-webhook" 60

# Wait for Sensor to be ready
wait_for_pod argo-events "sensor-name=mysql-ops-sensor" 60

# Step 7: Deploy the API
log "Deploying the API service..."

kubectl apply -f api-deployment.yaml

# Wait for API to be ready
wait_for_pod argo "app=argo-mysql-ops-api" 120

# Step 8: Setup port forwards and display access information
echo ""
echo -e "${GREEN}=== Deployment Complete! ===${NC}"
echo ""
echo -e "${BLUE}Access Information:${NC}"
echo ""

# API access
echo "1. API Access:"
echo "   kubectl port-forward svc/argo-mysql-ops-api -n argo 8080:80"
echo "   API will be available at: http://localhost:8080"
echo ""

# Argo UI access
echo "2. Argo Workflows UI:"
echo "   kubectl port-forward svc/argo-workflows-server -n argo 2746:2746"
echo "   UI will be available at: http://localhost:2746"
echo ""

# MySQL access
echo "3. MySQL Database:"
echo "   kubectl port-forward svc/mysql -n argo 3306:3306"
echo "   Connect with: mysql -h 127.0.0.1 -P 3306 -u root -p"
echo "   Password: password123"
echo ""

# Frontend
echo "4. Frontend (if you want to run it):"
echo "   cd frontend"
echo "   npm install"
echo "   npm start"
echo ""

# Quick test
echo -e "${BLUE}Quick Test Commands:${NC}"
echo ""
echo "# Check API status:"
echo "curl http://localhost:8080/api/v1/kubernetes/status"
echo ""
echo "# List workflows:"
echo "curl http://localhost:8080/api/v1/workflows"
echo ""
echo "# Delete user 3:"
echo 'curl -X POST http://localhost:8080/api/v1/mysql/operations/delete-user \'
echo '  -H "Content-Type: application/json" \'
echo '  -d '"'"'{"user_id": 3}'"'"''
echo ""

# Check deployment status
echo -e "${BLUE}Deployment Status:${NC}"
echo ""
kubectl get pods -n argo
echo ""
kubectl get pods -n argo-events
echo ""

log "Deployment script completed successfully!"