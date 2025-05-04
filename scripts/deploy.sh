#!/bin/bash
set -e

# Color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Default worker count
WORKER_COUNT=1

# Check if worker count was provided as an argument
if [ $# -ge 1 ] && [[ $1 =~ ^[0-9]+$ ]]; then
    WORKER_COUNT=$1
    echo -e "${GREEN}Setting up cluster with $WORKER_COUNT worker node(s)${NC}"
else
    echo -e "${YELLOW}No valid worker count specified, using default: $WORKER_COUNT worker node(s)${NC}"
fi

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

if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo -e "${RED}Error: SSH public key not found at ~/.ssh/id_rsa.pub${NC}"
    exit 1
fi

# Read public key
SSH_PUBLIC_KEY=$(cat ~/.ssh/id_rsa.pub)

# Run OpenTofu
cd tofu
echo -e "${GREEN}Initializing OpenTofu...${NC}"
tofu init

# Create and display plan
echo -e "${YELLOW}Creating infrastructure plan...${NC}"
tofu plan \
    -var "hcloud_token=${HCLOUD_TOKEN}" \
    -var "ssh_public_key=${SSH_PUBLIC_KEY}" \
    -var "ssh_private_key_path=~/.ssh/id_rsa" \
    -var "worker_count=${WORKER_COUNT}"

# Ask for confirmation
echo -e "\n${YELLOW}===================================================================${NC}"
echo -e "${YELLOW}Do you want to apply the plan and create/update the infrastructure?${NC}"
echo -e "${YELLOW}===================================================================${NC}"
echo -e "${YELLOW}Enter 'y' to confirm or any other key to cancel:${NC} "
read -p "" -n 1 -r REPLY
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Applying OpenTofu plan...${NC}"
    tofu apply -auto-approve \
        -var "hcloud_token=${HCLOUD_TOKEN}" \
        -var "ssh_public_key=${SSH_PUBLIC_KEY}" \
        -var "ssh_private_key_path=~/.ssh/id_rsa" \
        -var "worker_count=${WORKER_COUNT}"
    
    echo -e "${GREEN}Infrastructure created/updated!${NC}"
    tofu output
    
    # Ensure inventory file exists
    if [ ! -f ../ansible/inventory/hosts.ini ]; then
        echo -e "${RED}Error: Ansible inventory file not found. It should have been created by OpenTofu.${NC}"
        exit 1
    fi
    
    # Run Ansible
    cd ../ansible
    echo -e "${GREEN}Configuring K3s cluster with Ansible...${NC}"
    ansible-playbook site.yml
    
    echo -e "${GREEN}K3s cluster setup complete!${NC}"
    
    # Cleaning up outdated nodes
    echo -e "${YELLOW}Checking for outdated nodes to clean up...${NC}"
    
    # Install jq if not available
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}jq not found. Installing...${NC}"
        sudo apt-get update && sudo apt-get install -y jq
    fi
    
    # Get the list of all active server IPs from OpenTofu
    cd ../tofu
    ACTIVE_IPS=$(tofu output -json | jq -r '.master_ips.value + .worker_ips.value | .[]')
    echo -e "${GREEN}Active IPs in Hetzner Cloud:${NC}"
    echo "$ACTIVE_IPS"
    
    cd ../ansible
    KUBECONFIG=$(pwd)/k3s.yaml
    
    sleep 5
    
    echo -e "${GREEN}Checking nodes in K3s cluster...${NC}"
    
    NODE_LIST=$(kubectl --kubeconfig=$KUBECONFIG get nodes -o custom-columns=NAME:.metadata.name,IP:.status.addresses[0].address,ROLE:.metadata.labels.node-role\\.kubernetes\\.io/master --no-headers)
    
    echo "Nodes in Kubernetes cluster:"
    echo "$NODE_LIST"
    
    # Iterate through all nodes and check if their IP is still in the active IPs
    echo "$NODE_LIST" | while read -r node_info; do
        NODE_NAME=$(echo "$node_info" | awk '{print $1}')
        NODE_IP=$(echo "$node_info" | awk '{print $2}')
        IS_MASTER=$(echo "$node_info" | awk '{print $3}')
        
        echo -e "Checking node $NODE_NAME with IP $NODE_IP (Master: $IS_MASTER)"
        
        # If it's not a master node and the IP is no longer in the active list
        if [ "$IS_MASTER" != "true" ] && ! echo "$ACTIVE_IPS" | grep -q "$NODE_IP"; then
            echo -e "${YELLOW}Node $NODE_NAME ($NODE_IP) is no longer in Hetzner Cloud. Removing from K3s cluster...${NC}"
            kubectl --kubeconfig=$KUBECONFIG drain "$NODE_NAME" --ignore-daemonsets --delete-emptydir-data --force --timeout=60s || true
            kubectl --kubeconfig=$KUBECONFIG delete node "$NODE_NAME"
            echo -e "${GREEN}Node $NODE_NAME successfully removed from cluster.${NC}"
        fi
    done
    
    echo -e "${GREEN}Final cluster status:${NC}"
    kubectl --kubeconfig=$KUBECONFIG get nodes
    
    # Instructions for copying the kubeconfig
    echo -e "${YELLOW}To use kubectl with your cluster, copy the kubeconfig file:${NC}"
    echo -e "${YELLOW}cp $(pwd)/k3s.yaml ~/.kube/config${NC}"
    echo -e "${YELLOW}cp $(pwd)/k3s.yaml /mnt/c/Users/adegi/.kube/config${NC}"
else
    echo -e "${YELLOW}Operation cancelled. No changes were made.${NC}"
    exit 0
fi