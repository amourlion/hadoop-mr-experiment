#!/bin/bash

# Multi-Node Metrics Merger Script
# Usage: ./merge_node_metrics.sh <output_file> <node_csv_files...>
# This script merges metrics from multiple nodes into a single CSV for analysis

OUTPUT_FILE=${1}
shift
NODE_FILES=("$@")

# Validate parameters
if [ -z "$OUTPUT_FILE" ]; then
    echo "Error: Output file is required"
    echo "Usage: $0 <output_file> <node_csv_files...>"
    echo "Example: $0 merged_metrics.csv master.csv worker01.csv worker02.csv"
    exit 1
fi

if [ ${#NODE_FILES[@]} -eq 0 ]; then
    echo "Error: At least one node CSV file is required"
    echo "Usage: $0 <output_file> <node_csv_files...>"
    exit 1
fi

echo "=== Multi-Node Metrics Merger ==="
echo "Output file: $OUTPUT_FILE"
echo "Node files to merge: ${NODE_FILES[*]}"

# Check if all input files exist
missing_files=()
for file in "${NODE_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -gt 0 ]; then
    echo "Error: The following files do not exist:"
    for file in "${missing_files[@]}"; do
        echo "  - $file"
    done
    exit 1
fi

# Create output file with header from first input file
echo "Creating merged metrics file..."
head -1 "${NODE_FILES[0]}" > "$OUTPUT_FILE"

# Merge data from all node files (skip headers)
total_rows=0
for file in "${NODE_FILES[@]}"; do
    node_name=$(basename "$file" .csv)
    file_rows=$(tail -n +2 "$file" | wc -l)
    
    echo "Processing $file: $file_rows data rows"
    
    # Append data rows (skip header)
    tail -n +2 "$file" >> "$OUTPUT_FILE"
    
    total_rows=$((total_rows + file_rows))
done

echo ""
echo "✅ Merge completed successfully!"
echo "📁 Merged file: $OUTPUT_FILE"
echo "📊 Total data rows: $total_rows"
echo "📋 Nodes included: ${#NODE_FILES[@]}"

# Display merged file summary
echo ""
echo "=== Merged Data Summary ==="
echo "Header:"
head -1 "$OUTPUT_FILE"
echo ""
echo "Node distribution:"
tail -n +2 "$OUTPUT_FILE" | cut -d',' -f1 | sort | uniq -c | while read count node; do
    printf "  %-15s: %d rows\n" "$node" "$count"
done

echo ""
echo "🚀 Ready for analysis with: $OUTPUT_FILE"
