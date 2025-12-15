#!/bin/bash

###############################################################################
# Silver Mail - Change Password UI Quick Start
###############################################################################
# This script helps you quickly start the password change UI
#
# Usage:
#   ./start-change-password-ui.sh [port]
#
# Example:
#   ./start-change-password-ui.sh        # Start on default port 3001
#   ./start-change-password-ui.sh 8080   # Start on port 8080
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKEND_DIR="$SCRIPT_DIR/backend"
FRONTEND_DIR="$SCRIPT_DIR/frontend"

# Default port
PORT=${1:-3001}

echo -e "${BLUE}┌─────────────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│  Silver Mail - Change Password UI              │${NC}"
echo -e "${BLUE}└─────────────────────────────────────────────────┘${NC}"
echo ""

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo -e "${RED}✗ Error: Node.js is not installed${NC}"
    echo -e "${YELLOW}  Please install Node.js from https://nodejs.org/${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Node.js found: $(node --version)${NC}"

# Check if npm is installed
if ! command -v npm &> /dev/null; then
    echo -e "${RED}✗ Error: npm is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ npm found: $(npm --version)${NC}"

# Check for package.json in the script directory
PACKAGE_DIR="$SCRIPT_DIR"
if [ ! -f "$SCRIPT_DIR/package.json" ]; then
    echo -e "${YELLOW}⚠ package.json not found. Creating minimal package.json...${NC}"
    cat > "$SCRIPT_DIR/package.json" << 'PKGJSON'
{
  "name": "silver-mail-password-change-ui",
  "version": "1.0.0",
  "description": "Silver Mail Password Change UI - Frontend and Backend",
  "main": "backend/server.js",
  "scripts": {
    "start": "node backend/server.js",
    "dev": "node backend/server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "node-fetch": "^3.3.0"
  },
  "engines": {
    "node": ">=14.0.0"
  }
}
PKGJSON
fi

# Check if node_modules exists
if [ ! -d "$PACKAGE_DIR/node_modules" ]; then
    echo -e "${YELLOW}⚠ Dependencies not installed. Installing now...${NC}"
    cd "$PACKAGE_DIR"
    npm install
    echo -e "${GREEN}✓ Dependencies installed${NC}"
else
    echo -e "${GREEN}✓ Dependencies already installed${NC}"
fi

# Check directory structure
echo ""
echo -e "${BLUE}Checking project structure...${NC}"

if [ ! -d "$BACKEND_DIR" ]; then
    echo -e "${RED}✗ Error: backend/ directory not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ backend/ directory found${NC}"

if [ ! -d "$FRONTEND_DIR" ]; then
    echo -e "${RED}✗ Error: frontend/ directory not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ frontend/ directory found${NC}"

# Check if backend server exists
if [ ! -f "$BACKEND_DIR/server.js" ]; then
    echo -e "${RED}✗ Error: backend/server.js not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ backend/server.js found${NC}"

# Check if frontend files exist
if [ ! -f "$FRONTEND_DIR/index.html" ]; then
    echo -e "${RED}✗ Error: frontend/index.html not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ frontend/index.html found${NC}"

if [ ! -f "$FRONTEND_DIR/styles.css" ]; then
    echo -e "${RED}✗ Error: frontend/styles.css not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ frontend/styles.css found${NC}"

if [ ! -f "$FRONTEND_DIR/script.js" ]; then
    echo -e "${RED}✗ Error: frontend/script.js not found${NC}"
    exit 1
fi
echo -e "${GREEN}✓ frontend/script.js found${NC}"

# Start the server
echo ""
echo -e "${BLUE}Starting server on port $PORT...${NC}"
echo ""

cd "$SCRIPT_DIR"
PORT=$PORT node backend/server.js
