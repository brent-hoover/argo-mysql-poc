package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
	"k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/client-go/dynamic"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
	"k8s.io/client-go/tools/clientcmd"
)

// Response structures
type StatusResponse struct {
	KubernetesAvailable bool `json:"kubernetes_available"`
	ArgoAPIAvailable    bool `json:"argo_api_available"`
}

type ErrorResponse struct {
	Error string `json:"error"`
}

type SuccessResponse struct {
	Status  string      `json:"status"`
	Message string      `json:"message,omitempty"`
	Data    interface{} `json:"data,omitempty"`
}

type WorkflowSummary struct {
	Name       string `json:"name"`
	UID        string `json:"uid"`
	Status     string `json:"status"`
	StartedAt  string `json:"startedAt"`
	FinishedAt string `json:"finishedAt"`
	Operation  string `json:"operation"`
}

type WorkflowDetails struct {
	Name       string                 `json:"name"`
	UID        string                 `json:"uid"`
	Status     string                 `json:"status"`
	StartedAt  string                 `json:"startedAt"`
	FinishedAt string                 `json:"finishedAt"`
	Message    string                 `json:"message"`
	Nodes      map[string]interface{} `json:"nodes"`
	Parameters []interface{}          `json:"parameters"`
}

type WorkflowsResponse struct {
	Status    string            `json:"status"`
	Workflows []WorkflowSummary `json:"workflows"`
}

type WorkflowResponse struct {
	Status   string          `json:"status"`
	Workflow WorkflowDetails `json:"workflow"`
}

type DeleteUserRequest struct {
	UserID int `json:"user_id" binding:"required"`
}

type DeleteUserResponse struct {
	Status       string `json:"status"`
	Message      string `json:"message"`
	EventID      string `json:"event_id,omitempty"`
	UserID       int    `json:"user_id,omitempty"`
	WorkflowName string `json:"workflow_name,omitempty"`
	WorkflowUID  string `json:"workflow_uid,omitempty"`
}

type EventPayload struct {
	UserID    int    `json:"user_id"`
	EventID   string `json:"event_id"`
	Timestamp string `json:"timestamp"`
	Operation string `json:"operation"`
}

// Global clients
var (
	kubernetesClient   kubernetes.Interface
	dynamicClient      dynamic.Interface
	kubernetesEnabled  bool
	argoAPIEnabled     bool
)

// Kubernetes configuration
func initKubernetesClients() {
	var config *rest.Config
	var err error

	// Try in-cluster config first
	config, err = rest.InClusterConfig()
	if err != nil {
		log.Printf("Not running in cluster, trying kubeconfig: %v", err)
		// Try local kubeconfig
		config, err = clientcmd.BuildConfigFromFlags("", clientcmd.RecommendedHomeFile)
		if err != nil {
			log.Printf("Could not load Kubernetes config: %v", err)
			log.Println("Kubernetes functionality will be disabled")
			return
		}
		log.Println("Loaded kubeconfig")
	} else {
		log.Println("Loaded in-cluster config")
	}

	// Create clients
	kubernetesClient, err = kubernetes.NewForConfig(config)
	if err != nil {
		log.Printf("Failed to create Kubernetes client: %v", err)
		return
	}

	dynamicClient, err = dynamic.NewForConfig(config)
	if err != nil {
		log.Printf("Failed to create dynamic client: %v", err)
		return
	}

	kubernetesEnabled = true
	argoAPIEnabled = true
	log.Println("Kubernetes and Argo API clients initialized successfully")
}

// HTTP Handlers
func healthHandler(c *gin.Context) {
	c.String(http.StatusOK, "OK")
}

func rootHandler(c *gin.Context) {
	c.String(http.StatusOK, "Argo MySQL Operations API is running!")
}

func statusHandler(c *gin.Context) {
	response := StatusResponse{
		KubernetesAvailable: kubernetesEnabled,
		ArgoAPIAvailable:    argoAPIEnabled,
	}
	c.JSON(http.StatusOK, response)
}

