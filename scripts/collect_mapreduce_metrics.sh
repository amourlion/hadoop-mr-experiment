#!/bin/bash

# MapReduce Process Metrics Collection Script
# Usage: ./collect_mapreduce_metrics.sh <node_name> [scan_interval]
# This script runs in background and monitors MRAppMaster and YarnChild processes

NODE_NAME=${1}
SCAN_INTERVAL=${2:-5}  # Scan interval when no processes found (seconds)
MONITOR_INTERVAL=1     # Monitoring interval when processes are active (seconds)

# Validate node name parameter
if [ -z "$NODE_NAME" ]; then
    echo "Error: Node name is required as the first parameter"
    echo "Usage: $0 <node_name> [scan_interval_seconds]"
    echo "Example: $0 hadoop001 5"
    echo "         $0 hadoop002 3"
    exit 1
fi

# Check if pidstat is available
if ! command -v pidstat &> /dev/null; then
    echo "Error: pidstat not found. Please install sysstat package:"
    echo "  CentOS/RHEL: sudo yum install sysstat"
    echo "  Ubuntu/Debian: sudo apt-get install sysstat"
    exit 1
fi

# Generate output directory and filenames
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_DIR="mapreduce_metrics"
MRAPP_OUTPUT="${OUTPUT_DIR}/${NODE_NAME}_mrapp_${TIMESTAMP}.txt"
YARNCHILD_OUTPUT="${OUTPUT_DIR}/${NODE_NAME}_yarnchild_${TIMESTAMP}.txt"
LOG_FILE="${OUTPUT_DIR}/${NODE_NAME}_process_discovery_${TIMESTAMP}.log"

# Create output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Arrays to track monitoring processes
declare -A MONITORING_PIDS
declare -A ACTIVE_PROCESSES

# Function to log with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

# Function to discover MapReduce processes
discover_processes() {
    local mrapp_pids=$(jps | grep MRAppMaster | awk '{print $1}')
    local yarn_pids=$(jps | grep YarnChild | awk '{print $1}')
    
    echo "$mrapp_pids|$yarn_pids"
}

# Function to start monitoring MRAppMaster
start_mrapp_monitoring() {
    local pids="$1"
    if [ -n "$pids" ] && [ -z "${MONITORING_PIDS[mrapp]}" ]; then
        # Convert newline-separated PIDs to comma-separated for pidstat
        local pid_list=$(echo "$pids" | tr '\n' ',' | sed 's/,$//')
        log_message "Starting MRAppMaster monitoring for PIDs: $pid_list"
        
        # Start pidstat monitoring for MRAppMaster
        pidstat -u -r -d -p "$pid_list" $MONITOR_INTERVAL > "$MRAPP_OUTPUT" &
        MONITORING_PIDS[mrapp]=$!
        
        # Add header to output file
        echo "# MRAppMaster Process Monitoring - Node: $NODE_NAME" > "${MRAPP_OUTPUT}.header"
        echo "# Started at: $(date)" >> "${MRAPP_OUTPUT}.header"
        echo "# PIDs: $pid_list" >> "${MRAPP_OUTPUT}.header"
    fi
}

# Function to start monitoring YarnChild processes
start_yarnchild_monitoring() {
    local pids="$1"
    if [ -n "$pids" ] && [ -z "${MONITORING_PIDS[yarnchild]}" ]; then
        log_message "Starting YarnChild monitoring for PIDs: $pids"
        
        # Convert newline-separated PIDs to comma-separated
        local pid_list=$(echo "$pids" | tr '\n' ',' | sed 's/,$//')
        
        # Start pidstat monitoring for YarnChild processes
        pidstat -u -r -d -p "$pid_list" $MONITOR_INTERVAL > "$YARNCHILD_OUTPUT" &
        MONITORING_PIDS[yarnchild]=$!
        
        # Add header to output file
        echo "# YarnChild Process Monitoring - Node: $NODE_NAME" > "${YARNCHILD_OUTPUT}.header"
        echo "# Started at: $(date)" >> "${YARNCHILD_OUTPUT}.header"
        echo "# PIDs: $pid_list" >> "${YARNCHILD_OUTPUT}.header"
    fi
}

