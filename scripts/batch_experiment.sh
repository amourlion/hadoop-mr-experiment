#!/bin/bash

# Batch Experiment Script for MapReduce Slowstart Analysis with Multi-Node Monitoring
# Usage: ./batch_experiment.sh [input_path] [output_base_path]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
INPUT_PATH=${1:-"/mr_input"}
OUTPUT_BASE_PATH=${2:-"/mr_output"}
SLOWSTART_VALUES=(0.1 0.3 0.5 0.7 1.0)
EXPERIMENT_BASE_ID="batch_$(date +%Y%m%d_%H%M%S)"
SUMMARY_CSV="metrics/batch_summary_${EXPERIMENT_BASE_ID}.csv"

# Multi-Node Monitoring Configuration
REMOTE_NODES=("hadoop002" "hadoop003")
REMOTE_MONITOR_DIR="~/monitoring"
MONITOR_INTERVAL=1
LOCAL_METRICS_DIR="other_node_monitoring"

# Arrays to track monitoring status
declare -A MONITORING_PIDS
declare -A MONITORING_FILES

echo -e "${BLUE}=== Hadoop MapReduce Batch Experiment with Multi-Node Monitoring ===${NC}"
echo -e "${YELLOW}Input Path: ${INPUT_PATH}${NC}"
echo -e "${YELLOW}Output Base Path: ${OUTPUT_BASE_PATH}${NC}"
echo -e "${YELLOW}Experiment Base ID: ${EXPERIMENT_BASE_ID}${NC}"
echo -e "${YELLOW}Slowstart Values: ${SLOWSTART_VALUES[*]}${NC}"
echo -e "${YELLOW}Remote Nodes: ${REMOTE_NODES[*]}${NC}"

# Create metrics directories
mkdir -p metrics
mkdir -p "${LOCAL_METRICS_DIR}"

# Function: Deploy monitoring script to remote node
deploy_monitoring_script() {
    local node=$1
    echo -e "${CYAN}  → Deploying monitoring script to ${node}...${NC}"
    
    # Create remote monitoring directory
    if ssh "${node}" "mkdir -p ${REMOTE_MONITOR_DIR}" 2>/dev/null; then
        # Copy monitoring script
        if scp scripts/collect_metrics.sh "${node}:${REMOTE_MONITOR_DIR}/" >/dev/null 2>&1; then
            # Make script executable
            ssh "${node}" "chmod +x ${REMOTE_MONITOR_DIR}/collect_metrics.sh" 2>/dev/null
            echo -e "${GREEN}  ✓ Successfully deployed to ${node}${NC}"
            return 0
        else
            echo -e "${RED}  ✗ Failed to copy script to ${node}${NC}"
            return 1
        fi
    else
        echo -e "${RED}  ✗ Failed to create directory on ${node}${NC}"
        return 1
    fi
}

# Function: Start remote monitoring
start_remote_monitoring() {
    local node=$1
    echo -e "${CYAN}  → Starting monitoring on ${node}...${NC}"
    
    # Start monitoring in background via SSH
    if ssh "${node}" "cd ${REMOTE_MONITOR_DIR} && nohup ./collect_metrics.sh ${node} ${MONITOR_INTERVAL} > /dev/null 2>&1 &" 2>/dev/null; then
        # Give it a moment to start
        sleep 2
        
        # Verify process is running
        local pid=$(ssh "${node}" "ps aux | grep 'collect_metrics.sh ${node}' | grep -v grep | awk '{print \$2}' | head -n 1" 2>/dev/null)
        
        if [ -n "$pid" ]; then
            MONITORING_PIDS["${node}"]=$pid
            echo -e "${GREEN}  ✓ Monitoring started on ${node} (PID: ${pid})${NC}"
            return 0
        else
            echo -e "${YELLOW}  ⚠ Could not verify monitoring process on ${node}${NC}"
            return 1
        fi
    else
        echo -e "${RED}  ✗ Failed to start monitoring on ${node}${NC}"
        return 1
    fi
}

# Function: Stop remote monitoring
stop_remote_monitoring() {
    local node=$1
    echo -e "${CYAN}  → Stopping monitoring on ${node}...${NC}"
    
    # Kill monitoring process
    if ssh "${node}" "pkill -f 'collect_metrics.sh ${node}'" 2>/dev/null; then
        echo -e "${GREEN}  ✓ Monitoring stopped on ${node}${NC}"
        return 0
    else
        echo -e "${YELLOW}  ⚠ No monitoring process found on ${node} (may have already stopped)${NC}"
        return 0
    fi
}

