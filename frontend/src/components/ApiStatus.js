import React, { useState, useEffect } from 'react';

function ApiStatus() {
  const [status, setStatus] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchApiStatus();
  }, []);

  const fetchApiStatus = async () => {
    try {
      const apiBaseUrl = process.env.REACT_APP_API_BASE_URL || '';
      const response = await fetch(`${apiBaseUrl}/api/v1/kubernetes/status`);
      const data = await response.json();
      setStatus(data);
    } catch (error) {
      console.error('Error fetching API status:', error);
      setStatus({ error: 'Failed to connect to API' });
    } finally {
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <div className="card" style={{ marginBottom: '20px' }}>
        <div className="loading">Checking API status...</div>
      </div>
    );
  }

  const getStatusIndicator = (available) => {
    return available ? '🟢' : '🔴';
  };

  const getStatusText = (available) => {
    return available ? 'Available' : 'Unavailable';
  };

  return (
    <div className="card" style={{ marginBottom: '20px' }}>
      <h3>System Status</h3>
      
      {status?.error ? (
        <div className="error">
          {status.error}
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '15px' }}>
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '24px' }}>
              {getStatusIndicator(status?.kubernetes_available)}
            </div>
            <div style={{ fontWeight: 'bold' }}>Kubernetes API</div>
            <div style={{ fontSize: '12px', color: '#666' }}>
              {getStatusText(status?.kubernetes_available)}
            </div>
          </div>
          
          <div style={{ textAlign: 'center' }}>
            <div style={{ fontSize: '24px' }}>
              {getStatusIndicator(status?.argo_api_available)}
            </div>
            <div style={{ fontWeight: 'bold' }}>Argo Workflows</div>
            <div style={{ fontSize: '12px', color: '#666' }}>
              {getStatusText(status?.argo_api_available)}
            </div>
          </div>
        </div>
      )}
      
      <div style={{ marginTop: '15px', textAlign: 'center' }}>
        <button 
          className="btn btn-secondary" 
          onClick={fetchApiStatus}
          style={{ fontSize: '12px', padding: '5px 10px' }}
        >
          🔄 Refresh Status
        </button>
      </div>
    </div>
  );
}

export default ApiStatus;