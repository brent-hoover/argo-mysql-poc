# Argo MySQL Operations POC

A proof of concept using Argo Events and Argo Workflows to perform secure MySQL operations with an event-driven REST API.

## Overview

This project demonstrates how to use Argo Events and Argo Workflows to run controlled, parameterized database operations against MySQL databases. The system provides:

- Event-driven architecture using Argo Events
- Pre-defined, template-based SQL operations
- Secure credential management
- RESTful API for submitting operations
- Workflow status tracking and history
- Decoupled API from direct Kubernetes API access

## Architecture

The system follows an event-driven architecture:

```
API → HTTP Event → Argo Events → Jetstream EventBus → Sensor → Argo Workflow
```

**Benefits:**
- Better decoupling between API and workflow execution
- Event-driven scalability and resilience
- Easier testing and observability
- Multiple event sources can trigger the same workflows

## Components

- **Flask API**: REST API that publishes events to Argo Events
- **Argo Events**: Event-driven workflow automation framework
  - **EventBus**: Jetstream-based message bus for event delivery
  - **EventSource**: Webhook endpoint to receive API events
  - **Sensor**: Listens for events and triggers workflows
- **Argo Workflows**: Orchestration of database operations
- **MySQL Database**: Provides the database to perform operations against
- **Operation Templates**: WorkflowTemplate with pre-defined, parameterized SQL queries

## Prerequisites

- Kubernetes cluster (minikube, kind, or cloud provider)
- kubectl configured to access your cluster
- Docker for building container images
- Helm (for Argo installation)

## Complete Setup Instructions (From Bare Kubernetes Cluster)

### 0. Clone the Repository

```bash
# Clone this repository
git clone <repository-url>
cd argo-poc
```

### 1. Create Namespaces

```bash
# Create namespaces for Argo components
kubectl create namespace argo
kubectl create namespace argo-events
```

### 2. Install Argo Workflows

```bash
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

# Verify Argo Workflows installation
kubectl get pods -n argo
kubectl get svc -n argo
```

### 3. Install Argo Events

```bash
# Install Argo Events
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install.yaml

# Install Argo Events with validating admission controller
kubectl apply -f https://raw.githubusercontent.com/argoproj/argo-events/stable/manifests/install-validating-webhook.yaml

# Verify Argo Events installation
kubectl get pods -n argo-events
```

