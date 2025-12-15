FROM node:18-alpine

# Install docker CLI for executing database commands
RUN apk add --no-cache docker-cli

WORKDIR /app

# Copy package files
COPY package.json ./

# Install dependencies
RUN npm install --production

# Copy backend and frontend files
COPY backend/ ./backend/
COPY frontend/ ./frontend/

# Expose ports
EXPOSE 3001 3443

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3001/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the application
CMD ["node", "backend/server.js"]