# Function: Collect monitoring data from remote node
collect_remote_data() {
    local node=$1
    echo -e "${CYAN}  → Collecting data from ${node}...${NC}"
    
    # Find the most recent CSV file for this node in system_metrics subdirectory
    local remote_file=$(ssh "${node}" "ls -t ${REMOTE_MONITOR_DIR}/system_metrics/${node}_*.csv 2>/dev/null | head -n 1" 2>/dev/null)
    
    if [ -n "$remote_file" ]; then
        local filename=$(basename "$remote_file")
        # Create node-specific directory and save file there
        mkdir -p "${LOCAL_METRICS_DIR}/${node}"
        local local_file="${LOCAL_METRICS_DIR}/${node}/${filename}"
        
        # Copy file from remote node
        if scp "${node}:${remote_file}" "${local_file}" >/dev/null 2>&1; then
            MONITORING_FILES["${node}"]="${local_file}"
            local filesize=$(du -h "${local_file}" | cut -f1)
            echo -e "${GREEN}  ✓ Collected ${filename} (${filesize}) from ${node}${NC}"
            return 0
        else
            echo -e "${RED}  ✗ Failed to copy data from ${node}${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}  ⚠ No monitoring data found on ${node}${NC}"
        return 1
    fi
}

# Function: Cleanup remote monitoring files (optional)
cleanup_remote_data() {
    local node=$1
    echo -e "${CYAN}  → Cleaning up remote data on ${node}...${NC}"
    
    if ssh "${node}" "rm -f ${REMOTE_MONITOR_DIR}/${node}_*.csv" 2>/dev/null; then
        echo -e "${GREEN}  ✓ Cleaned up remote data on ${node}${NC}"
    else
        echo -e "${YELLOW}  ⚠ Could not clean up remote data on ${node}${NC}"
    fi
}

# ============================================================================
# PHASE 1: Deploy and Start Multi-Node Monitoring
# ============================================================================

echo -e "\n${BLUE}=== Phase 1: Multi-Node Monitoring Setup ===${NC}"

deployed_nodes=0
started_nodes=0

for node in "${REMOTE_NODES[@]}"; do
    echo -e "\n${BLUE}Setting up monitoring on ${node}:${NC}"
    
    # Deploy monitoring script
    if deploy_monitoring_script "${node}"; then
        deployed_nodes=$((deployed_nodes + 1))
        
        # Start monitoring
        if start_remote_monitoring "${node}"; then
            started_nodes=$((started_nodes + 1))
        fi
    fi
done

echo -e "\n${BLUE}Monitoring Setup Summary:${NC}"
echo -e "  Deployed: ${deployed_nodes}/${#REMOTE_NODES[@]} nodes"
echo -e "  Started: ${started_nodes}/${#REMOTE_NODES[@]} nodes"

if [ $started_nodes -eq 0 ]; then
    echo -e "${YELLOW}⚠ Warning: No monitoring processes started. Experiments will continue anyway.${NC}"
else
    echo -e "${GREEN}✓ Monitoring is active on ${started_nodes} node(s)${NC}"
fi

# ============================================================================
# PHASE 2: Run Batch Experiments
# ============================================================================

echo -e "\n${BLUE}=== Phase 2: Batch Experiments ===${NC}"

# Initialize summary CSV
echo "experiment_id,slowstart_value,start_time,end_time,total_time_sec,avg_cpu_percent,max_cpu_percent,avg_memory_mb,max_memory_mb,avg_load,max_load,bytes_read,bytes_written,map_tasks,reduce_tasks,job_status" > "${SUMMARY_CSV}"

echo -e "${GREEN}Starting batch experiments...${NC}"

