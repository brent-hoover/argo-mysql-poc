# Build stage
FROM golang:1.21-alpine AS builder

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

# Copy the binary from builder stage
COPY --from=builder /app/main .

# Copy scripts directory if it exists
COPY scripts/ ./scripts/

# Make sure scripts are executable
RUN chmod +x ./scripts/*.sh

# Expose port
EXPOSE 5000

# Run the binary
CMD ["./main"]