#!/bin/bash

# Complete Marzban Installation with VLESS WebSocket
# This script installs and fully configures Marzban with working VLESS WebSocket

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Complete Marzban VPN Installation ===${NC}"

# Get domain from user
read -p "Enter your domain (e.g., yourvpn.duckdns.org): " DOMAIN

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Domain is required${NC}"
    exit 1
fi

echo -e "${GREEN}Installing Marzban with VLESS WebSocket for domain: $DOMAIN${NC}"

# Function to check if domain resolves to server IP
check_domain() {
    echo -e "${YELLOW}Checking DNS resolution for $DOMAIN...${NC}"
    SERVER_IP=$(curl -4 -s ifconfig.me)
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

# Update system
echo -e "${YELLOW}Updating system packages...${NC}"
apt update && apt upgrade -y

# Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"
apt install -y curl wget git ufw nginx certbot python3-certbot-nginx dnsutils

# Configure firewall
echo -e "${YELLOW}Configuring firewall...${NC}"
ufw allow ssh
ufw allow 'Nginx Full'
ufw allow 443/tcp
ufw allow 80/tcp
ufw --force enable

# Install Docker
echo -e "${YELLOW}Installing Docker...${NC}"
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker

# Install Docker Compose
echo -e "${YELLOW}Installing Docker Compose...${NC}"
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Marzban
echo -e "${YELLOW}Installing Marzban...${NC}"
bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install

# Stop Marzban to configure it properly
marzban down

# Check domain resolution
check_domain

# Remove default Nginx config
rm -f /etc/nginx/sites-enabled/default

# Create Nginx configuration with WebSocket support
echo -e "${YELLOW}Creating Nginx configuration with WebSocket support...${NC}"
cat > /etc/nginx/sites-available/marzban << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    # For Let's Encrypt validation
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Temporary redirect to HTTPS (will be updated after SSL)
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    # SSL certificates (will be configured by certbot)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # SSL settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES256-GCM-SHA512:DHE-RSA-AES256-GCM-SHA512:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;
    
    # VLESS WebSocket proxy
    location /vless-ws {
        proxy_pass http://127.0.0.1:8443;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_redirect off;
    }
    
    # Marzban dashboard
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_redirect off;
        
        # WebSocket support for dashboard
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Enable HTTP-only config first
cat > /etc/nginx/sites-available/marzban-temp << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

ln -sf /etc/nginx/sites-available/marzban-temp /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Configure Marzban for production
echo -e "${YELLOW}Configuring Marzban...${NC}"
cat > /opt/marzban/.env << EOF
# Database
SQLALCHEMY_DATABASE_URL=sqlite:////var/lib/marzban/marzban.db

# Uvicorn settings
UVICORN_HOST=127.0.0.1
UVICORN_PORT=8000

# Security
JWT_ACCESS_TOKEN_EXPIRE_MINUTES=1440
CORS_ORIGINS=["https://$DOMAIN"]
APP_NAME="Marzban VPN Panel"
DOCS=false
DEBUG=false
EOF

# Start Marzban
echo -e "${YELLOW}Starting Marzban...${NC}"
marzban up
sleep 10

# Get SSL certificate
echo -e "${YELLOW}Getting SSL certificate...${NC}"
if certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN; then
    echo -e "${GREEN}✓ SSL certificate obtained${NC}"
    # Switch to full HTTPS config
    rm -f /etc/nginx/sites-enabled/marzban-temp
    ln -sf /etc/nginx/sites-available/marzban /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    PANEL_URL="https://$DOMAIN"
else
    echo -e "${YELLOW}SSL failed, using HTTP config${NC}"
    PANEL_URL="http://$DOMAIN"
fi

# Setup auto-renewal for SSL
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet --reload-hook 'systemctl reload nginx'") | crontab -

# Create the correct Core configuration
echo -e "${YELLOW}Updating Xray Core configuration...${NC}"

# Wait a bit more for Marzban to fully start
sleep 5

echo -e "${GREEN}=== Installation Complete! ===${NC}"
echo ""
echo -e "${GREEN}Dashboard URL: $PANEL_URL${NC}"
echo ""
echo -e "${YELLOW}IMPORTANT: Complete the setup with these steps:${NC}"
echo ""
echo "1. Create admin user:"
echo "   marzban cli admin create --sudo"
echo ""
echo "2. Open $PANEL_URL and login"
echo ""
echo "3. Go to 'Core Settings' and replace configuration with:"
echo ""
echo -e "${GREEN}--- Copy this EXACT configuration ---${NC}"
cat << 'CORECONFIG'
{
  "log": {
    "loglevel": "warning"
  },
  "routing": {
    "rules": [
      {
        "ip": [
          "geoip:private"
        ],
        "outboundTag": "BLOCK",
        "type": "field"
      }
    ]
  },
  "inbounds": [
    {
      "tag": "VLESS WebSocket",
      "listen": "127.0.0.1",
      "port": 8443,
      "protocol": "vless",
      "settings": {
        "clients": [],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "/vless-ws"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "DIRECT"
    },
    {
      "protocol": "blackhole",
      "tag": "BLOCK"
    }
  ]
}
CORECONFIG
echo -e "${GREEN}--- End of configuration ---${NC}"
echo ""
echo "4. Save and restart Xray Core"
echo ""
echo "5. Go to 'Host Settings' and create:"
echo "   - Remark: VLESS-WS-TLS"
echo "   - Address: $DOMAIN"
echo "   - Port: 443"
echo "   - Path: /vless-ws"
echo "   - Network: ws"
echo "   - Security: tls"
echo "   - SNI: $DOMAIN"
echo "   - Enable 'Use SNI as host'"
echo ""
echo "6. Create users in 'Users' section"
echo ""
echo -e "${GREEN}Your VLESS endpoint: wss://$DOMAIN:443/vless-ws${NC}"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "- View logs: marzban logs"
echo "- Restart: marzban restart"
echo "- Check WebSocket port: ss -tlnp | grep 8443"
echo ""
echo -e "${GREEN}Installation completed successfully!${NC}"