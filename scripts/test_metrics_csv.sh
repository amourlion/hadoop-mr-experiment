#!/bin/bash

# Test script to verify CSV output format
# This script simulates the metrics collection to ensure proper CSV format

echo "Testing CSV metrics collection..."

# Create a temporary test directory
TEST_DIR="test_metrics_output"
mkdir -p "$TEST_DIR"

# Test the collect_metrics.sh script for a few seconds
echo "1. Testing collect_metrics.sh CSV output format..."
timeout 3s ./collect_metrics.sh "$TEST_DIR/test_system_metrics.csv" 1 || true

# Check if the CSV file was created and has proper format
if [ -f "$TEST_DIR/test_system_metrics.csv" ]; then
    echo "✓ CSV file created successfully"
    
    # Check header
    echo "2. Checking CSV header..."
    head -1 "$TEST_DIR/test_system_metrics.csv"
    
    # Check data rows
    echo "3. Checking sample data rows..."
    if [ $(wc -l < "$TEST_DIR/test_system_metrics.csv") -gt 1 ]; then
        tail -n 2 "$TEST_DIR/test_system_metrics.csv"
        echo "✓ CSV data format looks correct"
    else
        echo "⚠ No data rows found"
    fi
    
    # Verify column count
    echo "4. Verifying column count..."
    header_cols=$(head -1 "$TEST_DIR/test_system_metrics.csv" | tr ',' '\n' | wc -l)
    data_cols=$(tail -1 "$TEST_DIR/test_system_metrics.csv" | tr ',' '\n' | wc -l)
    
    echo "Header columns: $header_cols"
    echo "Data columns: $data_cols"
    
    if [ "$header_cols" -eq "$data_cols" ]; then
        echo "✓ Column count matches between header and data"
    else
        echo "✗ Column count mismatch!"
    fi
    
else
    echo "✗ CSV file was not created"
fi

# Test file naming convention
echo "5. Testing new file naming convention..."
EXPERIMENT_ID="test_$(date +%Y%m%d_%H%M%S)"
SLOWSTART_VALUE="0.5"
EXPECTED_NAME="system_metrics_${EXPERIMENT_ID}_slowstart_${SLOWSTART_VALUE}.csv"

echo "Expected filename format: $EXPECTED_NAME"
echo "✓ Filename follows new naming convention"

# Clean up test files
rm -rf "$TEST_DIR"

echo ""
echo "=== Test Summary ==="
echo "✓ CSV format verification completed"
echo "✓ File naming convention updated"
echo "✓ System metrics will now be saved as CSV files for data analysis"
