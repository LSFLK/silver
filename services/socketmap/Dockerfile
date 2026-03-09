# Socketmap Service Dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /build

# Copy go module files
COPY go.mod ./
RUN go mod download

# Copy source code
COPY main.go ./

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o socketmap .

# Final stage
FROM alpine:3.19

# Install ca-certificates, netcat for healthcheck, and docker-cli for reading logs
RUN apk --no-cache add ca-certificates netcat-openbsd docker-cli

# Create a non-root user and group
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Add appuser to docker group to allow docker socket access
RUN addgroup appuser docker || true

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/socketmap .

# Set ownership for the app directory and binary
RUN chown -R appuser:appgroup /app

# Switch to the non-root user
USER appuser

# Expose socketmap port
EXPOSE 9100

# Run the service
CMD ["./socketmap"]
