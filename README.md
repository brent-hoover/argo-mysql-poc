# Argo MySQL Operations POC

A proof of concept using Argo Workflows and Argo Events to perform secure MySQL operations with an event-driven REST API written in Go.

## Overview

This project demonstrates an event-driven architecture using Argo Workflows and Argo Events to run controlled, parameterized database operations against MySQL databases. The system provides:

- Event-driven workflow triggering via webhooks
- Pre-defined, template-based SQL operations
- Secure credential management
- Go-based REST API for submitting operations
- React frontend for workflow management
- Real-time workflow status tracking and history

## Architecture

**Event Flow**: `Frontend → Go API → Argo Events → EventBus → Sensor → Argo Workflow → MySQL Operations`

## Components

- **Go API Service**: High-performance REST API with Kubernetes integration
- **React Frontend**: Web interface for workflow management and monitoring
- **Argo Events**: Event-driven workflow triggering system
- **Argo Workflows**: Orchestration of database operations  
- **MySQL Database**: Target database for operations
- **Jetstream EventBus**: Message delivery system
- **Operation Templates**: ConfigMap with pre-defined, parameterized SQL queries

## Prerequisites

- Kubernetes cluster
- kubectl configured to access your cluster  
- Docker for building container images
- Helm (for Argo installation)
- Node.js and npm (for frontend development)
- Go 1.21+ (for API development)

## Setup Instructions

### 0. Clone the Repository

```bash
# Clone this repository
git clone <repository-url>
cd argo-poc
```

### 1. Install Argo Workflows

```bash
# Create namespace for Argo
kubectl create namespace argo

# Add Argo Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Install Argo Workflows
helm install argo-workflows argo/argo-workflows \
  --namespace argo \
  --set server.serviceType=LoadBalancer \
  --set executor.resources.requests.cpu=100m \
  --set executor.resources.requests.memory=64Mi \
  --set controller.resources.requests.cpu=100m \
  --set controller.resources.requests.memory=64Mi

# Verify installation
kubectl get pods -n argo
kubectl get svc -n argo
```

