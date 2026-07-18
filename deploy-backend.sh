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

# DB_SSL: read from secret if present, default to "true" since RDS
# requires SSL. Prisma's pg driver only enables SSL when this is
# exactly the string "true" (see src/config/prisma.js).
DB_SSL=$(echo "$SECRET_JSON" | jq -r '.DB_SSL // "true"')

#############################################
# Generate DATABASE_URL
#############################################
DATABASE_URL="postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}"

#############################################
# Generate .env (quoted heredoc + sed substitution
# avoids bash re-expanding secrets that may contain
# special characters like $, @, etc.)
#############################################
cat > .env <<'EOF'
PORT=__PORT__
DATABASE_URL=__DATABASE_URL__
DB_SSL=__DB_SSL__
JWT_SECRET=__JWT_SECRET__
JWT_EXPIRES_IN=__JWT_EXPIRES_IN__
NODE_ENV=__NODE_ENV__
FRONTEND_URL=__FRONTEND_URL__
EOF

sed -i "s|__PORT__|${PORT}|" .env
sed -i "s|__DATABASE_URL__|${DATABASE_URL}|" .env
sed -i "s|__DB_SSL__|${DB_SSL}|" .env
sed -i "s|__JWT_SECRET__|${JWT_SECRET}|" .env
sed -i "s|__JWT_EXPIRES_IN__|${JWT_EXPIRES_IN}|" .env
sed -i "s|__NODE_ENV__|${NODE_ENV}|" .env
sed -i "s|__FRONTEND_URL__|${FRONTEND_URL}|" .env

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
