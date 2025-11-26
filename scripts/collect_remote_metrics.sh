#!/bin/bash

# Collect Remote Monitoring Data Script
# Pulls monitoring data from remote nodes to local directory
# Usage: ./collect_remote_metrics.sh

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REMOTE_NODES=("hadoop002" "hadoop003")
REMOTE_METRICS_DIR="~/monitoring/system_metrics"
LOCAL_BASE_DIR="other_node_monitoring"

echo -e "${BLUE}=== Collect Remote Node Monitoring Data ===${NC}"
echo -e "${YELLOW}Remote Nodes: ${REMOTE_NODES[*]}${NC}"
echo -e "${YELLOW}Remote Directory: ${REMOTE_METRICS_DIR}${NC}"
echo -e "${YELLOW}Local Directory: ${LOCAL_BASE_DIR}${NC}"

# Create local base directory
echo -e "\n${CYAN}Creating local directory structure...${NC}"
mkdir -p "${LOCAL_BASE_DIR}"
echo -e "${GREEN}✓ Created ${LOCAL_BASE_DIR}/${NC}"

# Track statistics
total_nodes=${#REMOTE_NODES[@]}
successful_nodes=0
failed_nodes=0
total_files=0
total_size=0

# Function to collect data from a single node
collect_from_node() {
    local node=$1
    local node_dir="${LOCAL_BASE_DIR}/${node}"
    
    echo -e "\n${BLUE}=== Processing ${node} ===${NC}"
    
    # Create node-specific directory
    mkdir -p "${node_dir}"
    echo -e "${CYAN}  → Created directory: ${node_dir}${NC}"
    
    # Check if remote directory exists
    if ! ssh "${node}" "test -d ${REMOTE_METRICS_DIR}" 2>/dev/null; then
        echo -e "${RED}  ✗ Remote directory ${REMOTE_METRICS_DIR} not found on ${node}${NC}"
        return 1
    fi
    
    # Check if there are any files
    local file_count=$(ssh "${node}" "ls ${REMOTE_METRICS_DIR}/*.csv 2>/dev/null | wc -l" 2>/dev/null || echo "0")
    
    if [ "$file_count" -eq 0 ]; then
        echo -e "${YELLOW}  ⚠ No CSV files found on ${node}${NC}"
        return 1
    fi
    
    echo -e "${CYAN}  → Found ${file_count} CSV file(s) on ${node}${NC}"
    
    # Copy files from remote node
    echo -e "${CYAN}  → Copying files from ${node}...${NC}"
    if scp -r "${node}:${REMOTE_METRICS_DIR}/*.csv" "${node_dir}/" 2>/dev/null; then
        # Count local files and calculate size
        local copied_files=$(ls "${node_dir}"/*.csv 2>/dev/null | wc -l)
        local dir_size=$(du -sh "${node_dir}" | cut -f1)
        
        echo -e "${GREEN}  ✓ Successfully copied ${copied_files} file(s) (${dir_size})${NC}"
        
        # Update statistics
        total_files=$((total_files + copied_files))
        return 0
    else
        echo -e "${RED}  ✗ Failed to copy files from ${node}${NC}"
        return 1
    fi
}

# Collect data from all nodes
echo -e "\n${BLUE}=== Starting Data Collection ===${NC}"

for node in "${REMOTE_NODES[@]}"; do
    if collect_from_node "${node}"; then
        successful_nodes=$((successful_nodes + 1))
    else
        failed_nodes=$((failed_nodes + 1))
    fi
done

# Calculate total size
if [ -d "${LOCAL_BASE_DIR}" ]; then
    total_size=$(du -sh "${LOCAL_BASE_DIR}" | cut -f1)
fi

# Display summary
echo -e "\n${BLUE}=== Collection Summary ===${NC}"
echo -e "Total Nodes: ${total_nodes}"
echo -e "Successful: ${GREEN}${successful_nodes}${NC}"
echo -e "Failed: ${RED}${failed_nodes}${NC}"
echo -e "Total Files Collected: ${total_files}"
echo -e "Total Size: ${total_size}"

# List collected files
if [ $successful_nodes -gt 0 ]; then
    echo -e "\n${BLUE}=== Collected Files ===${NC}"
    for node in "${REMOTE_NODES[@]}"; do
        local node_dir="${LOCAL_BASE_DIR}/${node}"
        if [ -d "${node_dir}" ] && [ "$(ls -A ${node_dir}/*.csv 2>/dev/null)" ]; then
            echo -e "\n${CYAN}${node}:${NC}"
            ls -lh "${node_dir}"/*.csv | awk '{printf "  %s  %s\n", $5, $9}'
        fi
    done
    
    echo -e "\n${GREEN}✓ All data collected successfully!${NC}"
    echo -e "${YELLOW}Data location: ${LOCAL_BASE_DIR}/${NC}"
else
    echo -e "\n${RED}✗ No data was collected${NC}"
    exit 1
fi
