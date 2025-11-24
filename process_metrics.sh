#!/bin/bash

# Metrics Processing Script
# Usage: ./process_metrics.sh <system_metrics_file> <job_log_file> <csv_output_file> <experiment_id> <slowstart_value> <start_time> <end_time> <total_time> <job_exit_code>

SYSTEM_METRICS_FILE="$1"
JOB_LOG_FILE="$2"
CSV_OUTPUT_FILE="$3"
EXPERIMENT_ID="$4"
SLOWSTART_VALUE="$5"
START_TIME="$6"
END_TIME="$7"
TOTAL_TIME="$8"
JOB_EXIT_CODE="$9"

# Default values if parameters are missing
SYSTEM_METRICS_FILE=${SYSTEM_METRICS_FILE:-"system_metrics.tmp"}
JOB_LOG_FILE=${JOB_LOG_FILE:-"job.log"}
CSV_OUTPUT_FILE=${CSV_OUTPUT_FILE:-"experiment_results.csv"}
EXPERIMENT_ID=${EXPERIMENT_ID:-"unknown"}
SLOWSTART_VALUE=${SLOWSTART_VALUE:-"0.0"}
START_TIME=${START_TIME:-$(date +%s)}
END_TIME=${END_TIME:-$(date +%s)}
TOTAL_TIME=${TOTAL_TIME:-0}
JOB_EXIT_CODE=${JOB_EXIT_CODE:-1}

echo "Processing metrics for experiment: $EXPERIMENT_ID"

# Function to calculate average from a column in metrics file
calculate_avg() {
    local file="$1"
    local column="$2"
    if [ -f "$file" ] && [ $(wc -l < "$file") -gt 1 ]; then
        tail -n +2 "$file" | awk -F, -v col="$column" '{sum+=$col; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}'
    else
        echo "0"
    fi
}

# Function to calculate maximum from a column in metrics file
calculate_max() {
    local file="$1"
    local column="$2"
    if [ -f "$file" ] && [ $(wc -l < "$file") -gt 1 ]; then
        tail -n +2 "$file" | awk -F, -v col="$column" '{if($col>max || NR==1) max=$col} END {printf "%.2f", max+0}'
    else
        echo "0"
    fi
}

# Function to extract Hadoop job statistics from log
extract_job_stats() {
    local log_file="$1"
    local bytes_read=0
    local bytes_written=0
    local map_tasks=0
    local reduce_tasks=0
    
    if [ -f "$log_file" ]; then
        # Extract bytes read and written from job counters
        bytes_read=$(grep -i "bytes.*read" "$log_file" | tail -1 | grep -o '[0-9,]\+' | tr -d ',' | head -1 || echo "0")
        bytes_written=$(grep -i "bytes.*written" "$log_file" | tail -1 | grep -o '[0-9,]\+' | tr -d ',' | head -1 || echo "0")
        
        # Extract number of map and reduce tasks
        map_tasks=$(grep -i "map.*100%" "$log_file" | wc -l || echo "0")
        reduce_tasks=$(grep -i "reduce.*100%" "$log_file" | wc -l || echo "0")
        
        # Alternative extraction methods for task counts
        if [ "$map_tasks" -eq 0 ]; then
            map_tasks=$(grep -o "map [0-9]*%" "$log_file" | wc -l || echo "0")
        fi
        
        if [ "$reduce_tasks" -eq 0 ]; then
            reduce_tasks=$(grep -o "reduce [0-9]*%" "$log_file" | wc -l || echo "0")
        fi
    fi
    
    echo "$bytes_read $bytes_written $map_tasks $reduce_tasks"
}

