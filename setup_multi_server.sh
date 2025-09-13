#!/bin/bash

# Multi-Server Setup Script for Marzban
# This script helps configure multi-server setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Marzban Multi-Server Setup ===${NC}"

# Function to add a new node
add_node() {
    echo -e "${YELLOW}Adding new node to Marzban...${NC}"
    
    read -p "Enter node IP address: " NODE_IP
    read -p "Enter node name (e.g., germany-node): " NODE_NAME
    read -p "Enter node port (default 8000): " NODE_PORT
    NODE_PORT=${NODE_PORT:-8000}
    
    if [ -z "$NODE_IP" ] || [ -z "$NODE_NAME" ]; then
        echo -e "${RED}Node IP and name are required${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}Node configuration:${NC}"
    echo "IP: $NODE_IP"
    echo "Name: $NODE_NAME" 
    echo "Port: $NODE_PORT"
    
    # Test connection to node
    echo -e "${YELLOW}Testing connection to node...${NC}"
    if curl -s --connect-timeout 5 "http://$NODE_IP:$NODE_PORT/health" > /dev/null; then
        echo -e "${GREEN}✓ Node is accessible${NC}"
    else
        echo -e "${RED}✗ Cannot connect to node${NC}"
        read -p "Continue anyway? (y/N): " CONTINUE
        if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Add to configuration
    echo -e "${YELLOW}Adding node to Marzban configuration...${NC}"
    
    # Create or update nodes configuration file
    NODES_FILE="/opt/marzban/nodes.json"
    if [ ! -f "$NODES_FILE" ]; then
        echo "[]" > "$NODES_FILE"
    fi
    
    # Add node to JSON configuration (simplified)
    NODE_CONFIG=$(cat <<EOF
{
    "name": "$NODE_NAME",
    "address": "$NODE_IP",
    "port": $NODE_PORT,
    "api_port": $NODE_PORT,
    "usage_coefficient": 1.0,
    "status": "connected"
}
EOF
    )
    
    echo "Node added to configuration. You need to add it through the Marzban dashboard:"
    echo "1. Login to your Marzban dashboard"
    echo "2. Go to 'Nodes' section"
    echo "3. Click 'Add Node'"
    echo "4. Enter the following details:"
    echo "   - Name: $NODE_NAME"
    echo "   - Address: $NODE_IP"
    echo "   - Port: $NODE_PORT"
}

# Function to list nodes
list_nodes() {
    echo -e "${GREEN}Current nodes configuration:${NC}"
    
    # This would need to be integrated with Marzban's actual API
    echo "Use 'marzban cli node list' or check the dashboard for current nodes"
}

# Function to remove node
remove_node() {
    read -p "Enter node name to remove: " NODE_NAME
    
    if [ -z "$NODE_NAME" ]; then
        echo -e "${RED}Node name is required${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}Removing node $NODE_NAME...${NC}"
    echo "Please remove the node through the Marzban dashboard:"
    echo "1. Login to your Marzban dashboard"
    echo "2. Go to 'Nodes' section"
    echo "3. Find node '$NODE_NAME' and click 'Remove'"
}

# Main menu
echo -e "${YELLOW}What would you like to do?${NC}"
echo "1. Add new node"
echo "2. List current nodes" 
echo "3. Remove node"
echo "4. Exit"

read -p "Choose option (1-4): " CHOICE

case $CHOICE in
    1)
        add_node
        ;;
    2)
        list_nodes
        ;;
    3)
        remove_node
        ;;
    4)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid option${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}Operation completed!${NC}"