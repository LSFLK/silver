FROM node:18-alpine

# Install docker CLI and curl for executing database commands and health checks
RUN apk add --no-cache docker-cli curl

WORKDIR /app

# Copy package files
COPY package.json ./

# Install dependencies
RUN npm install --production

# Copy backend and frontend files
COPY backend/ ./backend/
COPY frontend/ ./frontend/

# Expose HTTPS port only
EXPOSE 3443

# Health check - use HTTPS endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f -k https://localhost:3443/health || exit 1

# Start the application
CMD ["node", "backend/server.js"]
