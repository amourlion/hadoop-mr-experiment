#!/bin/bash

# Hadoop MapReduce Job Monitor Script
# Usage: ./monitor_job.sh <slowstart_value> <input_path> <output_path> [experiment_id]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
SLOWSTART_VALUE=${1:-0.3}
INPUT_PATH=${2:-/mr_input}
OUTPUT_PATH=${3:-/mr_output}
EXPERIMENT_ID=${4:-$(date +%Y%m%d_%H%M%S)}

# Output files
METRICS_DIR="metrics"
CSV_FILE="${METRICS_DIR}/experiment_${EXPERIMENT_ID}_slowstart_${SLOWSTART_VALUE}.csv"
SYSTEM_METRICS_FILE="${METRICS_DIR}/system_metrics_${EXPERIMENT_ID}_slowstart_${SLOWSTART_VALUE}.csv"
JOB_LOG_FILE="${METRICS_DIR}/job_${EXPERIMENT_ID}.log"

echo -e "${BLUE}=== Hadoop MapReduce Performance Monitor ===${NC}"
echo -e "${YELLOW}Experiment ID: ${EXPERIMENT_ID}${NC}"
echo -e "${YELLOW}Slowstart Value: ${SLOWSTART_VALUE}${NC}"
echo -e "${YELLOW}Input Path: ${INPUT_PATH}${NC}"
echo -e "${YELLOW}Output Path: ${OUTPUT_PATH}${NC}"

# Create metrics directory
mkdir -p ${METRICS_DIR}

# Initialize CSV header if file doesn't exist
if [ ! -f "${CSV_FILE}" ]; then
    echo "experiment_id,slowstart_value,start_time,end_time,total_time_sec,avg_cpu_percent,max_cpu_percent,avg_memory_mb,max_memory_mb,avg_load,max_load,bytes_read,bytes_written,map_tasks,reduce_tasks,job_status" > "${CSV_FILE}"
fi

# Function to cleanup background processes
cleanup() {
    echo -e "\n${YELLOW}Cleaning up background processes...${NC}"
    if [ ! -z "${MONITOR_PID}" ]; then
        kill ${MONITOR_PID} 2>/dev/null || true
    fi
    wait 2>/dev/null || true
}
trap cleanup EXIT

# Function to get Java process PID for Hadoop
get_hadoop_pid() {
    # Try to find the main Hadoop job process
    ps aux | grep -E "(hadoop|yarn)" | grep -v grep | grep -E "(jar|Main)" | head -1 | awk '{print $2}' 2>/dev/null || echo ""
}

# Start system monitoring in background
echo -e "${BLUE}Starting system resource monitoring...${NC}"
# Extract node name from hostname or use default
NODE_NAME=${NODE_NAME:-$(hostname -s)}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
"$(dirname "$0")/collect_metrics.sh" "${NODE_NAME}" &
MONITOR_PID=$!

# Update system metrics file path to match the new naming convention
SYSTEM_METRICS_FILE="system_metrics/${NODE_NAME}_${TIMESTAMP}.csv"

# Update slowstart value in Main.java
echo -e "${BLUE}Updating slowstart value to ${SLOWSTART_VALUE}...${NC}"
sed -i "s/mapreduce\.job\.reduce\.slowstart\.completedmaps\", [0-9.]*f/mapreduce.job.reduce.slowstart.completedmaps\", ${SLOWSTART_VALUE}f/" src/main/java/edu/example/mapreduce/Main.java

# Compile the project
echo -e "${BLUE}Compiling project...${NC}"
mvn clean package -DskipTests -q

# Clean output directory if exists
echo -e "${BLUE}Cleaning output directory...${NC}"
hdfs dfs -rm -r -f "${OUTPUT_PATH}" 2>/dev/null || true

# Record start time
START_TIME=$(date +%s)
START_TIME_HUMAN=$(date)

echo -e "${GREEN}Starting Hadoop job at ${START_TIME_HUMAN}...${NC}"

# Run Hadoop job and capture output
hadoop jar target/reduce-startup-1.0-SNAPSHOT-jar-with-dependencies.jar "${INPUT_PATH}" "${OUTPUT_PATH}" 2>&1 | tee "${JOB_LOG_FILE}"
JOB_EXIT_CODE=${PIPESTATUS[0]}

# Record end time
END_TIME=$(date +%s)
END_TIME_HUMAN=$(date)
TOTAL_TIME=$((END_TIME - START_TIME))

echo -e "${GREEN}Job completed at ${END_TIME_HUMAN}${NC}"
echo -e "${GREEN}Total execution time: ${TOTAL_TIME} seconds${NC}"

# Stop system monitoring
if [ ! -z "${MONITOR_PID}" ]; then
    kill ${MONITOR_PID} 2>/dev/null || true
    wait ${MONITOR_PID} 2>/dev/null || true
fi

# Process collected metrics
echo -e "${BLUE}Processing collected metrics...${NC}"
"$(dirname "$0")/process_metrics.sh" "${SYSTEM_METRICS_FILE}" "${JOB_LOG_FILE}" "${CSV_FILE}" "${EXPERIMENT_ID}" "${SLOWSTART_VALUE}" "${START_TIME}" "${END_TIME}" "${TOTAL_TIME}" "${JOB_EXIT_CODE}"

# Extract Map/Reduce timeline data if job succeeded
if [ ${JOB_EXIT_CODE} -eq 0 ]; then
    echo -e "${BLUE}Extracting Map/Reduce timeline...${NC}"
    
    # Extract application ID from job log
    APPLICATION_ID=$(grep -oP "Submitted application application_\K\d+_\d+" "${JOB_LOG_FILE}" | head -1)
    if [ ! -z "${APPLICATION_ID}" ]; then
        APPLICATION_ID="application_${APPLICATION_ID}"
        "$(dirname "$0")/extract_timeline.sh" "${APPLICATION_ID}" "${SLOWSTART_VALUE}" "${EXPERIMENT_ID}" 2>/dev/null || {
            echo -e "${YELLOW}Warning: Timeline extraction failed. Make sure JobHistory Server is running.${NC}"
            echo -e "${YELLOW}To start: mapred --daemon start historyserver${NC}"
        }
    else
        echo -e "${YELLOW}Warning: Could not extract application ID from job log${NC}"
    fi
fi

# Display summary
echo -e "\n${GREEN}=== Experiment Summary ===${NC}"
echo -e "Experiment ID: ${EXPERIMENT_ID}"
echo -e "Slowstart Value: ${SLOWSTART_VALUE}"
echo -e "Total Time: ${TOTAL_TIME} seconds"
echo -e "Job Status: $([ ${JOB_EXIT_CODE} -eq 0 ] && echo 'SUCCESS' || echo 'FAILED')"
echo -e "Experiment results saved to: ${CSV_FILE}"
echo -e "System metrics saved to: ${SYSTEM_METRICS_FILE}"

# Clean up temporary files (keep system metrics CSV)
rm -f "${JOB_LOG_FILE}" 2>/dev/null || true
