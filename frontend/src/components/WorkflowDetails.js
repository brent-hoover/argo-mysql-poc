import React, { useState, useEffect } from 'react';

function WorkflowDetails({ workflow, onClose }) {
  const [details, setDetails] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchWorkflowDetails();
  }, [workflow.name]);

  const fetchWorkflowDetails = async () => {
    if (!workflow.name) {
      setError('No workflow name provided');
      setLoading(false);
      return;
    }

    try {
      setLoading(true);
      const response = await fetch(`/api/v1/workflows/${workflow.name}`);
      const data = await response.json();
      
      if (data.status === 'success') {
        setDetails(data.workflow);
        setError('');
      } else {
        setError(data.error || 'Failed to fetch workflow details');
      }
    } catch (err) {
      setError('Network error: ' + err.message);
    } finally {
      setLoading(false);
    }
  };

  const formatTimestamp = (timestamp) => {
    if (!timestamp) return 'N/A';
    return new Date(timestamp).toLocaleString();
  };

  const getNodeStatus = (nodeStatus) => {
    switch (nodeStatus?.toLowerCase()) {
      case 'succeeded':
        return '✅ Succeeded';
      case 'failed':
        return '❌ Failed';
      case 'running':
        return '🏃 Running';
      case 'pending':
        return '⏳ Pending';
      default:
        return '❓ Unknown';
    }
  };

  return (
    <div style={{
      position: 'fixed',
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      backgroundColor: 'rgba(0,0,0,0.5)',
      display: 'flex',
      justifyContent: 'center',
      alignItems: 'center',
      zIndex: 1000
    }}>
      <div style={{
        backgroundColor: 'white',
        borderRadius: '8px',
        padding: '20px',
        maxWidth: '800px',
        maxHeight: '80vh',
        width: '90%',
        overflow: 'auto'
      }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '20px' }}>
          <h3>Workflow Details</h3>
          <button
            className="btn btn-secondary"
            onClick={onClose}
            style={{ padding: '5px 10px' }}
          >
            ✕ Close
          </button>
        </div>

        {loading && <div className="loading">Loading workflow details...</div>}
        
        {error && <div className="error">{error}</div>}
        
        {details && (
          <div>
            <div style={{ marginBottom: '20px' }}>
              <h4>Basic Information</h4>
              <table style={{ width: '100%' }}>
                <tbody>
                  <tr>
                    <td style={{ fontWeight: 'bold', padding: '5px 10px 5px 0' }}>Name:</td>
                    <td style={{ padding: '5px 0' }}>{details.name}</td>
                  </tr>
                  <tr>
                    <td style={{ fontWeight: 'bold', padding: '5px 10px 5px 0' }}>UID:</td>
                    <td style={{ padding: '5px 0', fontFamily: 'monospace', fontSize: '12px' }}>{details.uid}</td>
                  </tr>
                  <tr>
                    <td style={{ fontWeight: 'bold', padding: '5px 10px 5px 0' }}>Status:</td>
                    <td style={{ padding: '5px 0' }}>
                      <span className={`status-badge status-${details.status?.toLowerCase()}`}>
                        {details.status}
                      </span>
                    </td>
                  </tr>
                  <tr>
                    <td style={{ fontWeight: 'bold', padding: '5px 10px 5px 0' }}>Started:</td>
                    <td style={{ padding: '5px 0' }}>{formatTimestamp(details.startedAt)}</td>
                  </tr>
                  <tr>
                    <td style={{ fontWeight: 'bold', padding: '5px 10px 5px 0' }}>Finished:</td>
                    <td style={{ padding: '5px 0' }}>{formatTimestamp(details.finishedAt)}</td>
                  </tr>
                  {details.message && (
                    <tr>
                      <td style={{ fontWeight: 'bold', padding: '5px 10px 5px 0' }}>Message:</td>
                      <td style={{ padding: '5px 0' }}>{details.message}</td>
                    </tr>
                  )}
                </tbody>
              </table>
            </div>

            {details.parameters && details.parameters.length > 0 && (
              <div style={{ marginBottom: '20px' }}>
                <h4>Parameters</h4>
                <div style={{ backgroundColor: '#f5f5f5', padding: '10px', borderRadius: '4px' }}>
                  {details.parameters.map((param, index) => (
                    <div key={index} style={{ marginBottom: '5px' }}>
                      <strong>{param.name}:</strong> {param.value}
                    </div>
                  ))}
                </div>
              </div>
            )}

            {details.nodes && Object.keys(details.nodes).length > 0 && (
              <div>
                <h4>Workflow Steps</h4>
                <div style={{ backgroundColor: '#f9f9f9', padding: '15px', borderRadius: '4px' }}>
                  {Object.entries(details.nodes).map(([nodeId, node]) => (
                    <div key={nodeId} style={{ 
                      marginBottom: '10px', 
                      padding: '10px', 
                      backgroundColor: 'white', 
                      borderRadius: '4px',
                      border: '1px solid #ddd'
                    }}>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                        <strong>{node.displayName || node.name || nodeId}</strong>
                        <span>{getNodeStatus(node.phase)}</span>
                      </div>
                      {node.startedAt && (
                        <div style={{ fontSize: '12px', color: '#666', marginTop: '5px' }}>
                          Started: {formatTimestamp(node.startedAt)}
                          {node.finishedAt && ` | Finished: ${formatTimestamp(node.finishedAt)}`}
                        </div>
                      )}
                      {node.message && (
                        <div style={{ fontSize: '12px', marginTop: '5px', fontStyle: 'italic' }}>
                          {node.message}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </div>
            )}

            <div style={{ marginTop: '20px', textAlign: 'center' }}>
              <button
                className="btn btn-secondary"
                onClick={fetchWorkflowDetails}
              >
                🔄 Refresh Details
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export default WorkflowDetails;