For more detailed installation options, see the [official Argo Workflows documentation](https://argoproj.github.io/argo-workflows/installation/).

### 2. Deploy Kubernetes Resources

```bash

# Deploy the MySQL database with sample data
kubectl apply -f mysql-deployment.yaml

# Deploy the database credentials secret
kubectl apply -f mysql-secrets.yaml

# Deploy the workflow templates
kubectl apply -f argo-mysql-ops-workflows.yaml

# Deploy the operation templates
kubectl apply -f operation-templates.yaml

# Deploy the RBAC configuration for service account permissions
kubectl apply -f rbac.yaml

# Verify MySQL is running
kubectl get pods -n argo -l app=mysql
```

### 3. Deploy Argo Events

```bash
# Deploy Argo Events components
kubectl apply -f argo-events-eventbus-local.yaml
kubectl apply -f argo-events-eventsource.yaml
kubectl apply -f argo-events-sensor.yaml
kubectl apply -f argo-events-rbac.yaml

# Verify Argo Events is running
kubectl get pods -n argo -l app.kubernetes.io/part-of=argo-events
```

### 4. Build and Deploy the Go API

```bash
# Build the Go API image
docker build -t argo-mysql-ops:latest .

# For Docker Desktop Kubernetes - image is automatically available
# For minikube: minikube image load argo-mysql-ops:latest
# For kind: kind load docker-image argo-mysql-ops:latest --name <cluster-name>
# For cloud: tag and push to your registry

# Deploy the API service
kubectl apply -f api-deployment.yaml

# Verify deployment
kubectl get pods -n argo -l app=argo-mysql-ops-api
```

### 5. Access the Application

```bash
# Set up port forwarding to access the API
kubectl port-forward svc/argo-mysql-ops-api -n argo 8080:80

# The API is now accessible at http://localhost:8080
```

### 6. Run the React Frontend (Optional)

```bash
# Navigate to frontend directory
cd frontend

# Install dependencies
npm install

# Start the development server
npm start

# Frontend available at http://localhost:3000
# Configure API_BASE_URL in frontend/.env if needed
```

## API Usage

The API provides several endpoints for interacting with database operations.

### Check API Status

```bash
curl http://localhost:8080/api/v1/kubernetes/status
```

### List Workflows

```bash
curl http://localhost:8080/api/v1/workflows
```

### Get Workflow Details

```bash
curl http://localhost:8080/api/v1/workflows/{workflow-name}
```

### Delete a User (Event-Driven)

```bash
curl -X POST http://localhost:8080/api/v1/mysql/operations/delete-user \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 3
  }'
```

### Available Operations

Currently implemented specific operations:

- `/api/v1/mysql/operations/delete-user`: Delete a user by ID via event-driven workflow (includes backing up user data first)

The system uses an event-driven architecture where API calls trigger events that are processed by Argo Events, which then trigger the corresponding Argo Workflows.

Additional operations can be implemented by:
1. Adding new API endpoints in `main.go`
2. Creating corresponding Argo Events sensors  
3. Defining new workflow templates

## Sample Database

The deployed MySQL database includes the following sample data:

- **Users**: 5 sample users with different statuses
- **Organizations**: 3 sample organizations
- **Organization Members**: Mapping users to organizations with roles
- **Application Data**: Sample application configuration data
- **Audit Logs**: Sample user activity logs

This data can be used to test the various operations provided by the API.

## Security Considerations

- SQL queries are pre-defined and parameterized to prevent SQL injection
- Database credentials are stored as Kubernetes secrets
- Operations are restricted to pre-defined templates
- Input validation is performed on all API requests

## Development

### Adding New Operations

To add a new operation:

1. Create a new dedicated endpoint in `main.go` following the pattern of `/api/v1/mysql/operations/delete-user`
2. Create corresponding Argo Events sensor configuration
3. Design the specific workflow steps for that operation  
4. Implement proper validation for the operation's parameters
5. If needed, add any SQL templates to the `argo-mysql-ops-templates` ConfigMap
6. Apply the changes to your cluster:
   ```bash
   kubectl apply -f operation-templates.yaml
   kubectl apply -f argo-events-sensor.yaml
   ```

### Local Development

#### Go API Development

```bash
# Install Go dependencies
go mod tidy

# Run the API locally (limited functionality without Kubernetes)
go run main.go

# Build and test with Docker
docker build -t argo-mysql-ops:latest .
docker run -p 5000:5000 argo-mysql-ops:latest
```

#### Frontend Development

```bash
# Navigate to frontend directory  
cd frontend

# Install dependencies
npm install

# Start development server
npm start

# Configure API endpoint in frontend/.env
echo "REACT_APP_API_BASE_URL=http://localhost:8080" > .env
```

Note: For full functionality, deploy to Kubernetes where the Go API can access Kubernetes and Argo APIs.

## MySQL Database Access

You can connect to the MySQL database directly for debugging or manual operations:

```bash
# Port forward the MySQL service
kubectl port-forward svc/mysql -n argo 3306:3306

# In another terminal, connect using the MySQL client
mysql -h 127.0.0.1 -P 3306 -u root -p
# Enter password: password123

# Once connected, select the demo database
mysql> USE demo;

# Now you can run queries directly
mysql> SELECT * FROM users;
```

## Monitoring Workflows

You can monitor the status of your workflows in several ways:

### 1. Using the API

```bash
# List all workflows
curl http://localhost:8080/api/v1/workflows

# Get details of a specific workflow (replace WORKFLOW_NAME with actual name)
curl http://localhost:8080/api/v1/workflows/WORKFLOW_NAME
```

### 2. Using kubectl

```bash
# List all workflows
kubectl get workflows -n argo
# or use the shorter alias
kubectl get wf -n argo

# Get detailed status of a specific workflow
kubectl describe workflow WORKFLOW_NAME -n argo

# Watch workflow status updates in real-time
kubectl get workflows -n argo --watch

# Get the workflow definition with all status information
kubectl get workflow WORKFLOW_NAME -n argo -o yaml

# Get the logs from a workflow's pods
kubectl logs -n argo -l workflows.argoproj.io/workflow=WORKFLOW_NAME --tail=100
```

### 3. Accessing the Argo Workflows UI

The Argo Workflows UI provides a visual interface for monitoring and managing workflows:

```bash
# Port forward the Argo UI service
kubectl port-forward svc/argo-workflows-server -n argo 2746:2746

# Access the UI in your browser at:
# http://localhost:2746
```

In the UI, you can:
- View all workflows and their current status
- Inspect detailed execution information
- See logs for each step
- Resubmit workflows or retry failed steps
- View the workflow DAG (Directed Acyclic Graph) visualization

## Troubleshooting

### Common Issues

1. **Images not found**:
   - Ensure the Docker images are properly built and accessible to your Kubernetes cluster
   - For minikube/kind, make sure you've loaded the images correctly
   - For remote clusters, ensure the images are pushed to a registry accessible by the cluster

2. **PersistentVolumeClaims not provisioned**:
   - Check if your cluster has a default StorageClass: `kubectl get sc`
   - If not, create a StorageClass or modify the PVC files to use an existing one

3. **MySQL connectivity issues**:
   - Check if MySQL pod is running: `kubectl get pods -n argo -l app=mysql`
   - Check MySQL logs: `kubectl logs -n argo -l app=mysql`
   - Verify the secrets are correctly created: `kubectl describe secret mysql-credentials -n argo`

4. **API errors**:
   - Check API pod logs: `kubectl logs -n argo -l app=argo-mysql-ops-api`
   - Verify the API service is running: `kubectl get svc -n argo argo-mysql-ops-api`

5. **Argo Workflows errors**:
   - Check workflow status: `kubectl get workflows -n argo`
   - Check workflow logs: `kubectl logs -n argo -l app=argo-workflows-server`