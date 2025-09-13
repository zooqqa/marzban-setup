#!/bin/bash

# VLESS WebSocket Setup for Marzban
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== VLESS WebSocket Setup ===${NC}"

# Get domain from user
read -p "Enter your domain (default: 012301230.xyz): " DOMAIN
DOMAIN=${DOMAIN:-012301230.xyz}

if [ -z "$DOMAIN" ]; then
    echo -e "${RED}Domain is required${NC}"
    exit 1
fi

echo -e "${GREEN}Setting up VLESS WebSocket for domain: $DOMAIN${NC}"

# Check if Nginx config exists
if [ ! -f "/etc/nginx/sites-available/marzban" ]; then
    echo -e "${RED}Nginx configuration not found. Please run setup_production.sh first${NC}"
    exit 1
fi

# Step 1: Update Nginx configuration for WebSocket
echo -e "${YELLOW}Updating Nginx configuration for VLESS WebSocket...${NC}"

# Create backup of current config
cp /etc/nginx/sites-available/marzban /etc/nginx/sites-available/marzban.backup

# Update Nginx config to include WebSocket proxy
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

# Test Nginx configuration
echo -e "${YELLOW}Testing Nginx configuration...${NC}"
if nginx -t; then
    echo -e "${GREEN}✓ Nginx configuration is valid${NC}"
    systemctl reload nginx
    echo -e "${GREEN}✓ Nginx reloaded successfully${NC}"
else
    echo -e "${RED}✗ Nginx configuration error. Restoring backup...${NC}"
    cp /etc/nginx/sites-available/marzban.backup /etc/nginx/sites-available/marzban
    nginx -t && systemctl reload nginx
    exit 1
fi

# Step 2: Update Marzban Core configuration
echo -e "${YELLOW}Updating Marzban Core configuration...${NC}"

# Create backup of current Marzban config
if [ -f "/opt/marzban/xray_config.json" ]; then
    cp /opt/marzban/xray_config.json /opt/marzban/xray_config.json.backup
fi

# Stop Marzban to update configuration
echo -e "${YELLOW}Stopping Marzban...${NC}"
marzban down

# The user will need to update the Core Settings manually through the web interface
# We'll provide the configuration they need to paste

echo -e "${GREEN}=== Manual Configuration Required ===${NC}"
echo -e "${YELLOW}Please follow these steps in the Marzban dashboard:${NC}"
echo ""
echo "1. Open https://$DOMAIN and login to Marzban dashboard"
echo "2. Go to 'Core Settings'"
echo "3. Replace the entire configuration with the following:"
echo ""
echo -e "${GREEN}--- Copy this configuration ---${NC}"
cat << 'EOF'
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
EOF
echo -e "${GREEN}--- End of configuration ---${NC}"
echo ""
echo "4. Save the configuration"
echo "5. Restart Xray Core"
echo ""
echo -e "${YELLOW}For Host Settings, use these parameters:${NC}"
echo "- Remark: VLESS-WS-TLS"
echo "- Address: $DOMAIN"
echo "- Port: 443"
echo "- Path: /vless-ws"
echo "- Network: ws"
echo "- Security: tls"
echo "- SNI: $DOMAIN"
echo "- Enable: Use SNI as host"
echo ""

# Start Marzban
echo -e "${YELLOW}Starting Marzban...${NC}"
marzban up

# Wait for Marzban to start
sleep 10

# Check if services are running
echo -e "${YELLOW}Checking services...${NC}"

# Check Nginx
if systemctl is-active --quiet nginx; then
    echo -e "${GREEN}✓ Nginx is running${NC}"
else
    echo -e "${RED}✗ Nginx is not running${NC}"
fi

# Check Marzban
if curl -s http://127.0.0.1:8000 > /dev/null; then
    echo -e "${GREEN}✓ Marzban is running${NC}"
else
    echo -e "${RED}✗ Marzban is not responding${NC}"
fi

echo ""
echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Complete the manual configuration above in the dashboard"
echo "2. Create a VLESS user in the Users section"
echo "3. Test the connection with a VLESS client"
echo ""
echo -e "${GREEN}Dashboard: https://$DOMAIN${NC}"
echo -e "${GREEN}VLESS endpoint: wss://$DOMAIN:443/vless-ws${NC}"
echo ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo "- Check Marzban logs: marzban logs"
echo "- Check Nginx logs: tail -f /var/log/nginx/error.log"
echo "- Verify port 8443: ss -tlnp | grep 8443"
echo ""
echo -e "${GREEN}WebSocket VLESS setup completed!${NC}"