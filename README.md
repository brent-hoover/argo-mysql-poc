# Argo MySQL Operations POC

A proof of concept using Argo Workflows to perform secure MySQL operations with a REST API.

## Overview

This project demonstrates how to use Argo Workflows to run controlled, parameterized database operations against MySQL databases. The system provides:

- Pre-defined, template-based SQL operations
- Secure credential management
- RESTful API for submitting operations
- Workflow status tracking and history

## Components

- **Flask API**: REST API for submitting database operations
- **Argo Workflows**: Orchestration of database operations
- **MySQL Operations Container**: Alpine-based container with MySQL client tools
- **Operation Templates**: ConfigMap with pre-defined, parameterized SQL queries

## Prerequisites

- Kubernetes cluster
- kubectl configured to access your cluster
- Docker for building container images
- Helm (for Argo installation)

## Setup Instructions

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
# Create the persistent volume claim for backups
kubectl apply -f mysql-backups-pvc.yaml

# Deploy the database credentials secret (modify with actual credentials first)
kubectl apply -f mysql-secrets.yaml

# Deploy the workflow templates
kubectl apply -f argo-mysql-ops-workflows.yaml

# Deploy the operation templates
kubectl apply -f operation-templates.yaml

# Deploy the RBAC configuration for service account permissions
kubectl apply -f rbac.yaml
```

### 3. Build Docker Images Locally

```bash
# Build the MySQL operations image
docker build -t argo-mysql-ops:latest -f Dockerfile .

# Build the API image
docker build -t argo-mysql-ops-api:latest -f Dockerfile.app .

# Note: The deployment is configured to use these local images
# with imagePullPolicy: IfNotPresent to avoid any need for a remote registry
```

### 4. Deploy the API

```bash
# Use the included API deployment file
kubectl apply -f api-deployment.yaml

# Verify the deployment is running
kubectl get pods -n argo -l app=argo-mysql-ops-api

# Set up port forwarding to access the API locally
kubectl port-forward svc/argo-mysql-ops-api -n argo 5000:80

# This makes the API accessible at http://localhost:5000
```

## API Usage

The API provides several endpoints for interacting with database operations.

### Check API Status

```bash
curl http://localhost:5000/api/v1/kubernetes/status
```

### List Workflows

```bash
curl http://localhost:5000/api/v1/workflows
```

### Get Workflow Details

```bash
curl http://localhost:5000/api/v1/workflows/{workflow-name}
```

### Run a Pre-defined Operation

```bash
curl -X POST http://localhost:5000/api/v1/mysql/operations \
  -H "Content-Type: application/json" \
  -d '{
    "operation": "delete-user",
    "parameters": {
      "user_id": 123
    }
  }'
```

### Available Operations

The system comes with pre-defined operations:

- `delete-user`: Delete a user by ID
- `get-user`: Get user data by ID
- `update-user-status`: Update a user's status
- `get-org-users`: Get all users in an organization
- `backup-application-data`: Backup application data
- `get-user-activity`: Get user activity logs

## Security Considerations

- SQL queries are pre-defined and parameterized to prevent SQL injection
- Database credentials are stored as Kubernetes secrets
- Operations are restricted to pre-defined templates
- Input validation is performed on all API requests

## Development

### Adding New Operations

1. Add a new SQL template to the `argo-mysql-ops-templates` ConfigMap in `operation-templates.yaml`
2. Update the `allowed_operations` list in `app.py`
3. Apply the changes to your cluster:
   ```bash
   kubectl apply -f operation-templates.yaml
   ```

### Local Development

For local development:

```bash
# Run the API locally
python app.py

# Test an API call
curl -X POST http://localhost:5000/api/v1/mysql/operations \
  -H "Content-Type: application/json" \
  -d '{
    "operation": "get-user",
    "parameters": {
      "user_id": 1
    }
  }'
```

## Monitoring Workflows

You can monitor the status of your workflows in several ways:

### 1. Using the API

```bash
# List all workflows
curl http://localhost:5000/api/v1/workflows

# Get details of a specific workflow (replace WORKFLOW_NAME with actual name)
curl http://localhost:5000/api/v1/workflows/WORKFLOW_NAME
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