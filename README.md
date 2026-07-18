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
BACKEND_REPO="https://github.com/BOT-Parth/ecom-lite-backend.git"
FRONTEND_REPO="https://github.com/BOT-Parth/ecom-lite-frontend-.git"
SCRIPTS_REPO="https://github.com/BOT-Parth/ecom-scripts.git"

#############################################
# Create appuser (stock AMI has no such user by default)
#############################################
if ! id -u appuser >/dev/null 2>&1; then
    useradd -m -s /bin/bash appuser
fi

#############################################
# System Update
#############################################
dnf update -y

#############################################
# Install Packages
#############################################
dnf install -y git nginx jq

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
# Nginx: minimal base config
# (site config lives entirely in conf.d/ecom-lite.conf)
#############################################
cat > /etc/nginx/nginx.conf <<'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    keepalive_timeout   65;
    types_hash_max_size 4096;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    include /etc/nginx/conf.d/*.conf;
}
EOF

#############################################
# Nginx: site config
# Serves the built frontend, proxies /api/ to backend on :5000
#############################################
mkdir -p /etc/nginx/conf.d
cat > /etc/nginx/conf.d/ecom-lite.conf <<'EOF'
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri /index.html;
    }

    location /api/ {
        proxy_pass http://127.0.0.1:5000/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

nginx -t

#############################################
# Grant appuser limited access to manage nginx
# content + service (no interactive sudo needed)
#############################################
mkdir -p /usr/share/nginx/html
chown -R appuser:appuser /usr/share/nginx/html

cat > /etc/sudoers.d/appuser-nginx <<'EOF'
appuser ALL=(root) NOPASSWD: /usr/bin/systemctl reload nginx
appuser ALL=(root) NOPASSWD: /usr/bin/systemctl restart nginx
EOF
chmod 440 /etc/sudoers.d/appuser-nginx

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
# Enable Nginx on Boot
#############################################
systemctl enable nginx

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
