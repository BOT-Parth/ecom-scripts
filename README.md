# ecom-scripts

-- has the commands to setup the backend and frontend --
## use the below command as userdata if needed -- will improve it and make it better and correct as time gones one






#!/bin/bash

set -euxo pipefail

#############################################
# Logging
#############################################

exec > >(tee /var/log/user-data.log | logger -t user-data) 2>&1

echo "========================================="
echo "Starting User Data"
echo "========================================="

#############################################
# Variables
#############################################

APP_HOME="/home/appuser/apps/ecom-lite"

BACKEND_REPO="https://github.com/<YOUR_USERNAME>/<BACKEND_REPO>.git"
FRONTEND_REPO="https://github.com/<YOUR_USERNAME>/<FRONTEND_REPO>.git"
SCRIPTS_REPO="https://github.com/<YOUR_USERNAME>/<SCRIPTS_REPO>.git"

#############################################
# System Update
#############################################

dnf update -y

#############################################
# Install Packages
#############################################

dnf install -y \
    git \
    nginx \
    jq

#############################################
# Install Node.js 22
#############################################

dnf module disable nodejs -y || true

curl -fsSL https://rpm.nodesource.com/setup_22.x | bash -

dnf install -y nodejs

#############################################
# Install PM2
#############################################

npm install -g pm2

#############################################
# Create Application Folder
#############################################

mkdir -p "$APP_HOME"

chown -R appuser:appuser /home/appuser/apps

#############################################
# Clone Repositories
#############################################

cd "$APP_HOME"

if [ ! -d backend ]; then
    sudo -u appuser git clone "$BACKEND_REPO" backend
fi

if [ ! -d frontend ]; then
    sudo -u appuser git clone "$FRONTEND_REPO" frontend
fi

if [ ! -d scripts ]; then
    sudo -u appuser git clone "$SCRIPTS_REPO" scripts
fi

#############################################
# Permissions
#############################################

chmod +x "$APP_HOME/scripts/"*.sh

#############################################
# Backend
#############################################

sudo -u appuser bash "$APP_HOME/scripts/deploy-backend.sh"

#############################################
# Frontend
#############################################

sudo -u appuser bash "$APP_HOME/scripts/deploy-frontend.sh"

#############################################
# Enable Services
#############################################

systemctl enable nginx

systemctl restart nginx

#############################################
# PM2 Startup
#############################################

sudo -u appuser pm2 startup systemd -u appuser --hp /home/appuser

env PATH=$PATH:/usr/bin pm2 save

#############################################
# Finished
#############################################

echo "========================================="
echo "User Data Completed Successfully"
echo "========================================="
