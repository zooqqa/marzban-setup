#!/bin/bash

# Marzban Node Installation Script
# This script installs Marzban-node on additional servers to expand your VPN infrastructure

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Marzban Node Installation Script ===${NC}"
echo -e "${YELLOW}This script will install Marzban-node on this server${NC}"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root (use sudo)${NC}" 
   exit 1
fi

# Get node name from user
echo -e "${YELLOW}Enter a name for this node (e.g., node-germany, node-usa):${NC}"
read -p "Node name: " NODE_NAME

if [ -z "$NODE_NAME" ]; then
    echo -e "${RED}Node name cannot be empty${NC}"
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
ufw --force enable

# Install Docker (required for Marzban-node)
echo -e "${GREEN}Installing Docker...${NC}"
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
systemctl enable docker
systemctl start docker

# Install Docker Compose
echo -e "${GREEN}Installing Docker Compose...${NC}"
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Marzban-node
echo -e "${GREEN}Installing Marzban-node with name: $NODE_NAME${NC}"
bash -c "$(curl -sL https://github.com/Gozargah/Marzban-scripts/raw/master/marzban-node.sh)" @ install --name "$NODE_NAME"

# Display installation info
echo -e "${GREEN}=== Node Installation Complete! ===${NC}"
echo -e "${GREEN}Node name: $NODE_NAME${NC}"
echo -e "${GREEN}Configuration file: /opt/$NODE_NAME/.env${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Configure the node in your main Marzban dashboard"
echo "2. Add this server's IP and certificate to your main server"
echo "3. Update the node configuration if needed"
echo ""
echo -e "${GREEN}Useful commands:${NC}"
echo "- View logs: $NODE_NAME logs"
echo "- Restart service: $NODE_NAME restart"
echo "- Update: $NODE_NAME update"
echo "- Stop service: $NODE_NAME down"
echo ""
echo -e "${YELLOW}Server IP: $(curl -s ifconfig.me)${NC}"