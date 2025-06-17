# Frontend build stage
FROM node:18-alpine AS frontend-builder

WORKDIR /frontend

# Copy package files first for better caching
COPY frontend/package*.json ./

# Install dependencies
RUN npm ci

# Copy frontend source
COPY frontend/ ./

# Build the React app
RUN npm run build

# Backend build stage
FROM golang:1.21-alpine AS backend-builder

# Set working directory
WORKDIR /app

# Install git (needed for go mod download)
RUN apk add --no-cache git

# Copy go mod file and source code
COPY go.mod main.go ./

# Download dependencies (this will create go.sum)
RUN go mod tidy && go mod download

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

# Final stage
FROM alpine:latest

# Install ca-certificates for HTTPS requests and mysql client
RUN apk --no-cache add ca-certificates mysql-client

WORKDIR /app

# Copy the binary from backend builder stage
COPY --from=backend-builder /app/main .

# Copy built frontend from frontend builder stage
COPY --from=frontend-builder /frontend/build ./frontend-build
# Copy files to proper locations for Gin static serving
RUN mkdir -p ./static && \
    cp ./frontend-build/index.html ./static/ && \
    cp -r ./frontend-build/static/* ./static/ && \
    rm -rf ./frontend-build

# Copy scripts directory if it exists
COPY scripts/ ./scripts/

# Make sure scripts are executable
RUN chmod +x ./scripts/*.sh

# Expose port
EXPOSE 5000

# Run the binary
CMD ["./main"]