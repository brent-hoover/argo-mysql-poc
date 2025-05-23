# Argo MySQL Operations Frontend

A React frontend for managing and monitoring Argo Workflows that perform MySQL operations.

## Features

- **Workflow Initiation**: Submit delete-user operations through a clean form interface
- **Real-time Status Tracking**: Monitor workflow status with automatic refresh
- **Workflow History**: View complete history of submitted workflows  
- **Detailed Workflow View**: Inspect individual workflow steps and execution details
- **System Status**: Check connectivity to Kubernetes and Argo APIs
- **Event-driven Architecture**: Integrates with Argo Events for decoupled workflow execution

## Setup Instructions

### Prerequisites

- Node.js 16+ installed
- Backend API running on `http://localhost:5000`
- Access to the Argo MySQL Operations API

### Installation

1. **Navigate to the frontend directory:**
   ```bash
   cd frontend
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Start the development server:**
   ```bash
   npm start
   ```

4. **Access the application:**
   - Open your browser to `http://localhost:3000`
   - The app will automatically proxy API requests to `http://localhost:5000`

### Production Build

To create a production build:

```bash
npm run build
```

This creates a `build/` directory with optimized static files ready for deployment.

## Usage

### System Status
- The top card shows the connectivity status to Kubernetes and Argo APIs
- Green indicators mean the services are available
- Red indicators mean there are connectivity issues

### Delete User Operations
1. Enter a user ID in the form (e.g., 1, 2, 3, 4, 5)
2. Click "Delete User" to submit the workflow
3. The system will trigger an event-driven workflow that:
   - First backs up the user data
   - Then deletes the user from the database

### Monitoring Workflows
- The workflow history table shows all submitted workflows
- Status badges indicate the current state (Pending, Running, Succeeded, Failed)
- Click "Details" to view complete workflow information including:
  - Individual step execution status
  - Timestamps and duration
  - Parameters and messages
  - Real-time status updates

### Auto-refresh
- The workflow list automatically refreshes every 10 seconds
- Manual refresh is available via the "Refresh" button
- Individual workflow details can be refreshed independently

## API Integration

The frontend integrates with these API endpoints:

- `GET /api/v1/kubernetes/status` - Check system connectivity
- `GET /api/v1/workflows` - List all workflows
- `GET /api/v1/workflows/{name}` - Get workflow details  
- `POST /api/v1/mysql/operations/delete-user` - Submit delete user workflow

## Architecture

```
React Frontend → Flask API → Argo Events → Jetstream EventBus → Sensor → Argo Workflow
```

The frontend provides a user-friendly interface for the event-driven workflow architecture, allowing users to:
- Submit operations without direct Kubernetes access
- Monitor workflow execution in real-time
- Track the complete lifecycle of database operations

## Development

### Available Scripts

- `npm start` - Start development server
- `npm run build` - Create production build
- `npm test` - Run tests
- `npm run eject` - Eject from Create React App (irreversible)

### Project Structure

```
src/
├── components/
│   ├── ApiStatus.js       # System connectivity status
│   ├── DeleteUserForm.js  # Workflow submission form
│   ├── WorkflowList.js    # Workflow history table
│   └── WorkflowDetails.js # Detailed workflow view
├── App.js                 # Main application component
├── index.js              # Application entry point
└── index.css             # Global styles
```

### Customization

- Modify `src/index.css` for styling changes
- Add new operation forms by following the `DeleteUserForm.js` pattern
- Extend workflow monitoring by adding new columns to `WorkflowList.js`
- The proxy configuration in `package.json` can be updated for different backend URLs