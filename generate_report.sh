#!/bin/bash

# Analysis Report Generation Script
# Usage: ./generate_report.sh <csv_file> <output_report_file>

CSV_FILE=${1:-"metrics/batch_summary.csv"}
REPORT_FILE=${2:-"metrics/analysis_report.txt"}

# Check if CSV file exists
if [ ! -f "$CSV_FILE" ]; then
    echo "Error: CSV file not found: $CSV_FILE"
    exit 1
fi

# Check if CSV has data
if [ $(wc -l < "$CSV_FILE") -le 1 ]; then
    echo "Error: CSV file has no data rows: $CSV_FILE"
    exit 1
fi

echo "Generating analysis report from: $CSV_FILE"
echo "Output report: $REPORT_FILE"

# Create report file
cat > "$REPORT_FILE" << EOF
================================================================================
HADOOP MAPREDUCE SLOWSTART PERFORMANCE ANALYSIS REPORT
================================================================================
Generated: $(date)
Source Data: $CSV_FILE

EOF

# Function to calculate statistics
calculate_stats() {
    local column=$1
    local label=$2
    echo "--- $label Statistics ---" >> "$REPORT_FILE"
    
    # Calculate min, max, average using awk
    tail -n +2 "$CSV_FILE" | awk -F',' -v col=$column '
    BEGIN { min=999999; max=0; sum=0; count=0 }
    {
        if ($col != "" && $col != "0") {
            if ($col < min) min = $col
            if ($col > max) max = $col
            sum += $col
            count++
        }
    }
    END {
        if (count > 0) {
            printf "Minimum: %.2f\n", min
            printf "Maximum: %.2f\n", max
            printf "Average: %.2f\n", sum/count
        } else {
            print "No valid data"
        }
    }' >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
}

# Performance comparison table
echo "PERFORMANCE COMPARISON BY SLOWSTART VALUE" >> "$REPORT_FILE"
echo "==========================================" >> "$REPORT_FILE"
printf "%-10s | %-12s | %-10s | %-12s | %-10s | %-8s\n" "Slowstart" "Total Time(s)" "Avg CPU(%)" "Max Memory(MB)" "Avg Load" "Status" >> "$REPORT_FILE"
echo "-----------|--------------|------------|--------------|------------|----------" >> "$REPORT_FILE"

tail -n +2 "$CSV_FILE" | sort -t',' -k2 -n | while IFS=',' read -r exp_id slowstart start end total avg_cpu max_cpu avg_mem max_mem avg_load max_load bytes_r bytes_w maps reduces status; do
    printf "%-10s | %-12s | %-10s | %-12s | %-10s | %-8s\n" "$slowstart" "$total" "$avg_cpu" "$max_mem" "$avg_load" "$status" >> "$REPORT_FILE"
done

echo "" >> "$REPORT_FILE"

# Detailed statistics
calculate_stats 5 "Total Execution Time (seconds)"
calculate_stats 6 "Average CPU Usage (%)"
calculate_stats 8 "Maximum Memory Usage (MB)"
calculate_stats 9 "Average System Load"

# Find best performing configuration
echo "PERFORMANCE OPTIMIZATION ANALYSIS" >> "$REPORT_FILE"
echo "=================================" >> "$REPORT_FILE"

# Best execution time
best_time_line=$(tail -n +2 "$CSV_FILE" | sort -t',' -k5 -n | head -1)
if [ -n "$best_time_line" ]; then
    best_slowstart=$(echo "$best_time_line" | cut -d',' -f2)
    best_time=$(echo "$best_time_line" | cut -d',' -f5)
    echo "Fastest Execution:" >> "$REPORT_FILE"
    echo "  Slowstart Value: $best_slowstart" >> "$REPORT_FILE"
    echo "  Total Time: ${best_time}s" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

# Most CPU efficient
most_cpu_efficient=$(tail -n +2 "$CSV_FILE" | sort -t',' -k6 -n | head -1)
if [ -n "$most_cpu_efficient" ]; then
    cpu_slowstart=$(echo "$most_cpu_efficient" | cut -d',' -f2)
    cpu_usage=$(echo "$most_cpu_efficient" | cut -d',' -f6)
    echo "Most CPU Efficient:" >> "$REPORT_FILE"
    echo "  Slowstart Value: $cpu_slowstart" >> "$REPORT_FILE"
    echo "  Average CPU Usage: ${cpu_usage}%" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
