import React, { useState, useEffect } from 'react';
import DeleteUserForm from './components/DeleteUserForm';
import WorkflowList from './components/WorkflowList';
import ApiStatus from './components/ApiStatus';

function App() {
  const [workflows, setWorkflows] = useState([]);
  const [loading, setLoading] = useState(false);
  const [lastUpdate, setLastUpdate] = useState(new Date());

  const fetchWorkflows = async () => {
    setLoading(true);
    try {
      const response = await fetch('/api/v1/workflows');
      const data = await response.json();
      if (data.status === 'success') {
        setWorkflows(data.workflows);
      }
      setLastUpdate(new Date());
    } catch (error) {
      console.error('Error fetching workflows:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleWorkflowSubmitted = (workflowData) => {
    // Add the new workflow to the list immediately
    const newWorkflow = {
      name: workflowData.workflow_name,
      uid: workflowData.workflow_uid,
      status: 'Pending',
      startedAt: new Date().toISOString(),
      finishedAt: null,
      operation: 'delete-user'
    };
    setWorkflows(prev => [newWorkflow, ...prev]);
    
    // Refresh the list after a short delay to get updated status
    setTimeout(fetchWorkflows, 2000);
  };

  useEffect(() => {
    fetchWorkflows();
    
    // Set up periodic refresh every 10 seconds
    const interval = setInterval(fetchWorkflows, 10000);
    
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="App">
      <div className="header">
        <div className="container">
          <h1>Argo MySQL Operations</h1>
        </div>
      </div>
      
      <div className="container">
        <ApiStatus />
        
        <div className="card">
          <h2>Delete User Operation</h2>
          <DeleteUserForm onWorkflowSubmitted={handleWorkflowSubmitted} />
        </div>

        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
            <h2>Workflow History</h2>
            <div>
              <button 
                className="btn btn-secondary" 
                onClick={fetchWorkflows}
                disabled={loading}
              >
                {loading ? 'Refreshing...' : 'Refresh'}
              </button>
              <span style={{ marginLeft: '10px', fontSize: '12px', color: '#666' }}>
                Last updated: {lastUpdate.toLocaleTimeString()}
              </span>
            </div>
          </div>
          <WorkflowList workflows={workflows} loading={loading} />
        </div>
      </div>
    </div>
  );
}

export default App;