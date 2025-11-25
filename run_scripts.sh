#!/bin/bash

# Convenience wrapper for accessing scripts in the scripts folder
# Usage: ./run_scripts.sh <script_name> [arguments...]

SCRIPT_DIR="$(dirname "$0")/scripts"

if [ $# -eq 0 ]; then
    echo "Available scripts:"
    echo "  generate_data.py     - Generate datasets of any size"
    echo "  monitor_job.sh       - Monitor single MapReduce job"
    echo "  batch_experiment.sh  - Run batch experiments with different slowstart values"
    echo "  collect_metrics.sh   - Collect system metrics from a node"
    echo "  merge_node_metrics.sh - Merge metrics from multiple nodes"
    echo "  generate_report.sh   - Generate analysis reports"
    echo "  test_metrics_csv.sh  - Test CSV metrics collection"
    echo ""
    echo "Usage: ./run_scripts.sh <script_name> [arguments...]"
    echo ""
    echo "Examples:"
    echo "  ./run_scripts.sh generate_data.py 100        # Generate 100MB dataset"
    echo "  ./run_scripts.sh monitor_job.sh 0.3          # Monitor job with slowstart 0.3"
    echo "  ./run_scripts.sh batch_experiment.sh         # Run batch experiments"
    exit 0
fi

SCRIPT_NAME="$1"
shift

# Check if script exists
SCRIPT_PATH="${SCRIPT_DIR}/${SCRIPT_NAME}"
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Error: Script '$SCRIPT_NAME' not found in scripts directory"
    echo "Available scripts:"
    ls -1 "$SCRIPT_DIR" | grep -E '\.(sh|py)$' | sed 's/^/  /'
    exit 1
fi

# Make script executable if it's not
if [ ! -x "$SCRIPT_PATH" ]; then
    chmod +x "$SCRIPT_PATH"
fi

# Execute the script with remaining arguments
if [[ "$SCRIPT_NAME" == *.py ]]; then
    python3 "$SCRIPT_PATH" "$@"
else
    "$SCRIPT_PATH" "$@"
fi
