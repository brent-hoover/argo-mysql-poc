import React, { useState } from 'react';

function DeleteUserForm({ onWorkflowSubmitted }) {
  const [userId, setUserId] = useState('');
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState('');
  const [messageType, setMessageType] = useState(''); // 'success' or 'error'

  const handleSubmit = async (e) => {
    e.preventDefault();
    
    if (!userId || isNaN(userId)) {
      setMessage('Please enter a valid user ID');
      setMessageType('error');
      return;
    }

    setLoading(true);
    setMessage('');

    try {
      const response = await fetch('/api/v1/mysql/operations/delete-user', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          user_id: parseInt(userId)
        }),
      });

      const data = await response.json();

      if (response.ok && data.status === 'success') {
        setMessage(`Workflow submitted successfully! Event ID: ${data.event_id || 'N/A'}`);
        setMessageType('success');
        setUserId('');
        
        // Notify parent component
        if (onWorkflowSubmitted) {
          onWorkflowSubmitted(data);
        }
      } else {
        setMessage(data.error || 'Failed to submit workflow');
        setMessageType('error');
      }
    } catch (error) {
      setMessage('Network error: ' + error.message);
      setMessageType('error');
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={handleSubmit}>
      {message && (
        <div className={messageType === 'success' ? 'success' : 'error'}>
          {message}
        </div>
      )}
      
      <div className="form-group">
        <label htmlFor="userId">User ID:</label>
        <input
          type="number"
          id="userId"
          value={userId}
          onChange={(e) => setUserId(e.target.value)}
          placeholder="Enter user ID to delete (e.g., 1, 2, 3)"
          disabled={loading}
          min="1"
        />
      </div>
      
      <button 
        type="submit" 
        className="btn btn-primary"
        disabled={loading || !userId}
      >
        {loading ? 'Submitting...' : 'Delete User'}
      </button>
      
      <div style={{ marginTop: '10px', fontSize: '12px', color: '#666' }}>
        <strong>Note:</strong> This will trigger an event-driven workflow that first backs up the user data, then deletes the user from the database.
      </div>
    </form>
  );
}

export default DeleteUserForm;