# Function to extract timing information from job log
extract_job_timings() {
    local log_file="$1"
    local map_start_time=""
    local map_end_time=""
    local reduce_start_time=""
    local shuffle_start_time=""
    
    if [ -f "$log_file" ]; then
        # Look for map and reduce progress indicators
        map_start_time=$(grep -m1 "map [0-9]*%" "$log_file" | head -1 | grep -o '^[0-9][0-9]/[0-9][0-9]/[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]' || echo "")
        reduce_start_time=$(grep -m1 "reduce [0-9]*%" "$log_file" | head -1 | grep -o '^[0-9][0-9]/[0-9][0-9]/[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]' || echo "")
        
        # Convert to timestamps if found
        if [ -n "$map_start_time" ]; then
            map_start_time=$(date -d "$map_start_time" +%s 2>/dev/null || echo "$START_TIME")
        else
            map_start_time="$START_TIME"
        fi
        
        if [ -n "$reduce_start_time" ]; then
            reduce_start_time=$(date -d "$reduce_start_time" +%s 2>/dev/null || echo "$START_TIME")
        else
            reduce_start_time="$START_TIME"
        fi
    fi
    
    echo "$map_start_time $reduce_start_time"
}

# Process system metrics if file exists
if [ -f "$SYSTEM_METRICS_FILE" ]; then
    echo "Processing system metrics from: $SYSTEM_METRICS_FILE"
    
    # Calculate averages and maximums
    avg_cpu=$(calculate_avg "$SYSTEM_METRICS_FILE" 2)
    max_cpu=$(calculate_max "$SYSTEM_METRICS_FILE" 2)
    avg_memory=$(calculate_avg "$SYSTEM_METRICS_FILE" 3)
    max_memory=$(calculate_max "$SYSTEM_METRICS_FILE" 3)
    avg_load=$(calculate_avg "$SYSTEM_METRICS_FILE" 6)
    max_load=$(calculate_max "$SYSTEM_METRICS_FILE" 6)
else
    echo "Warning: System metrics file not found: $SYSTEM_METRICS_FILE"
    avg_cpu=0
    max_cpu=0
    avg_memory=0
    max_memory=0
    avg_load=0
    max_load=0
fi

# Process job log if file exists
if [ -f "$JOB_LOG_FILE" ]; then
    echo "Processing job log from: $JOB_LOG_FILE"
    job_stats=$(extract_job_stats "$JOB_LOG_FILE")
    job_timings=$(extract_job_timings "$JOB_LOG_FILE")
else
    echo "Warning: Job log file not found: $JOB_LOG_FILE"
    job_stats="0 0 0 0"
    job_timings="$START_TIME $START_TIME"
fi

# Parse extracted data
bytes_read=$(echo $job_stats | awk '{print $1}')
bytes_written=$(echo $job_stats | awk '{print $2}')
map_tasks=$(echo $job_stats | awk '{print $3}')
reduce_tasks=$(echo $job_stats | awk '{print $4}')

# Determine job status
job_status="FAILED"
if [ "$JOB_EXIT_CODE" -eq 0 ]; then
    job_status="SUCCESS"
fi

# Format the CSV line
csv_line="${EXPERIMENT_ID},${SLOWSTART_VALUE},${START_TIME},${END_TIME},${TOTAL_TIME},${avg_cpu},${max_cpu},${avg_memory},${max_memory},${avg_load},${max_load},${bytes_read},${bytes_written},${map_tasks},${reduce_tasks},${job_status}"

# Append to CSV file
echo "$csv_line" >> "$CSV_OUTPUT_FILE"

echo "Metrics processing completed"
echo "Data appended to: $CSV_OUTPUT_FILE"

# Display processed metrics summary
echo ""
echo "=== Processed Metrics Summary ==="
echo "Experiment ID: $EXPERIMENT_ID"
echo "Slowstart Value: $SLOWSTART_VALUE"
echo "Total Time: ${TOTAL_TIME}s"
echo "Average CPU: ${avg_cpu}%"
echo "Max CPU: ${max_cpu}%"
echo "Average Memory: ${avg_memory}MB"
echo "Max Memory: ${max_memory}MB"
echo "Average Load: ${avg_load}"
echo "Max Load: ${max_load}"
echo "Bytes Read: ${bytes_read}"
echo "Bytes Written: ${bytes_written}"
echo "Map Tasks: ${map_tasks}"
echo "Reduce Tasks: ${reduce_tasks}"