# Function to convert pidstat output to CSV
convert_to_csv() {
    local txt_file="$1"
    local csv_file="${txt_file%.txt}.csv"
    
    if [ -f "$txt_file" ] && [ -s "$txt_file" ]; then
        log_message "Converting $txt_file to CSV format"
        if python3 "$(dirname "$0")/convert_pidstat_to_csv.py" "$txt_file" "$csv_file" 2>/dev/null; then
            log_message "CSV conversion successful: $csv_file"
        else
            log_message "CSV conversion failed for $txt_file"
        fi
    fi
}

# Function to stop monitoring process
stop_monitoring() {
    local process_type="$1"
    local pid="${MONITORING_PIDS[$process_type]}"
    
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        log_message "Stopping $process_type monitoring (PID: $pid)"
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
        unset MONITORING_PIDS[$process_type]
        
        # Convert output to CSV after monitoring stops
        if [ "$process_type" = "mrapp" ]; then
            convert_to_csv "$MRAPP_OUTPUT"
        elif [ "$process_type" = "yarnchild" ]; then
            convert_to_csv "$YARNCHILD_OUTPUT"
        fi
    fi
}

# Function to check if processes are still running
check_processes_alive() {
    local process_type="$1"
    local pids="$2"
    
    local alive_count=0
    for pid in $pids; do
        if kill -0 "$pid" 2>/dev/null; then
            alive_count=$((alive_count + 1))
        fi
    done
    
    if [ $alive_count -eq 0 ]; then
        log_message "All $process_type processes have ended"
        stop_monitoring "$process_type"
        return 1
    fi
    
    return 0
}

# Function to cleanup on exit
cleanup() {
    log_message "Shutting down MapReduce monitoring..."
    
    # Stop all monitoring processes
    for process_type in "${!MONITORING_PIDS[@]}"; do
        stop_monitoring "$process_type"
    done
    
    log_message "MapReduce monitoring stopped"
    exit 0
}

# Set up signal handlers
trap cleanup SIGINT SIGTERM

# Main monitoring loop
log_message "MapReduce process monitoring started on $NODE_NAME"
log_message "Scan interval: ${SCAN_INTERVAL}s, Monitor interval: ${MONITOR_INTERVAL}s"

while true; do
    # Discover current MapReduce processes
    process_info=$(discover_processes)
    mrapp_pids=$(echo "$process_info" | cut -d'|' -f1)
    yarn_pids=$(echo "$process_info" | cut -d'|' -f2)
    
    # Check if we have any MapReduce processes
    if [ -z "$mrapp_pids" ] && [ -z "$yarn_pids" ]; then
        # No processes found, clean up any existing monitoring
        if [ ${#MONITORING_PIDS[@]} -gt 0 ]; then
            log_message "No MapReduce processes found, stopping monitoring"
            for process_type in "${!MONITORING_PIDS[@]}"; do
                stop_monitoring "$process_type"
            done
        fi
        
        # Sleep for scan interval
        sleep $SCAN_INTERVAL
        continue
    fi
    
    # Handle MRAppMaster processes
    if [ -n "$mrapp_pids" ]; then
        if [ -z "${MONITORING_PIDS[mrapp]}" ]; then
            start_mrapp_monitoring "$mrapp_pids"
        else
            # Check if monitored processes are still alive
            if ! check_processes_alive "MRAppMaster" "$mrapp_pids"; then
                # Restart monitoring with new PIDs if any
                if [ -n "$mrapp_pids" ]; then
                    start_mrapp_monitoring "$mrapp_pids"
                fi
            fi
        fi
    else
        # No MRAppMaster processes, stop monitoring if active
        if [ -n "${MONITORING_PIDS[mrapp]}" ]; then
            stop_monitoring "mrapp"
        fi
    fi
    
    # Handle YarnChild processes
    if [ -n "$yarn_pids" ]; then
        if [ -z "${MONITORING_PIDS[yarnchild]}" ]; then
            start_yarnchild_monitoring "$yarn_pids"
        else
            # Check if monitored processes are still alive
            if ! check_processes_alive "YarnChild" "$yarn_pids"; then
                # Restart monitoring with new PIDs if any
                if [ -n "$yarn_pids" ]; then
                    start_yarnchild_monitoring "$yarn_pids"
                fi
            fi
        fi
    else
        # No YarnChild processes, stop monitoring if active
        if [ -n "${MONITORING_PIDS[yarnchild]}" ]; then
            stop_monitoring "yarnchild"
        fi
    fi
    
    # Sleep for monitoring interval when processes are active
    sleep $MONITOR_INTERVAL
done
