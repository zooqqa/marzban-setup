#!/bin/bash

# Add Marzban Node to existing infrastructure
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Add Marzban Node ===${NC}"

# Get information from user
read -p "Enter node name (e.g., usa-node, uk-node): " NODE_NAME
read -p "Enter your domain for this node (e.g., usa.yourdomain.com): " DOMAIN

if [ -z "$NODE_NAME" ] || [ -z "$DOMAIN" ]; then
    echo -e "${RED}Node name and domain are required${NC}"
    exit 1
fi

echo -e "${GREEN}Setting up Marzban Node: $NODE_NAME with domain: $DOMAIN${NC}"

# Get server location for reference
SERVER_IP=$(curl -4 -s ifconfig.me)
echo -e "${YELLOW}Server IP: $SERVER_IP${NC}"
echo -e "${YELLOW}Make sure $DOMAIN points to this IP${NC}"

# Update system
echo -e "${YELLOW}Updating system...${NC}"
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

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    systemctl enable docker
    systemctl start docker
fi

# Install Docker Compose if not present
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}Installing Docker Compose...${NC}"
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
fi

# Install Marzban Node
echo -e "${YELLOW}Installing Marzban Node: $NODE_NAME${NC}"
bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban-node.sh)" @ install --name "$NODE_NAME"

# Stop node to configure it
$NODE_NAME down || true

# Create Nginx configuration for the node
echo -e "${YELLOW}Creating Nginx configuration...${NC}"
rm -f /etc/nginx/sites-enabled/default

# Create temporary HTTP config
cat > /etc/nginx/sites-available/$NODE_NAME << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 444; # Close connection for security
    }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    
    # VLESS WebSocket proxy for node
    location /vless-ws {
        proxy_pass http://127.0.0.1:8443;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Block all other requests for security
    location / {
        return 444;
    }
}
EOF

# Create temporary HTTP-only config first
cat > /etc/nginx/sites-available/$NODE_NAME-temp << EOF
server {
    listen 80;
    server_name $DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 444;
    }
}
EOF

ln -sf /etc/nginx/sites-available/$NODE_NAME-temp /etc/nginx/sites-enabled/
nginx -t && systemctl restart nginx

# Start the node
echo -e "${YELLOW}Starting Marzban Node...${NC}"
$NODE_NAME up
sleep 10

# Get SSL certificate
echo -e "${YELLOW}Getting SSL certificate...${NC}"
if certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN; then
    echo -e "${GREEN}✓ SSL certificate obtained${NC}"
    rm -f /etc/nginx/sites-enabled/$NODE_NAME-temp
    ln -sf /etc/nginx/sites-available/$NODE_NAME /etc/nginx/sites-enabled/
    nginx -t && systemctl reload nginx
    NODE_URL="https://$DOMAIN"
else
    echo -e "${YELLOW}SSL failed, check DNS settings${NC}"
    NODE_URL="http://$DOMAIN"
fi

# Setup SSL auto-renewal
(crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet --reload-hook 'systemctl reload nginx'") | crontab -

echo -e "${GREEN}=== Node Installation Complete! ===${NC}"
echo ""
echo -e "${GREEN}Node Name: $NODE_NAME${NC}"
echo -e "${GREEN}Node Domain: $DOMAIN${NC}"
echo -e "${GREEN}Node IP: $SERVER_IP${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. In your MAIN Marzban panel, go to 'Node Settings'"
echo "2. Add new node with these details:"
echo "   - Name: $NODE_NAME"
echo "   - Address: $SERVER_IP"
echo "   - Port: 62050 (default Marzban-node port)"
echo "   - API Port: 62051"
echo "   - Certificate: (get from main server)"
echo ""
echo "3. Configure this node's Xray with VLESS WebSocket:"
echo "   - Edit /opt/$NODE_NAME/xray_config.json"
echo "   - Add VLESS inbound on port 8443 with WebSocket"
echo "   - Path: /vless-ws"
echo ""
echo "4. In Host Settings of main panel, create entry:"
echo "   - Address: $DOMAIN"
echo "   - Port: 443"
echo "   - Path: /vless-ws"
echo "   - Network: ws"
echo "   - Security: tls"
echo "   - SNI: $DOMAIN"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "- Check node status: $NODE_NAME status"
echo "- View node logs: $NODE_NAME logs"
echo "- Restart node: $NODE_NAME restart"
echo ""
echo -e "${GREEN}Node ready for connection to main Marzban server!${NC}"