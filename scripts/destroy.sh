#!/bin/bash
set -e

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Check if HCLOUD_TOKEN environment variable is set
if [ -z "$HCLOUD_TOKEN" ]; then
    echo -e "${RED}Error: HCLOUD_TOKEN environment variable is not set. Please export it before running this script.${NC}"
    exit 1
fi

# Check if SSH keys exist
if [ ! -f ~/.ssh/id_rsa ]; then
    echo -e "${RED}Error: SSH private key not found at ~/.ssh/id_rsa${NC}"
    exit 1
fi

# Read public key
SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)

# Run OpenTofu command
cd tofu
echo -e "${GREEN}Initializing OpenTofu...${NC}"
tofu init

# Display the resources that will be destroyed
echo -e "${YELLOW}Showing resources that will be destroyed...${NC}"
tofu plan -destroy \
    -var "hcloud_token=${HCLOUD_TOKEN}" \
    -var "ssh_public_key=${SSH_PUBLIC_KEY}" \
    -var "ssh_private_key_path=~/.ssh/id_rsa"

# Double-check with the user
echo -e "\n${RED}WARNING: This will destroy ALL resources in your Hetzner K3s cluster!${NC}"
echo -e "${RED}All data will be lost and cannot be recovered!${NC}"
echo -e "\n${YELLOW}===================================================================${NC}"
echo -e "${YELLOW}Are you ABSOLUTELY SURE you want to destroy this infrastructure?${NC}"
echo -e "${YELLOW}===================================================================${NC}"
echo -e "${YELLOW}Type 'yes-destroy-everything' to confirm:${NC} "
read -p "" CONFIRM

if [ "$CONFIRM" == "yes-destroy-everything" ]; then
    echo -e "${RED}Destroying infrastructure...${NC}"
    
    # Show current nodes before destroying
    if [ -f ../ansible/k3s.yaml ]; then
        echo -e "${YELLOW}Current K3s nodes before destruction:${NC}"
        KUBECONFIG=$(pwd)/../ansible/k3s.yaml kubectl get nodes || echo "Could not retrieve nodes"
    fi
    
    echo -e "${YELLOW}Step 1: Destroying server instances first...${NC}"
    tofu destroy -auto-approve -target="hcloud_server.worker" -target="hcloud_server.master" \
        -var "hcloud_token=${HCLOUD_TOKEN}" \
        -var "ssh_public_key=${SSH_PUBLIC_KEY}" \
        -var "ssh_private_key_path=~/.ssh/id_rsa"
    
    sleep 10
    echo -e "${YELLOW}Step 2: Destroying network resources...${NC}"
    tofu destroy -auto-approve -target="hcloud_network_subnet.k3s" \
        -var "hcloud_token=${HCLOUD_TOKEN}" \
        -var "ssh_public_key=${SSH_PUBLIC_KEY}" \
        -var "ssh_private_key_path=~/.ssh/id_rsa"
    
    sleep 10
    echo -e "${YELLOW}Step 3: Destroying remaining resources...${NC}"
    tofu destroy -auto-approve \
        -var "hcloud_token=${HCLOUD_TOKEN}" \
        -var "ssh_public_key=${SSH_PUBLIC_KEY}" \
        -var "ssh_private_key_path=~/.ssh/id_rsa"
    
    echo -e "${GREEN}Infrastructure has been destroyed successfully!${NC}"
    
    # Clean up local files
    echo -e "${YELLOW}Cleaning up local files...${NC}"
    rm -f ../ansible/k3s.yaml ../ansible/inventory/hosts.ini || true
    
    echo -e "${GREEN}Cleanup complete. The K3s cluster has been fully destroyed.${NC}"
else
    echo -e "${YELLOW}Destruction cancelled. Your infrastructure is safe.${NC}"
    exit 0
fi