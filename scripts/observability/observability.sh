#!/bin/bash

# ============================================
#  Silver Observability Setup Script
# ============================================

# Base directories
SILVER_ROOT="$(git rev-parse --show-toplevel)"
TARGET_DIR="$SILVER_ROOT/silver-observability"

# Repo URLs
OBSERVABILITY_REPO="https://github.com/maneeshaxyz/silver-observability.git"

# Clone observability repo
git clone "$OBSERVABILITY_REPO" "$TARGET_DIR"

printf "Observability folder added at ${TARGET_DIR}\n"
