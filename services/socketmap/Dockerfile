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
FROM alpine:latest

RUN apk --no-cache add ca-certificates

WORKDIR /app

# Copy binary from builder
COPY --from=builder /build/socketmap .

# Expose socketmap port
EXPOSE 9100

# Run the service
CMD ["./socketmap"]
