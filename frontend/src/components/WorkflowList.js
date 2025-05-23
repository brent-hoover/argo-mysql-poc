import React, { useState } from 'react';
import WorkflowDetails from './WorkflowDetails';

function WorkflowList({ workflows, loading }) {
  const [selectedWorkflow, setSelectedWorkflow] = useState(null);

  const getStatusBadgeClass = (status) => {
    switch (status?.toLowerCase()) {
      case 'succeeded':
        return 'status-badge status-succeeded';
      case 'failed':
      case 'error':
        return 'status-badge status-failed';
      case 'running':
        return 'status-badge status-running';
      default:
        return 'status-badge status-pending';
    }
  };

  const formatTimestamp = (timestamp) => {
    if (!timestamp) return 'N/A';
    return new Date(timestamp).toLocaleString();
  };

  const getDuration = (startedAt, finishedAt) => {
    if (!startedAt) return 'N/A';
    const start = new Date(startedAt);
    const end = finishedAt ? new Date(finishedAt) : new Date();
    const duration = Math.round((end - start) / 1000);
    return `${duration}s`;
  };

  if (loading && workflows.length === 0) {
    return <div className="loading">Loading workflows...</div>;
  }

  if (workflows.length === 0) {
    return (
      <div style={{ textAlign: 'center', color: '#666', padding: '40px' }}>
        <p>No workflows found. Create your first workflow using the form above.</p>
      </div>
    );
  }

  return (
    <>
      <table className="workflow-table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Operation</th>
            <th>Status</th>
            <th>Started</th>
            <th>Duration</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {workflows.map((workflow) => (
            <tr key={workflow.uid || workflow.name}>
              <td title={workflow.name}>
                {workflow.name?.length > 30 
                  ? workflow.name.substring(0, 30) + '...' 
                  : workflow.name}
              </td>
              <td>
                <span style={{ textTransform: 'capitalize' }}>
                  {workflow.operation || 'Unknown'}
                </span>
              </td>
              <td>
                <span className={getStatusBadgeClass(workflow.status)}>
                  {workflow.status || 'Unknown'}
                </span>
              </td>
              <td>{formatTimestamp(workflow.startedAt)}</td>
              <td>{getDuration(workflow.startedAt, workflow.finishedAt)}</td>
              <td>
                <button
                  className="btn btn-secondary"
                  style={{ fontSize: '12px', padding: '5px 10px' }}
                  onClick={() => setSelectedWorkflow(workflow)}
                >
                  Details
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      {selectedWorkflow && (
        <WorkflowDetails
          workflow={selectedWorkflow}
          onClose={() => setSelectedWorkflow(null)}
        />
      )}
    </>
  );
}

export default WorkflowList;