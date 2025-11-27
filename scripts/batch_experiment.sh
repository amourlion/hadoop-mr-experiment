#!/bin/bash

# Batch Experiment Script for MapReduce Slowstart Analysis
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

# Local Monitoring Configuration  
LOCAL_METRICS_DIR="system_metrics"

echo -e "${BLUE}=== Hadoop MapReduce Batch Experiment ===${NC}"
echo -e "${YELLOW}Input Path: ${INPUT_PATH}${NC}"
echo -e "${YELLOW}Output Base Path: ${OUTPUT_BASE_PATH}${NC}"
echo -e "${YELLOW}Experiment Base ID: ${EXPERIMENT_BASE_ID}${NC}"
echo -e "${YELLOW}Slowstart Values: ${SLOWSTART_VALUES[*]}${NC}"

# Create metrics directories
mkdir -p metrics
mkdir -p "${LOCAL_METRICS_DIR}"


# ============================================================================
# PHASE 1: Run Batch Experiments
# ============================================================================

echo -e "\n${BLUE}=== Phase 1: Batch Experiments ===${NC}"

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
# PHASE 2: Generate Reports and Summary
# ============================================================================

echo -e "\n${BLUE}=== Phase 2: Analysis and Reporting ===${NC}"

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


echo -e "\n${GREEN}All tasks completed successfully!${NC}"
