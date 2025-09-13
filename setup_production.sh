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

# Function to check if domain resolves to server IP
check_domain() {
    echo -e "${YELLOW}Checking DNS resolution for $DOMAIN...${NC}"
    SERVER_IP=$(curl -s ifconfig.me)
    DOMAIN_IP=$(dig +short $DOMAIN | head -n1)
    
    if [ "$DOMAIN_IP" = "$SERVER_IP" ]; then
        echo -e "${GREEN}✓ Domain resolves correctly to $SERVER_IP${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Domain resolves to $DOMAIN_IP but server IP is $SERVER_IP${NC}"
        echo -e "${YELLOW}DNS may still be propagating. Continuing anyway...${NC}"
        return 1
    fi
}

# Stop current Marzban
echo -e "${YELLOW}Stopping current Marzban...${NC}"
marzban down 2>/dev/null || echo "Marzban was already down"

# Install Nginx and Certbot
echo -e "${YELLOW}Installing Nginx and Certbot...${NC}"
apt update
apt install -y nginx certbot python3-certbot-nginx dig

# Remove any existing configs
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/sites-enabled/marzban*
rm -f /etc/nginx/sites-available/marzban*

# Check domain resolution
check_domain

# Create temporary HTTP-only Nginx config for certificate generation
echo -e "${YELLOW}Creating temporary Nginx configuration...${NC}"
cat > /etc/nginx/sites-available/marzban-temp << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # For Let's Encrypt validation
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Proxy to Marzban for now
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Enable temporary config
ln -sf /etc/nginx/sites-available/marzban-temp /etc/nginx/sites-enabled/

# Test and start Nginx
nginx -t
systemctl enable nginx
systemctl restart nginx

# Wait for DNS propagation if needed
echo -e "${YELLOW}Testing domain availability...${NC}"
for i in {1..5}; do
    if curl -s --connect-timeout 5 http://$DOMAIN > /dev/null; then
        echo -e "${GREEN}✓ Domain is accessible${NC}"
        break
    else
        echo -e "${YELLOW}Waiting for domain to become accessible... (attempt $i/5)${NC}"
        sleep 10
    fi
done

# Get SSL certificate
echo -e "${YELLOW}Getting SSL certificate from Let's Encrypt...${NC}"
if certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN --redirect; then
    echo -e "${GREEN}✓ SSL certificate obtained successfully${NC}"
else
    echo -e "${RED}✗ Failed to get SSL certificate${NC}"
    echo -e "${YELLOW}Continuing with HTTP setup...${NC}"
    SSL_FAILED=true
fi

# Remove temporary config
rm -f /etc/nginx/sites-enabled/marzban-temp

# Create final Nginx configuration
echo -e "${YELLOW}Creating final Nginx configuration...${NC}"
if [ "$SSL_FAILED" = "true" ]; then
    # HTTP-only configuration
    cat > /etc/nginx/sites-available/marzban << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
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
}
EOF
    PANEL_URL="http://$DOMAIN"
else
    # HTTPS configuration
    cat > /etc/nginx/sites-available/marzban << EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
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
}
EOF
    PANEL_URL="https://$DOMAIN"
fi

# Enable the site
ln -sf /etc/nginx/sites-available/marzban /etc/nginx/sites-enabled/

# Test Nginx config
nginx -t && systemctl reload nginx

# Configure Marzban for production
echo -e "${YELLOW}Configuring Marzban for production...${NC}"
cat > /opt/marzban/.env << EOF
# Database
SQLALCHEMY_DATABASE_URL=sqlite:////var/lib/marzban/marzban.db

# Uvicorn settings - bind only to localhost (Nginx handles external access)
UVICORN_HOST=127.0.0.1
UVICORN_PORT=8000

# SSL handled by Nginx
UVICORN_SSL_CERTFILE=
UVICORN_SSL_KEYFILE=

# Security
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=1440

# CORS
CORS_ORIGINS=["$PANEL_URL"]

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
ufw allow ssh
ufw --force enable
ufw reload

# Start Marzban
echo -e "${YELLOW}Starting Marzban...${NC}"
marzban up

# Wait for Marzban to start
echo -e "${YELLOW}Waiting for Marzban to start...${NC}"
sleep 15

# Check if Marzban is running
if curl -s http://127.0.0.1:8000 > /dev/null; then
    echo -e "${GREEN}✓ Marzban is running${NC}"
else
    echo -e "${RED}✗ Marzban failed to start${NC}"
    echo -e "${YELLOW}Check logs with: marzban logs${NC}"
fi

# Setup SSL certificate auto-renewal
if [ "$SSL_FAILED" != "true" ]; then
    echo -e "${YELLOW}Setting up SSL certificate auto-renewal...${NC}"
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet --reload-hook 'systemctl reload nginx'") | crontab -
    echo -e "${GREEN}✓ SSL auto-renewal configured${NC}"
fi

echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo -e "${GREEN}Dashboard URL: $PANEL_URL${NC}"
echo -e "${GREEN}Configuration: /opt/marzban/.env${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Access $PANEL_URL to login to dashboard"
echo "2. Create admin user: marzban cli admin create --sudo"
echo "3. Configure VLESS inbound on port 443 in Core Settings"
echo "4. Create VPN users"
echo ""
if [ "$SSL_FAILED" != "true" ]; then
    echo -e "${GREEN}✓ SSL certificate installed and configured for auto-renewal${NC}"
else
    echo -e "${YELLOW}⚠ SSL setup failed. Panel accessible via HTTP only.${NC}"
    echo -e "${YELLOW}You can retry SSL setup later with: certbot --nginx -d $DOMAIN${NC}"
fi

echo -e "${GREEN}Production setup completed!${NC}"