# Track overall statistics
total_experiments=${#SLOWSTART_VALUES[@]}
successful_experiments=0
failed_experiments=0
start_batch_time=$(date +%s)

# Run experiments for each slowstart value
for i in "${!SLOWSTART_VALUES[@]}"; do
    slowstart_value=${SLOWSTART_VALUES[$i]}
    experiment_id="${EXPERIMENT_BASE_ID}_exp$(printf "%02d" $((i+1)))"
    output_path="${OUTPUT_BASE_PATH}_slowstart_${slowstart_value//./}"
    
    echo -e "\n${BLUE}--- Experiment $((i+1))/${total_experiments}: slowstart=${slowstart_value} ---${NC}"
    
    # Clean output directory
    echo -e "${YELLOW}Cleaning output directory: ${output_path}${NC}"
    hdfs dfs -rm -r -f "${output_path}" 2>/dev/null || true
    
    # Run single experiment
    start_exp_time=$(date +%s)
    if "$(dirname "$0")/monitor_job.sh" "${slowstart_value}" "${INPUT_PATH}" "${output_path}" "${experiment_id}"; then
        end_exp_time=$(date +%s)
        exp_duration=$((end_exp_time - start_exp_time))
        successful_experiments=$((successful_experiments + 1))
        echo -e "${GREEN}✓ Experiment $((i+1)) completed successfully in ${exp_duration}s${NC}"
    else
        end_exp_time=$(date +%s)
        exp_duration=$((end_exp_time - start_exp_time))
        failed_experiments=$((failed_experiments + 1))
        echo -e "${RED}✗ Experiment $((i+1)) failed after ${exp_duration}s${NC}"
    fi
    
    # Copy individual experiment results to summary
    individual_csv="metrics/experiment_${experiment_id}_slowstart_${slowstart_value}.csv"
    if [ -f "${individual_csv}" ] && [ $(wc -l < "${individual_csv}") -gt 1 ]; then
        tail -n +2 "${individual_csv}" >> "${SUMMARY_CSV}"
    fi
    
    # Short delay between experiments
    if [ $((i+1)) -lt ${total_experiments} ]; then
        echo -e "${YELLOW}Waiting 10 seconds before next experiment...${NC}"
        sleep 10
    fi
done

end_batch_time=$(date +%s)
total_batch_time=$((end_batch_time - start_batch_time))

# ============================================================================
# PHASE 3: Stop Monitoring and Collect Data
# ============================================================================

echo -e "\n${BLUE}=== Phase 3: Stop Monitoring and Collect Data ===${NC}"

stopped_nodes=0
collected_nodes=0

for node in "${REMOTE_NODES[@]}"; do
    echo -e "\n${BLUE}Processing ${node}:${NC}"
    
    # Stop monitoring
    if stop_remote_monitoring "${node}"; then
        stopped_nodes=$((stopped_nodes + 1))
    fi
    
    # Wait a moment for final data to be written
    sleep 2
    
    # Collect data
    if collect_remote_data "${node}"; then
        collected_nodes=$((collected_nodes + 1))
    fi
done

echo -e "\n${BLUE}Data Collection Summary:${NC}"
echo -e "  Stopped: ${stopped_nodes}/${#REMOTE_NODES[@]} nodes"
echo -e "  Collected: ${collected_nodes}/${#REMOTE_NODES[@]} nodes"

if [ $collected_nodes -gt 0 ]; then
    echo -e "\n${GREEN}✓ Successfully collected monitoring data from ${collected_nodes} node(s):${NC}"
    for node in "${!MONITORING_FILES[@]}"; do
        echo -e "  ${node}: ${MONITORING_FILES[$node]}"
    done
fi

# ============================================================================
# PHASE 4: Generate Reports and Summary
# ============================================================================

echo -e "\n${BLUE}=== Phase 4: Analysis and Reporting ===${NC}"

echo -e "\n${GREEN}=== Batch Experiment Summary ===${NC}"
echo -e "Total Experiments: ${total_experiments}"
echo -e "Successful: ${GREEN}${successful_experiments}${NC}"
echo -e "Failed: ${RED}${failed_experiments}${NC}"
echo -e "Total Batch Time: ${total_batch_time} seconds"
echo -e "Summary CSV: ${SUMMARY_CSV}"

# Generate analysis report
echo -e "\n${BLUE}Generating analysis report...${NC}"
"$(dirname "$0")/generate_report.sh" "${SUMMARY_CSV}" "metrics/analysis_report_${EXPERIMENT_BASE_ID}.txt"

echo -e "\n${GREEN}Batch experiments completed!${NC}"

# Display quick analysis if summary CSV has data
if [ -f "${SUMMARY_CSV}" ] && [ $(wc -l < "${SUMMARY_CSV}") -gt 1 ]; then
    echo -e "\n${BLUE}=== Quick Performance Analysis ===${NC}"
    echo "Slowstart | Total Time | Avg CPU | Max Memory | Status"
    echo "----------|------------|---------|------------|--------"
    tail -n +2 "${SUMMARY_CSV}" | while IFS=',' read -r exp_id slowstart start end total avg_cpu max_cpu avg_mem max_mem avg_load max_load bytes_r bytes_w maps reduces status; do
        printf "%-9s | %-10s | %-7s | %-10s | %s\n" "$slowstart" "${total}s" "${avg_cpu}%" "${max_mem}MB" "$status"
    done
fi

# Display collected monitoring files
if [ ${#MONITORING_FILES[@]} -gt 0 ]; then
    echo -e "\n${BLUE}=== Collected Monitoring Data ===${NC}"
    echo "Node        | File Location"
    echo "------------|--------------------------------------------"
    for node in "${!MONITORING_FILES[@]}"; do
        printf "%-11s | %s\n" "$node" "${MONITORING_FILES[$node]}"
    done
fi

echo -e "\n${GREEN}All tasks completed successfully!${NC}"
