#!/bin/bash

set -euo pipefail

#############################################
# Configuration
#############################################

ROOT_DIR="/home/appuser/apps/ecom-lite"
APP_DIR="$ROOT_DIR/backend"

SECRET_NAME="ecom-lite/prod/backend"
REGION="ap-south-1"

APP_NAME="backend"

#############################################
# Checks
#############################################

for cmd in aws jq pm2 npm npx; do
    command -v "$cmd" >/dev/null 2>&1 || {
        echo "$cmd is not installed."
        exit 1
    }
done

#############################################
# Backend
#############################################

echo "========================================="
echo "Deploying Backend"
echo "========================================="

cd "$APP_DIR"

#############################################
# Fetch Secret
#############################################

echo "Fetching secrets..."

SECRET_JSON=$(aws secretsmanager get-secret-value \
    --region "$REGION" \
    --secret-id "$SECRET_NAME" \
    --query SecretString \
    --output text)

#############################################
# Parse Secret
#############################################

JWT_SECRET=$(echo "$SECRET_JSON" | jq -r '.JWT_SECRET')
JWT_EXPIRES_IN=$(echo "$SECRET_JSON" | jq -r '.JWT_EXPIRES_IN')
NODE_ENV=$(echo "$SECRET_JSON" | jq -r '.NODE_ENV')
PORT=$(echo "$SECRET_JSON" | jq -r '.PORT')
FRONTEND_URL=$(echo "$SECRET_JSON" | jq -r '.FRONTEND_URL')

DB_HOST=$(echo "$SECRET_JSON" | jq -r '.DB_HOST')
DB_PORT=$(echo "$SECRET_JSON" | jq -r '.DB_PORT')
DB_NAME=$(echo "$SECRET_JSON" | jq -r '.DB_NAME')
DB_USERNAME=$(echo "$SECRET_JSON" | jq -r '.DB_USERNAME')
DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.DB_PASSWORD')

#############################################
# Generate DATABASE_URL
#############################################

DATABASE_URL="postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

#############################################
# Generate .env
#############################################

cat > .env <<EOF
PORT=$PORT
DATABASE_URL=$DATABASE_URL
JWT_SECRET=$JWT_SECRET
JWT_EXPIRES_IN=$JWT_EXPIRES_IN
NODE_ENV=$NODE_ENV
FRONTEND_URL=$FRONTEND_URL
EOF

#############################################
# Install Packages
#############################################

echo "Installing backend dependencies..."

npm install

#############################################
# Prisma
#############################################

echo "Generating Prisma Client..."

npx prisma generate

echo "Running Migrations..."

npx prisma migrate deploy

#############################################
# Restart Backend
#############################################

echo "Restarting Backend..."

pm2 delete "$APP_NAME" >/dev/null 2>&1 || true

pm2 start src/server.js \
    --name "$APP_NAME"

pm2 save

#############################################
# Health Check
#############################################

echo "Waiting for backend..."

sleep 5

curl -f http://localhost:5000/health >/dev/null || {
    echo "Backend failed health check."
    exit 1
}

echo ""
echo "========================================="
echo "Backend Deployment Successful"
echo "========================================="
