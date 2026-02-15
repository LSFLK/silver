#!/bin/bash

# ============================================
#  Docker Complete Cleanup Script
# ============================================
#  This script will:
#  1. Stop all running containers
#  2. Remove all Docker volumes
#  3. Remove all Docker images
# ============================================

# Colors
CYAN="\033[0;36m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
RED="\033[0;31m"
NC="\033[0m" # No Color

# Get the script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Services directory contains docker-compose.yaml
SERVICES_DIR="$(cd "${SCRIPT_DIR}/../../services" && pwd)"

echo -e "${YELLOW}Docker Complete Cleanup${NC}"
echo "---------------------------------------------"
echo -e "${RED}WARNING: This will remove ALL Docker volumes and images!${NC}"
echo ""
read -p "Are you sure you want to continue? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ]; then
    echo -e "${CYAN}Cleanup cancelled.${NC}"
    exit 0
fi

# Step 1: Stop all containers using docker compose
echo -e "\n${YELLOW}Step 1/4: Stopping Docker containers${NC}"
echo "  - Stopping Silver mail services..."
(cd "${SERVICES_DIR}" && docker compose down)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ Silver services stopped successfully${NC}"
else
    echo -e "${RED}  ✗ Failed to stop Silver services${NC}"
fi

echo "  - Stopping SeaweedFS services..."
(cd "${SERVICES_DIR}" && docker compose -f docker-compose.seaweedfs.yaml down)
if [ $? -eq 0 ]; then
    echo -e "${GREEN}  ✓ SeaweedFS services stopped successfully${NC}"
else
    echo -e "${RED}  ✗ Failed to stop SeaweedFS services${NC}"
fi

# Stop Identity Provider services
IDP_DIR="$(cd "${SCRIPT_DIR}/../idp/docker" && pwd)"
echo "  - Stopping Identity Provider services..."
for idp in thunder keycloak; do
    echo "    - Stopping ${idp}..."
    if [ -f "${IDP_DIR}/docker-compose.${idp}.yaml" ]; then
        (cd "${IDP_DIR}" && docker compose -f "docker-compose.${idp}.yaml" down)
    fi
done
echo -e "${GREEN}  ✓ Identity Provider services stopped${NC}"


# Step 2: Remove all volumes
echo -e "\n${YELLOW}Step 2/4: Removing all Docker volumes${NC}"
VOLUMES=$(docker volume ls -q)
if [ -n "$VOLUMES" ]; then
    docker volume rm $VOLUMES
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ All volumes removed successfully${NC}"
    else
        echo -e "${RED}✗ Some volumes could not be removed (may be in use)${NC}"
    fi
else
    echo -e "${CYAN}No volumes to remove${NC}"
fi

# Step 3: Remove all images
echo -e "\n${YELLOW}Step 3/4: Removing all Docker images${NC}"
IMAGES=$(docker images -q)
if [ -n "$IMAGES" ]; then
    docker rmi -f $IMAGES
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ All images removed successfully${NC}"
    else
        echo -e "${RED}✗ Some images could not be removed${NC}"
    fi
else
    echo -e "${CYAN}No images to remove${NC}"
fi

# Step 4: Clean up any remaining IdP containers
echo -e "\n${YELLOW}Step 4/4: Cleaning up Identity Provider containers${NC}"
IDP_CONTAINERS=$(docker ps -a --filter "name=thunder" --filter "name=keycloak" -q)
if [ -n "$IDP_CONTAINERS" ]; then
    docker rm -f $IDP_CONTAINERS
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ All IdP containers removed${NC}"
    else
        echo -e "${RED}✗ Some IdP containers could not be removed${NC}"
    fi
else
    echo -e "${CYAN}No IdP containers to remove${NC}"
fi

echo -e "\n${GREEN}Cleanup complete!${NC}"