# Build stage
FROM golang:1.21-alpine AS builder

WORKDIR /app

# Install build dependencies
RUN apk add --no-cache git

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY main.go ./

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o metadata-service .

# Runtime stage
FROM alpine:latest

RUN apk --no-cache add ca-certificates

# Create a non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy the binary from builder and set ownership
COPY --from=builder --chown=appuser:appgroup /app/metadata-service .

# Switch to non-root user
USER appuser

# Expose metadata API port
EXPOSE 8888

# Run the service
CMD ["./metadata-service"]