func listWorkflowsHandler(c *gin.Context) {
	if !argoAPIEnabled {
		c.JSON(http.StatusServiceUnavailable, ErrorResponse{
			Error: "Kubernetes/Argo integration not available",
		})
		return
	}

	// Define the Workflow resource
	workflowGVR := schema.GroupVersionResource{
		Group:    "argoproj.io",
		Version:  "v1alpha1",
		Resource: "workflows",
	}

	// List workflows with label selector
	workflows, err := dynamicClient.Resource(workflowGVR).Namespace("argo").List(
		context.TODO(),
		metav1.ListOptions{
			LabelSelector: "app=argo-mysql-ops",
		},
	)

	if err != nil {
		log.Printf("Error listing workflows: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{
			Error: err.Error(),
		})
		return
	}

	// Format response
	var workflowList []WorkflowSummary
	for _, item := range workflows.Items {
		metadata := item.Object["metadata"].(map[string]interface{})
		status := item.Object["status"]
		
		var statusMap map[string]interface{}
		if status != nil {
			statusMap = status.(map[string]interface{})
		} else {
			statusMap = make(map[string]interface{})
		}

		labels := make(map[string]interface{})
		if metadata["labels"] != nil {
			labels = metadata["labels"].(map[string]interface{})
		}

		workflow := WorkflowSummary{
			Name:      getStringValue(metadata, "name"),
			UID:       getStringValue(metadata, "uid"),
			Status:    getStringValue(statusMap, "phase"),
			StartedAt: getStringValue(statusMap, "startedAt"),
			FinishedAt: getStringValue(statusMap, "finishedAt"),
			Operation: getStringValue(labels, "operation"),
		}
		
		workflowList = append(workflowList, workflow)
	}

	response := WorkflowsResponse{
		Status:    "success",
		Workflows: workflowList,
	}

	c.JSON(http.StatusOK, response)
}

func getWorkflowHandler(c *gin.Context) {
	workflowName := c.Param("name")
	
	if !argoAPIEnabled {
		c.JSON(http.StatusServiceUnavailable, ErrorResponse{
			Error: "Kubernetes/Argo integration not available",
		})
		return
	}

	// Define the Workflow resource
	workflowGVR := schema.GroupVersionResource{
		Group:    "argoproj.io",
		Version:  "v1alpha1",
		Resource: "workflows",
	}

	// Get specific workflow
	workflow, err := dynamicClient.Resource(workflowGVR).Namespace("argo").Get(
		context.TODO(),
		workflowName,
		metav1.GetOptions{},
	)

	if err != nil {
		log.Printf("Error getting workflow %s: %v", workflowName, err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{
			Error: err.Error(),
		})
		return
	}

	// Extract workflow details
	metadata := workflow.Object["metadata"].(map[string]interface{})
	status := workflow.Object["status"]
	spec := workflow.Object["spec"]

	var statusMap map[string]interface{}
	if status != nil {
		statusMap = status.(map[string]interface{})
	} else {
		statusMap = make(map[string]interface{})
	}

	var specMap map[string]interface{}
	if spec != nil {
		specMap = spec.(map[string]interface{})
	} else {
		specMap = make(map[string]interface{})
	}

	var nodes map[string]interface{}
	if statusMap["nodes"] != nil {
		nodes = statusMap["nodes"].(map[string]interface{})
	} else {
		nodes = make(map[string]interface{})
	}

	var parameters []interface{}
	if args := specMap["arguments"]; args != nil {
		if argsMap := args.(map[string]interface{}); argsMap["parameters"] != nil {
			parameters = argsMap["parameters"].([]interface{})
		}
	}

	workflowDetails := WorkflowDetails{
		Name:       getStringValue(metadata, "name"),
		UID:        getStringValue(metadata, "uid"),
		Status:     getStringValue(statusMap, "phase"),
		StartedAt:  getStringValue(statusMap, "startedAt"),
		FinishedAt: getStringValue(statusMap, "finishedAt"),
		Message:    getStringValue(statusMap, "message"),
		Nodes:      nodes,
		Parameters: parameters,
	}

	response := WorkflowResponse{
		Status:   "success",
		Workflow: workflowDetails,
	}

	c.JSON(http.StatusOK, response)
}

func deleteUserHandler(c *gin.Context) {
	var req DeleteUserRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, ErrorResponse{
			Error: "Invalid request: " + err.Error(),
		})
		return
	}

	if !argoAPIEnabled {
		c.JSON(http.StatusOK, DeleteUserResponse{
			Status:  "warning",
			Message: "Kubernetes/Argo integration not available. Running in debug/local mode.",
			UserID:  req.UserID,
		})
		return
	}

	// Generate event ID
	eventID := uuid.New().String()[:8]

	// Create event payload
	eventPayload := EventPayload{
		UserID:    req.UserID,
		EventID:   eventID,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Operation: "delete-user",
	}

	// Send event to Argo Events webhook
	webhookURL := "http://mysql-ops-webhook-eventsource-svc.argo-events.svc.cluster.local:12000/delete-user"
	
	payloadBytes, err := json.Marshal(eventPayload)
	if err != nil {
		log.Printf("Error marshaling event payload: %v", err)
		c.JSON(http.StatusInternalServerError, ErrorResponse{
			Error: "Failed to create event payload",
		})
		return
	}

	resp, err := http.Post(webhookURL, "application/json", bytes.NewBuffer(payloadBytes))
	if err != nil {
		log.Printf("Error sending event to webhook: %v", err)
		// Fallback to direct workflow creation if event sending fails
		fallbackResponse := createWorkflowDirectly(req.UserID)
		c.JSON(http.StatusOK, fallbackResponse)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		log.Printf("Webhook returned status %d", resp.StatusCode)
		// Fallback to direct workflow creation
		fallbackResponse := createWorkflowDirectly(req.UserID)
		c.JSON(http.StatusOK, fallbackResponse)
		return
	}

	log.Printf("Event sent successfully: %s", eventID)
	
	response := DeleteUserResponse{
		Status:  "success",
		Message: "Delete user event submitted successfully",
		EventID: eventID,
		UserID:  req.UserID,
	}

	c.JSON(http.StatusOK, response)
}

