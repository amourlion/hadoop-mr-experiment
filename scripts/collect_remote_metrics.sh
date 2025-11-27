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

# =========================
# Configuration
# =========================

# 远端节点
REMOTE_NODES=("hadoop002" "hadoop003")

# 远端 system_metrics 目录（CSV）
REMOTE_SYSTEM_DIR="~/monitoring/system_metrics"

# 远端 mapreduce_metrics 目录（TXT 文件放这里）
REMOTE_MR_DIR="~/mapreduce_metrics"

# 本地存放“远端收集结果”的目录（相对当前目录）
LOCAL_BASE_DIR="other_node_monitoring"

echo -e "${BLUE}=== Collect Remote Node Monitoring Data ===${NC}"
echo -e "${YELLOW}Remote Nodes: ${REMOTE_NODES[*]}${NC}"
echo -e "${YELLOW}Remote system_metrics: ${REMOTE_SYSTEM_DIR}${NC}"
echo -e "${YELLOW}Remote mapreduce_metrics (txt): ${REMOTE_MR_DIR}${NC}"
echo -e "${YELLOW}Local Base Directory: ${LOCAL_BASE_DIR}${NC}"

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

# -------------------------
# collect system_metrics
# -------------------------
collect_system_metrics() {
    local node=$1
    local node_dir="${LOCAL_BASE_DIR}/${node}/system_metrics"

    echo -e "\n${BLUE}=== ${node} | system_metrics ===${NC}"

    mkdir -p "${node_dir}"

    if ! ssh "${node}" "test -d ${REMOTE_SYSTEM_DIR}" 2>/dev/null; then
        echo -e "${YELLOW}  ⚠ No system_metrics dir on ${node}${NC}"
        return 1
    fi

    local count
    count=$(ssh "${node}" "ls ${REMOTE_SYSTEM_DIR}/*.csv 2>/dev/null | wc -l" || echo "0")

    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}  ⚠ No CSV found on ${node}${NC}"
        return 1
    fi

    echo -e "${CYAN}  → Copying CSV from ${node}${NC}"
    if scp "${node}:${REMOTE_SYSTEM_DIR}/*.csv" "${node_dir}/" 2>/dev/null; then
        local copied
        copied=$(ls "${node_dir}"/*.csv 2>/dev/null | wc -l)
        local size
        size=$(du -sh "${node_dir}" | cut -f1)
        echo -e "${GREEN}  ✓ ${copied} csv (${size})${NC}"
        total_files=$((total_files + copied))
        return 0
    else
        echo -e "${RED}  ✗ Failed to copy CSV from ${node}${NC}"
        return 1
    fi
}

# -------------------------
# collect mapreduce_metrics (*.txt)
# -------------------------
collect_mr_metrics() {
    local node=$1
    local node_dir="${LOCAL_BASE_DIR}/${node}/mapreduce_metrics"

    echo -e "\n${BLUE}=== ${node} | mapreduce_metrics ===${NC}"

    mkdir -p "${node_dir}"

    if ! ssh "${node}" "test -d ${REMOTE_MR_DIR}" 2>/dev/null; then
        echo -e "${YELLOW}  ⚠ No mapreduce_metrics dir on ${node}${NC}"
        return 1
    fi

    local count
    count=$(ssh "${node}" "ls ${REMOTE_MR_DIR}/*.txt 2>/dev/null | wc -l" || echo "0")

    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}  ⚠ No txt found on ${node}${NC}"
        return 1
    fi

    echo -e "${CYAN}  → Copying TXT from ${node}${NC}"
    if scp "${node}:${REMOTE_MR_DIR}/*.txt" "${node_dir}/" 2>/dev/null; then
        local copied
        copied=$(ls "${node_dir}"/*.txt 2>/dev/null | wc -l)
        local size
        size=$(du -sh "${node_dir}" | cut -f1)
        echo -e "${GREEN}  ✓ ${copied} txt (${size})${NC}"
        total_files=$((total_files + copied))
        return 0
    else
        echo -e "${RED}  ✗ Failed to copy TXT from ${node}${NC}"
        return 1
    fi
}

# ============
# Main loop
# ============
echo -e "\n${BLUE}=== Starting Data Collection ===${NC}"

for node in "${REMOTE_NODES[@]}"; do
    ok=0

    collect_system_metrics "${node}" && ok=1
    collect_mr_metrics "${node}" && ok=1

    if [ $ok -eq 1 ]; then
        successful_nodes=$((successful_nodes + 1))
    else
        failed_nodes=$((failed_nodes + 1))
    fi
done

# Calculate total size
if [ -d "${LOCAL_BASE_DIR}" ]; then
    total_size=$(du -sh "${LOCAL_BASE_DIR}" | cut -f1)
else
    total_size="0"
fi

# ============
# Summary
# ============
echo -e "\n${BLUE}=== Collection Summary ===${NC}"
echo -e "Total Nodes: ${total_nodes}"
echo -e "Successful: ${GREEN}${successful_nodes}${NC}"
echo -e "Failed: ${RED}${failed_nodes}${NC}"
echo -e "Total Files Collected: ${total_files}"
echo -e "Total Size: ${total_size}"

# List collected files
if [ "${successful_nodes}" -gt 0 ]; then
    echo -e "\n${BLUE}=== Collected Files ===${NC}"

    for node in "${REMOTE_NODES[@]}"; do
        base="${LOCAL_BASE_DIR}/${node}"

        if [ -d "$base" ]; then
            echo -e "\n${CYAN}${node}:${NC}"
            find "$base" -type f \( -name "*.csv" -o -name "*.txt" \) \
                -exec ls -lh {} \; | awk '{printf "  %s  %s\n", $5, $9}'
        fi
    done

    echo -e "\n${GREEN}✓ All data collected successfully!${NC}"
    echo -e "${YELLOW}Data location: ${LOCAL_BASE_DIR}/${NC}"
else
    echo -e "\n${RED}✗ No data was collected${NC}"
    exit 1
fi