from flask import Flask, request, jsonify
import logging
import os
import yaml
import uuid
import json
from datetime import datetime

# Configure logging
logging.basicConfig(level=logging.INFO, 
                    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Only try to load Kubernetes configuration if running in Kubernetes
kubernetes_available = False
argo_api_available = False
try:
    import kubernetes
    from kubernetes import client, config
    
    # Try to load Kubernetes configuration, but don't fail the app if it doesn't work
    try:
        config.load_incluster_config()
        logger.info("Loaded in-cluster config")
        kubernetes_available = True
    except Exception as e:
        logger.info(f"Not running in Kubernetes cluster: {e}")
        try:
            # For local development, try to load from kube config file
            config.load_kube_config()
            logger.info("Loaded kube config")
            kubernetes_available = True
        except Exception as e:
            logger.warning(f"Could not load Kubernetes config: {e}")
            logger.warning("Kubernetes functionality will be disabled")
    
    # Initialize Kubernetes API client
    if kubernetes_available:
        api_client = client.ApiClient()
        custom_api = client.CustomObjectsApi(api_client)
        argo_api_available = True
        logger.info("Argo API is available")
except ImportError:
    logger.warning("Kubernetes library not available")

@app.route('/')
def hello():
    return "Argo MySQL Operations API is running!"

@app.route('/health')
def health():
    return "OK"

@app.route('/api/v1/kubernetes/status', methods=['GET'])
def kubernetes_status():
    return jsonify({
        "kubernetes_available": kubernetes_available,
        "argo_api_available": argo_api_available
    })

@app.route('/api/v1/workflows', methods=['GET'])
def list_workflows():
    if not argo_api_available:
        return jsonify({
            "status": "warning",
            "message": "Kubernetes/Argo integration not available."
        }), 503
    
    try:
        workflows = custom_api.list_namespaced_custom_object(
            group="argoproj.io",
            version="v1alpha1",
            namespace="argo",
            plural="workflows",
            label_selector="app=argo-mysql-ops"
        )
        
        # Format the response to only include relevant information
        simplified_workflows = []
        for wf in workflows.get('items', []):
            simplified_workflows.append({
                "name": wf.get('metadata', {}).get('name'),
                "uid": wf.get('metadata', {}).get('uid'),
                "status": wf.get('status', {}).get('phase', 'Unknown'),
                "startedAt": wf.get('status', {}).get('startedAt'),
                "finishedAt": wf.get('status', {}).get('finishedAt'),
                "operation": wf.get('metadata', {}).get('labels', {}).get('operation')
            })
        
        return jsonify({
            "status": "success",
            "workflows": simplified_workflows
        })
    except Exception as e:
        logger.error(f"Error listing workflows: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/v1/workflows/<workflow_name>', methods=['GET'])
def get_workflow(workflow_name):
    if not argo_api_available:
        return jsonify({
            "status": "warning",
            "message": "Kubernetes/Argo integration not available."
        }), 503
    
    try:
        workflow = custom_api.get_namespaced_custom_object(
            group="argoproj.io",
            version="v1alpha1",
            namespace="argo",
            plural="workflows",
            name=workflow_name
        )
        
        # Extract and format the workflow details
        status = workflow.get('status', {})
        workflow_details = {
            "name": workflow.get('metadata', {}).get('name'),
            "uid": workflow.get('metadata', {}).get('uid'),
            "status": status.get('phase', 'Unknown'),
            "startedAt": status.get('startedAt'),
            "finishedAt": status.get('finishedAt'),
            "message": status.get('message', ''),
            "nodes": status.get('nodes', {}),
            "parameters": workflow.get('spec', {}).get('arguments', {}).get('parameters', [])
        }
        
        return jsonify({
            "status": "success",
            "workflow": workflow_details
        })
    except Exception as e:
        logger.error(f"Error getting workflow {workflow_name}: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/v1/mysql/operations/delete-user', methods=['POST'])
def delete_user():
    try:
        data = request.json
        if not data:
            return jsonify({"error": "No data provided"}), 400
            
        # Validate required fields
        required_fields = ['user_id']
        missing_fields = [field for field in required_fields if field not in data]
        if missing_fields:
            return jsonify({
                "error": f"Missing required fields: {', '.join(missing_fields)}"
            }), 400
            
        if not argo_api_available:
            return jsonify({
                "status": "warning",
                "message": "Kubernetes/Argo integration not available. Running in debug/local mode.",
                "data": data
            })
        
        # Create workflow name
        workflow_name = f"delete-user-{uuid.uuid4().hex[:8]}"
        
        # Create a workflow using the predefined template
        workflow = {
            "apiVersion": "argoproj.io/v1alpha1",
            "kind": "Workflow",
            "metadata": {
                "generateName": workflow_name + "-",
                "namespace": "argo",
                "labels": {
                    "app": "argo-mysql-ops",
                    "operation": "delete-user",
                    "created-by": "api",
                    "user-id": str(data['user_id'])
                }
            },
            "spec": {
                "entrypoint": "delete-user-workflow",
                "templates": [
                    {
                        "name": "delete-user-workflow",
                        "steps": [
                            [
                                {
                                    "name": "backup-user-data",
                                    "templateRef": {
                                        "name": "argo-mysql-ops-operations", 
                                        "template": "run-query"
                                    },
                                    "arguments": {
                                        "parameters": [
                                            {
                                                "name": "connection-string", 
                                                "value": "mysql:3306/demo:root@password123"
                                            },
                                            {
                                                "name": "query",
                                                "value": f"SELECT * FROM users WHERE id = {data['user_id']};"
                                            }
                                        ]
                                    }
                                }
                            ],
                            [
                                {
                                    "name": "delete-user",
                                    "templateRef": {
                                        "name": "argo-mysql-ops-operations",
                                        "template": "run-query"
                                    },
                                    "arguments": {
                                        "parameters": [
                                            {
                                                "name": "connection-string",
                                                "value": "mysql:3306/demo:root@password123"
                                            },
                                            {
                                                "name": "query",
                                                "value": f"DELETE FROM users WHERE id = {data['user_id']};"
                                            }
                                        ]
                                    }
                                }
                            ]
                        ]
                    }
                ],
                "arguments": {
                    "parameters": []
                },
                "volumes": [
                    {
                        "name": "mysql-creds",
                        "secret": {
                            "secretName": "mysql-credentials"
                        }
                    }
                ]
            }
        }
        
        # Submit the workflow to Argo
        try:
            created_workflow = custom_api.create_namespaced_custom_object(
                group="argoproj.io",
                version="v1alpha1",
                namespace="argo",
                plural="workflows",
                body=workflow
            )
            
            workflow_name = created_workflow['metadata']['name']
            workflow_uid = created_workflow['metadata']['uid']
            
            logger.info(f"Created workflow: {workflow_name}")
            
            return jsonify({
                "status": "success",
                "message": "Delete user workflow submitted successfully",
                "workflow_name": workflow_name,
                "workflow_uid": workflow_uid
            })
        except Exception as e:
            logger.error(f"Error creating workflow: {str(e)}")
            return jsonify({"error": f"Failed to create workflow: {str(e)}"}), 500
            
    except Exception as e:
        logger.error(f"Error: {str(e)}")
        return jsonify({"error": str(e)}), 500

# Generic operations route has been removed for security reasons.
# Use specific operation routes instead, which provide better security and workflow control.

if __name__ == '__main__':
    logger.info("Starting Flask application")
    app.run(debug=True, host='0.0.0.0', port=5000)