func createWorkflowDirectly(userID int) DeleteUserResponse {
	workflowName := fmt.Sprintf("delete-user-%s", uuid.New().String()[:8])
	
	// Create workflow definition
	workflow := &unstructured.Unstructured{
		Object: map[string]interface{}{
			"apiVersion": "argoproj.io/v1alpha1",
			"kind":       "Workflow",
			"metadata": map[string]interface{}{
				"generateName": workflowName + "-",
				"namespace":    "argo",
				"labels": map[string]interface{}{
					"app":        "argo-mysql-ops",
					"operation":  "delete-user",
					"created-by": "api-fallback",
					"user-id":    strconv.Itoa(userID),
				},
			},
			"spec": map[string]interface{}{
				"entrypoint": "delete-user-workflow",
				"templates": []interface{}{
					map[string]interface{}{
						"name": "delete-user-workflow",
						"steps": []interface{}{
							[]interface{}{
								map[string]interface{}{
									"name": "backup-user-data",
									"templateRef": map[string]interface{}{
										"name":     "argo-mysql-ops-operations",
										"template": "run-query",
									},
									"arguments": map[string]interface{}{
										"parameters": []interface{}{
											map[string]interface{}{
												"name":  "connection-string",
												"value": "mysql:3306/demo:root@password123",
											},
											map[string]interface{}{
												"name":  "query",
												"value": fmt.Sprintf("SELECT * FROM users WHERE id = %d;", userID),
											},
										},
									},
								},
							},
							[]interface{}{
								map[string]interface{}{
									"name": "delete-user",
									"templateRef": map[string]interface{}{
										"name":     "argo-mysql-ops-operations",
										"template": "run-query",
									},
									"arguments": map[string]interface{}{
										"parameters": []interface{}{
											map[string]interface{}{
												"name":  "connection-string",
												"value": "mysql:3306/demo:root@password123",
											},
											map[string]interface{}{
												"name":  "query",
												"value": fmt.Sprintf("DELETE FROM users WHERE id = %d;", userID),
											},
										},
									},
								},
							},
						},
					},
				},
				"arguments": map[string]interface{}{
					"parameters": []interface{}{},
				},
				"volumes": []interface{}{
					map[string]interface{}{
						"name": "mysql-creds",
						"secret": map[string]interface{}{
							"secretName": "mysql-credentials",
						},
					},
				},
			},
		},
	}

	// Define the Workflow resource
	workflowGVR := schema.GroupVersionResource{
		Group:    "argoproj.io",
		Version:  "v1alpha1",
		Resource: "workflows",
	}

	// Create the workflow
	createdWorkflow, err := dynamicClient.Resource(workflowGVR).Namespace("argo").Create(
		context.TODO(),
		workflow,
		metav1.CreateOptions{},
	)

	if err != nil {
		log.Printf("Error creating workflow: %v", err)
		return DeleteUserResponse{
			Status:  "error",
			Message: "Failed to create workflow: " + err.Error(),
		}
	}

	metadata := createdWorkflow.Object["metadata"].(map[string]interface{})
	createdName := getStringValue(metadata, "name")
	createdUID := getStringValue(metadata, "uid")

	log.Printf("Created workflow directly: %s", createdName)

	return DeleteUserResponse{
		Status:       "success",
		Message:      "Delete user workflow submitted successfully (direct mode)",
		WorkflowName: createdName,
		WorkflowUID:  createdUID,
		UserID:       userID,
	}
}

// Helper function to safely get string values from maps
func getStringValue(m map[string]interface{}, key string) string {
	if val, ok := m[key]; ok && val != nil {
		if str, ok := val.(string); ok {
			return str
		}
	}
	return ""
}

func main() {
	// Initialize Kubernetes clients
	initKubernetesClients()

	// Set up Gin router
	r := gin.Default()

	// Add CORS middleware for frontend
	r.Use(func(c *gin.Context) {
		c.Header("Access-Control-Allow-Origin", "*")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		c.Header("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept, Authorization")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// Routes
	r.GET("/", rootHandler)
	r.GET("/health", healthHandler)
	r.GET("/api/v1/kubernetes/status", statusHandler)
	r.GET("/api/v1/workflows", listWorkflowsHandler)
	r.GET("/api/v1/workflows/:name", getWorkflowHandler)
	r.POST("/api/v1/mysql/operations/delete-user", deleteUserHandler)

	// Start server
	log.Println("Starting Argo MySQL Operations API server on :5000")
	if err := r.Run(":5000"); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}