For more detailed installation options, see the [official Argo Workflows documentation](https://argoproj.github.io/argo-workflows/installation/) and [Argo Events documentation](https://argoproj.github.io/argo-events/installation/).

### 4. Deploy Argo Events Components

```bash
# Deploy RBAC for Argo Events
kubectl apply -f argo-events-rbac.yaml

# Deploy the Jetstream EventBus (use local version for better performance on local clusters)
kubectl apply -f argo-events-eventbus-local.yaml

# Deploy the webhook EventSource
kubectl apply -f argo-events-eventsource.yaml

# Deploy the sensor to trigger workflows
kubectl apply -f argo-events-sensor.yaml

# Verify Argo Events components are running
kubectl get eventbus -n argo-events
kubectl get eventsource -n argo-events
kubectl get sensor -n argo-events
```

### 5. Deploy Application Resources

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

### 6. Build Docker Image Locally

```bash
# Build the combined image
docker build -t argo-mysql-ops-combined:latest -f Dockerfile .

# If using minikube, load the image into minikube
# minikube image load argo-mysql-ops-combined:latest

# If using kind, load the image into kind
# kind load docker-image argo-mysql-ops-combined:latest --name <your-cluster-name>

# For standard Kubernetes clusters with no local registry:
# 1. Tag your image for your registry: docker tag argo-mysql-ops-combined:latest <your-registry>/argo-mysql-ops-combined:latest
# 2. Push to your registry: docker push <your-registry>/argo-mysql-ops-combined:latest
# 3. Update api-deployment.yaml to use your registry image

# Note: The deployment is configured to use the local image with imagePullPolicy: IfNotPresent
```

### 7. Deploy the API Service

```bash
# Use the included API deployment file
kubectl apply -f api-deployment.yaml

# Verify the deployment is running
kubectl get pods -n argo -l app=argo-mysql-ops-api

# Set up port forwarding to access the API locally
kubectl port-forward svc/argo-mysql-ops-api -n argo 5000:80

# This makes the API accessible at http://localhost:5000
```

## Testing the Event-Driven Architecture

### 1. Verify All Components Are Running

```bash
# Check Argo Workflows
kubectl get pods -n argo

# Check Argo Events
kubectl get pods -n argo-events

# Check EventBus status
kubectl get eventbus -n argo-events

# Check EventSource status  
kubectl get eventsource -n argo-events

# Check Sensor status
kubectl get sensor -n argo-events

# Check MySQL and API
kubectl get pods -n argo -l app=mysql
kubectl get pods -n argo -l app=argo-mysql-ops-api
```

### 2. Set Up Port Forwarding

```bash
# Port forward the API (in one terminal)
kubectl port-forward svc/argo-mysql-ops-api -n argo 5000:80

# Port forward Argo Events webhook (in another terminal)
kubectl port-forward svc/mysql-ops-webhook-eventsource-svc -n argo-events 12000:12000

# Port forward Argo UI (in another terminal)
kubectl port-forward svc/argo-workflows-server -n argo 2746:2746
```

### 3. Test the Event-Driven Flow

#### Step 1: Check Initial Database State

```bash
# Connect to MySQL to see current users
kubectl port-forward svc/mysql -n argo 3306:3306

# In another terminal
mysql -h 127.0.0.1 -P 3306 -u root -p
# Password: password123

USE demo;
SELECT * FROM users;
```

#### Step 2: Trigger an Event via API

```bash
# Test the event-driven delete user operation
curl -X POST http://localhost:5000/api/v1/mysql/operations/delete-user \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 3
  }'
```

Expected response:
```json
{
  "status": "success",
  "message": "Delete user event submitted successfully", 
  "event_id": "abc12345",
  "user_id": 3
}
```

#### Step 3: Monitor the Event Flow

```bash
# Watch for new workflows being created
kubectl get workflows -n argo --watch

# Check sensor logs to see event processing
kubectl logs -n argo-events -l sensor-name=mysql-ops-sensor -f

# Check eventsource logs to see webhook events
kubectl logs -n argo-events -l eventsource-name=mysql-ops-webhook -f
```

#### Step 4: Verify Workflow Execution

```bash
# List workflows to find the triggered workflow
kubectl get workflows -n argo

# Get details of the workflow (replace WORKFLOW_NAME with actual name)
kubectl describe workflow WORKFLOW_NAME -n argo

# View workflow logs
kubectl logs -n argo -l workflows.argoproj.io/workflow=WORKFLOW_NAME --tail=100
```

#### Step 5: Verify Database Changes

```bash
# Check that the user was deleted
mysql -h 127.0.0.1 -P 3306 -u root -p
USE demo;
SELECT * FROM users WHERE id = 3;  # Should return no results
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

### Delete a User (Event-Driven)

```bash
curl -X POST http://localhost:5000/api/v1/mysql/operations/delete-user \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 3
  }'
```

### Available Operations

Currently implemented specific operations:

- `/api/v1/mysql/operations/delete-user`: Delete a user by ID via event-driven workflow (includes backing up user data first)

Additional operations can be implemented following this pattern with dedicated endpoints for each operation.

### Testing Event Delivery Directly

You can also test the event system directly by sending events to the webhook:

```bash
# Send event directly to Argo Events webhook
curl -X POST http://localhost:12000/delete-user \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 4,
    "event_id": "test-001",
    "timestamp": "2024-01-01T12:00:00Z",
    "operation": "delete-user"
  }'
```

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

1. Create a new dedicated endpoint in `app.py` following the pattern of `/api/v1/mysql/operations/delete-user`
2. Design the specific workflow steps for that operation
3. Implement proper validation for the operation's parameters
4. If needed, add any SQL templates to the `argo-mysql-ops-templates` ConfigMap
5. Apply the changes to your cluster:
   ```bash
   kubectl apply -f operation-templates.yaml
   ```

### Local Development

For local development:

```bash
# Install dependencies
pip install -r requirements.txt

# Run the API locally
python app.py

# Test an API call (note: in local development, this simulates the operation)
curl -X POST http://localhost:5000/api/v1/mysql/operations/delete-user \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1
  }'
```

Note: For local development that involves running SQL commands, ensure you have MySQL client tools installed on your machine.

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

6. **Argo Events errors**:
   - Check EventBus status: `kubectl describe eventbus default -n argo-events`
   - Check EventSource logs: `kubectl logs -n argo-events -l eventsource-name=mysql-ops-webhook`
   - Check Sensor logs: `kubectl logs -n argo-events -l sensor-name=mysql-ops-sensor`
   - Verify RBAC permissions: `kubectl describe clusterrolebinding operate-workflow-role-binding`

7. **Event delivery issues**:
   - Test webhook directly: `curl -X POST http://localhost:12000/delete-user -d '{"user_id":1}'`
   - Check Jetstream EventBus: `kubectl get pods -n argo-events -l controller=eventbus-controller`
   - Verify API can reach EventSource: Check API logs for HTTP errors