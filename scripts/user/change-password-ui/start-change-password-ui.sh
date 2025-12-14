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
PARENT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

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

# Try to find package.json (parent directory or current)
PACKAGE_DIR="$PARENT_DIR"
if [ ! -f "$PARENT_DIR/package.json" ] && [ ! -f "$SCRIPT_DIR/package.json" ]; then
    echo -e "${YELLOW}⚠ package.json not found. Creating minimal package.json...${NC}"
    cat > "$PARENT_DIR/package.json" << 'PKGJSON'
{
  "name": "silver-mail-change-password",
  "version": "1.0.0",
  "description": "Change password UI for Silver Mail",
  "type": "module",
  "dependencies": {
    "express": "^4.18.2",
    "node-fetch": "^3.3.2"
  }
}
PKGJSON
    PACKAGE_DIR="$PARENT_DIR"
elif [ -f "$SCRIPT_DIR/package.json" ]; then
    PACKAGE_DIR="$SCRIPT_DIR"
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

# Check if the UI file exists
if [ ! -f "$SCRIPT_DIR/change-password-ui.html" ]; then
    echo -e "${RED}✗ Error: change-password-ui.html not found${NC}"
    exit 1
fi

echo -e "${GREEN}✓ UI file found${NC}"

# Start the server
echo ""
echo -e "${BLUE}Starting server on port $PORT...${NC}"
echo ""

cd "$SCRIPT_DIR"
PORT=$PORT node change-password-server.js
