# Socketmap Service Dockerfile
FROM golang:1.21-alpine AS builder

WORKDIR /build

# Copy go module files
COPY go.mod ./
RUN go mod download

# Copy source code (including all packages)
COPY main.go ./
COPY config/ ./config/
COPY internal/ ./internal/

# Build the binary
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o socketmap .

# Final stage
FROM alpine:3.19

# Install ca-certificates, netcat for healthcheck, and docker-cli for reading logs
RUN apk --no-cache add ca-certificates netcat-openbsd docker-cli

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/socketmap .

# Expose socketmap port
EXPOSE 9100

# Note: This service runs as root (configured in docker-compose.yaml with user: "0:0")
# to access the Docker socket for thunder-setup log extraction.
# In production, consider using init containers or secrets management instead.

# Run the service
CMD ["./socketmap"]
