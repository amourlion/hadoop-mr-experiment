#!/bin/bash

# System Metrics Collection Script for Multi-Node Hadoop Cluster
# Usage: ./collect_metrics.sh <node_name> [interval]
# This script runs in background and collects system metrics every second

NODE_NAME=${1}
INTERVAL=${2:-1}  # Collection interval in seconds

# Validate node name parameter
if [ -z "$NODE_NAME" ]; then
    echo "Error: Node name is required as the first parameter"
    echo "Usage: $0 <node_name> [interval_seconds]"
    echo "Example: $0 master 1"
    echo "         $0 worker01 2"
    exit 1
fi

# Generate output filename with timestamp to avoid overwriting
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="system_metrics/${NODE_NAME}_${TIMESTAMP}.csv"

# Create system_metrics directory if it doesn't exist
mkdir -p system_metrics

# Function to get CPU usage percentage
get_cpu_usage() {
    # Use top to get current CPU usage, excluding idle
    top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}'
}

# Function to get memory usage in MB
get_memory_usage() {
    free -m | awk 'NR==2{printf "%.0f %.0f %.1f", $3,$2,$3*100/$2}'
}

# Function to get load average
get_load_average() {
    uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//'
}

# Function to get disk I/O stats
get_disk_io() {
    if command -v iostat &> /dev/null; then
        iostat -d 1 1 | tail -n +4 | awk 'NR>1 && NF>1 {reads+=$4; writes+=$5} END {printf "%.0f %.0f", reads, writes}'
    else
        echo "0 0"
    fi
}

# Function to get network I/O stats
get_network_io() {
    if [ -f /proc/net/dev ]; then
        awk '/:/ {
            gsub(/:/," ");
            rx += $3; tx += $11
        } END {
            printf "%.0f %.0f", rx/1024/1024, tx/1024/1024
        }' /proc/net/dev
    else
        echo "0 0"
    fi
}

# Function to get Java process specific metrics
get_java_metrics() {
    local hadoop_pids=$(ps aux | grep -E "(hadoop|yarn)" | grep -v grep | grep -E "(jar|Main)" | awk '{print $2}' | tr '\n' ' ')
    
    if [ -n "$hadoop_pids" ]; then
        local total_cpu=0
        local total_mem=0
        local process_count=0
        
        for pid in $hadoop_pids; do
            if [ -d "/proc/$pid" ]; then
                local cpu_mem=$(ps -p $pid -o %cpu,%mem --no-headers 2>/dev/null)
                if [ -n "$cpu_mem" ]; then
                    local cpu=$(echo $cpu_mem | awk '{print $1}')
                    local mem=$(echo $cpu_mem | awk '{print $2}')
                    total_cpu=$(echo "$total_cpu + $cpu" | bc -l 2>/dev/null || echo "$total_cpu")
                    total_mem=$(echo "$total_mem + $mem" | bc -l 2>/dev/null || echo "$total_mem")
                    process_count=$((process_count + 1))
                fi
            fi
        done
        
        echo "$total_cpu $total_mem $process_count"
    else
        echo "0 0 0"
    fi
}

# Initialize output file with header (added node_name column for multi-node analysis)
echo "node_name,timestamp,cpu_percent,memory_used_mb,memory_total_mb,memory_percent,load_avg,disk_reads,disk_writes,network_rx_mb,network_tx_mb,java_cpu_percent,java_memory_percent,java_processes" > "$OUTPUT_FILE"

echo "System metrics collection started. Output: $OUTPUT_FILE"
echo "Collection interval: ${INTERVAL} second(s)"
echo "Press Ctrl+C to stop collection"

# Main collection loop
while true; do
    timestamp=$(date +%s)
    
    # Get system metrics
    cpu_usage=$(get_cpu_usage)
    memory_info=$(get_memory_usage)
    load_avg=$(get_load_average)
    disk_io=$(get_disk_io)
    network_io=$(get_network_io)
    java_metrics=$(get_java_metrics)
    
    # Parse memory info
    memory_used=$(echo $memory_info | awk '{print $1}')
    memory_total=$(echo $memory_info | awk '{print $2}')
    memory_percent=$(echo $memory_info | awk '{print $3}')
    
    # Parse disk I/O
    disk_reads=$(echo $disk_io | awk '{print $1}')
    disk_writes=$(echo $disk_io | awk '{print $2}')
    
    # Parse network I/O
    network_rx=$(echo $network_io | awk '{print $1}')
    network_tx=$(echo $network_io | awk '{print $2}')
    
    # Parse Java metrics
    java_cpu=$(echo $java_metrics | awk '{print $1}')
    java_mem=$(echo $java_metrics | awk '{print $2}')
    java_procs=$(echo $java_metrics | awk '{print $3}')
    
    # Write metrics to file (include node_name as first column)
    echo "${NODE_NAME},${timestamp},${cpu_usage},${memory_used},${memory_total},${memory_percent},${load_avg},${disk_reads},${disk_writes},${network_rx},${network_tx},${java_cpu},${java_mem},${java_procs}" >> "$OUTPUT_FILE"
    
    sleep $INTERVAL
done
