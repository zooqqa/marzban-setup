#!/bin/bash

# Production Marzban Setup with SSL
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Production Marzban Setup ===${NC}"

# Get domain from user
read -p "Enter your domain (default: 012301230.xyz): " DOMAIN
DOMAIN=${DOMAIN:-012301230.xyz}

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Domain is required${NC}"
    exit 1
fi

echo -e "${GREEN}Setting up production Marzban for domain: $DOMAIN${NC}"

# Stop current Marzban
echo -e "${YELLOW}Stopping current Marzban...${NC}"
marzban down || true

# Install Nginx and Certbot
echo -e "${YELLOW}Installing Nginx and Certbot...${NC}"
apt update
apt install -y nginx certbot python3-certbot-nginx

# Remove default Nginx config
rm -f /etc/nginx/sites-enabled/default

# Create Nginx config for Marzban
echo -e "${YELLOW}Creating Nginx configuration...${NC}"
cat > /etc/nginx/sites-available/marzban << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # SSL configuration will be added by certbot
    
    # Marzban dashboard
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        
        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
    
    # Block access to sensitive paths
    location ~ ^/(api/admin|api/core) {
        allow 127.0.0.1;
        deny all;
        proxy_pass http://127.0.0.1:8000;
    }
}
EOF

# Enable the site
ln -sf /etc/nginx/sites-available/marzban /etc/nginx/sites-enabled/

# Test Nginx config
nginx -t

# Start Nginx
systemctl enable nginx
systemctl start nginx

# Get SSL certificate
echo -e "${YELLOW}Getting SSL certificate...${NC}"
certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN

# Configure Marzban for production
echo -e "${YELLOW}Configuring Marzban...${NC}"
cat > /opt/marzban/.env << EOF
# Database
SQLALCHEMY_DATABASE_URL=sqlite:////var/lib/marzban/marzban.db

# Uvicorn settings
UVICORN_HOST=127.0.0.1
UVICORN_PORT=8000

# SSL handled by Nginx
UVICORN_SSL_CERTFILE=
UVICORN_SSL_KEYFILE=

# Security
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=1440

# CORS
CORS_ORIGINS=["https://$DOMAIN"]

# Custom settings
APP_NAME="Marzban VPN Panel"
DOCS=false
DEBUG=false

# Subscription settings
SUBSCRIPTION_PAGE_TEMPLATE=""
EOF

# Configure firewall
echo -e "${YELLOW}Configuring firewall...${NC}"
ufw allow 'Nginx Full'
ufw allow 443/tcp
ufw allow 80/tcp
ufw reload

# Start Marzban
echo -e "${YELLOW}Starting Marzban...${NC}"
marzban up

# Wait for Marzban to start
sleep 10

echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo -e "${GREEN}Dashboard URL: https://$DOMAIN${NC}"
echo -e "${GREEN}SSL certificate installed and auto-renewal configured${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Access https://$DOMAIN to login to dashboard"
echo "2. Create VLESS inbound on port 443"
echo "3. Create users and test connections"
echo ""
echo -e "${GREEN}SSL certificate will auto-renew via cron job${NC}"

# Setup auto-renewal
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -

echo -e "${GREEN}Production setup completed successfully!${NC}"