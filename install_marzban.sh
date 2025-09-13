#!/bin/bash

# Marzban Installation Script for Ubuntu
# This script installs Marzban VPN management panel with VLESS support

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Marzban VPN Installation Script ===${NC}"
echo -e "${YELLOW}This script will install Marzban on your Ubuntu server${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root (use sudo)${NC}" 
   exit 1
fi

# Update system
echo -e "${GREEN}Updating system packages...${NC}"
apt update && apt upgrade -y

# Install required packages
echo -e "${GREEN}Installing required packages...${NC}"
apt install -y curl wget git ufw

# Configure firewall
echo -e "${GREEN}Configuring firewall...${NC}"
ufw allow ssh
ufw allow 8000/tcp  # Marzban dashboard
ufw allow 443/tcp   # HTTPS
ufw allow 80/tcp    # HTTP
ufw --force enable

# Install Docker (required for Marzban)
echo -e "${GREEN}Installing Docker...${NC}"
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker

# Install Docker Compose
echo -e "${GREEN}Installing Docker Compose...${NC}"
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Marzban
echo -e "${GREEN}Installing Marzban...${NC}"
bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban.sh)" @ install

# Wait for services to start
echo -e "${GREEN}Waiting for services to start...${NC}"
sleep 10

# Create admin user
echo -e "${GREEN}Creating admin user...${NC}"
echo -e "${YELLOW}Please enter admin credentials:${NC}"
marzban cli admin create --sudo

# Display installation info
echo -e "${GREEN}=== Installation Complete! ===${NC}"
echo -e "${GREEN}Dashboard URL: https://$(curl -s ifconfig.me):8000/dashboard/${NC}"
echo -e "${GREEN}Configuration file: /opt/marzban/.env${NC}"
echo -e "${GREEN}Data directory: /var/lib/marzban${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Access the dashboard using the URL above"
echo "2. Login with the admin credentials you just created"
echo "3. Configure your VLESS settings in the dashboard"
echo "4. Use the install_marzban_node.sh script to add additional servers"
echo ""
echo -e "${GREEN}Useful commands:${NC}"
echo "- View logs: marzban logs"
echo "- Restart service: marzban restart"
echo "- Update: marzban update"
echo "- Stop service: marzban down"