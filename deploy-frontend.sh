#!/bin/bash

set -euo pipefail

#############################################
# Configuration
#############################################

FRONTEND_DIR="/home/appuser/apps/ecom-lite/frontend"
NGINX_ROOT="/usr/share/nginx/html"

#############################################
# Checks
#############################################

command -v npm >/dev/null 2>&1 || {
    echo "npm is not installed."
    exit 1
}

command -v nginx >/dev/null 2>&1 || {
    echo "Nginx is not installed."
    exit 1
}

#############################################
# Build Frontend
#############################################

echo "========================================="
echo "Deploying Frontend"
echo "========================================="

cd "$FRONTEND_DIR"

echo "Installing npm packages..."
npm install

echo "Building frontend..."
npm run build

#############################################
# Deploy Build
#############################################

echo "Cleaning nginx web root..."
sudo rm -rf "${NGINX_ROOT:?}"/*

echo "Copying build files..."
sudo cp -r dist/* "$NGINX_ROOT/"

#############################################
# Reload Nginx
#############################################

echo "Reloading nginx..."
sudo systemctl reload nginx

#############################################
# Health Check
#############################################

echo "Waiting for frontend..."
sleep 2

curl -f http://localhost >/dev/null

echo ""
echo "Frontend deployed successfully!"