fi

# Memory usage analysis
echo "MEMORY USAGE ANALYSIS" >> "$REPORT_FILE"
echo "=====================" >> "$REPORT_FILE"
tail -n +2 "$CSV_FILE" | awk -F',' '
{
    printf "Slowstart %s: Avg Memory = %sMB, Max Memory = %sMB\n", $2, $7, $8
}' >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

# Resource utilization trends
echo "RESOURCE UTILIZATION TRENDS" >> "$REPORT_FILE"
echo "===========================" >> "$REPORT_FILE"

# Check if there's a correlation between slowstart and performance
echo "Correlation Analysis:" >> "$REPORT_FILE"
tail -n +2 "$CSV_FILE" | awk -F',' '
BEGIN {
    print "- Lower slowstart values (0.1-0.3): Early reduce start, potentially higher resource overlap"
    print "- Medium slowstart values (0.5-0.7): Balanced approach"  
    print "- Higher slowstart values (1.0): Sequential execution, potentially lower resource contention"
}
{
    slowstart[NR] = $2
    total_time[NR] = $5
    cpu_usage[NR] = $6
    memory_usage[NR] = $8
    count = NR
}
END {
    if (count >= 2) {
        print ""
        print "Observed Patterns:"
        
        # Simple trend analysis
        min_time = 999999
        max_time = 0
        min_slowstart = ""
        max_slowstart = ""
        
        for (i = 1; i <= count; i++) {
            if (total_time[i] < min_time) {
                min_time = total_time[i]
                min_slowstart = slowstart[i]
            }
            if (total_time[i] > max_time) {
                max_time = total_time[i]
                max_slowstart = slowstart[i]
            }
        }
        
        printf "- Fastest configuration: slowstart=%s (%ss)\n", min_slowstart, min_time
        printf "- Slowest configuration: slowstart=%s (%ss)\n", max_slowstart, max_time
        
        time_diff = max_time - min_time
        if (time_diff > 0) {
            improvement = (time_diff / max_time) * 100
            printf "- Performance improvement: %.1f%% (%.0fs difference)\n", improvement, time_diff
        }
    }
}' >> "$REPORT_FILE"

# Recommendations
echo "" >> "$REPORT_FILE"
echo "RECOMMENDATIONS" >> "$REPORT_FILE"
echo "===============" >> "$REPORT_FILE"
echo "1. Compare execution times across different slowstart values" >> "$REPORT_FILE"
echo "2. Monitor resource utilization patterns (CPU, Memory, Load)" >> "$REPORT_FILE"
echo "3. Consider cluster size and workload characteristics" >> "$REPORT_FILE"
echo "4. Test with larger datasets for more significant differences" >> "$REPORT_FILE"
echo "5. Analyze Hadoop logs for detailed phase timing information" >> "$REPORT_FILE"

# Data quality assessment
echo "" >> "$REPORT_FILE"
echo "DATA QUALITY ASSESSMENT" >> "$REPORT_FILE"
echo "=======================" >> "$REPORT_FILE"

successful_runs=$(tail -n +2 "$CSV_FILE" | grep -c "SUCCESS" || echo "0")
failed_runs=$(tail -n +2 "$CSV_FILE" | grep -c "FAILED" || echo "0")
total_runs=$((successful_runs + failed_runs))

echo "Total Experiments: $total_runs" >> "$REPORT_FILE"
echo "Successful Runs: $successful_runs" >> "$REPORT_FILE"
echo "Failed Runs: $failed_runs" >> "$REPORT_FILE"

if [ $total_runs -gt 0 ]; then
    success_rate=$(echo "scale=1; $successful_runs * 100 / $total_runs" | bc -l 2>/dev/null || echo "0")
    echo "Success Rate: ${success_rate}%" >> "$REPORT_FILE"
fi

echo "" >> "$REPORT_FILE"
echo "Report generation completed: $(date)" >> "$REPORT_FILE"

echo "Analysis report generated successfully: $REPORT_FILE"
