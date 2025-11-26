#!/bin/bash

# Package Experiment Results Script
# Packages metrics, system_metrics, and other_node_monitoring into a zip file
# Usage: ./package_results.sh [output_filename]

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
DIRS_TO_PACKAGE=("metrics" "system_metrics" "other_node_monitoring")
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DEFAULT_OUTPUT="experiment_results_${TIMESTAMP}.zip"
OUTPUT_FILE=${1:-"${DEFAULT_OUTPUT}"}

echo -e "${BLUE}=== Package Experiment Results ===${NC}"
echo -e "${YELLOW}Output File: ${OUTPUT_FILE}${NC}"

# Check if zip command is available
if ! command -v zip &> /dev/null; then
    echo -e "${RED}✗ Error: 'zip' command not found${NC}"
    echo -e "${YELLOW}Please install zip: sudo apt-get install zip${NC}"
    exit 1
fi

# Check which directories exist and calculate total size
existing_dirs=()
total_size=0
missing_dirs=()

echo -e "\n${CYAN}Checking directories...${NC}"
for dir in "${DIRS_TO_PACKAGE[@]}"; do
    if [ -d "$dir" ]; then
        dir_size=$(du -sh "$dir" 2>/dev/null | cut -f1)
        file_count=$(find "$dir" -type f | wc -l)
        echo -e "${GREEN}  ✓ ${dir}/ (${file_count} files, ${dir_size})${NC}"
        existing_dirs+=("$dir")
    else
        echo -e "${YELLOW}  ⚠ ${dir}/ (not found, skipping)${NC}"
        missing_dirs+=("$dir")
    fi
done

# Check if we have any directories to package
if [ ${#existing_dirs[@]} -eq 0 ]; then
    echo -e "\n${RED}✗ Error: None of the target directories exist${NC}"
    echo -e "${YELLOW}Expected directories: ${DIRS_TO_PACKAGE[*]}${NC}"
    exit 1
fi

# Remove existing output file if it exists
if [ -f "${OUTPUT_FILE}" ]; then
    echo -e "\n${YELLOW}Removing existing ${OUTPUT_FILE}...${NC}"
    rm -f "${OUTPUT_FILE}"
fi

# Create zip archive
echo -e "\n${CYAN}Creating zip archive...${NC}"
echo -e "${BLUE}Including directories: ${existing_dirs[*]}${NC}"

# Use zip command
if zip -r "${OUTPUT_FILE}" "${existing_dirs[@]}" -x "*.git*" -x "*__pycache__*" -x "*.pyc" > /dev/null 2>&1; then
    # Get final file size
    if [ -f "${OUTPUT_FILE}" ]; then
        output_size=$(du -h "${OUTPUT_FILE}" | cut -f1)
        file_count=$(unzip -l "${OUTPUT_FILE}" | tail -n 1 | awk '{print $2}')
        
        echo -e "\n${GREEN}=== Packaging Complete ===${NC}"
        echo -e "Output File: ${CYAN}${OUTPUT_FILE}${NC}"
        echo -e "File Size: ${output_size}"
        echo -e "Total Files: ${file_count}"
        
        # List contents summary
        echo -e "\n${BLUE}=== Archive Contents Summary ===${NC}"
        for dir in "${existing_dirs[@]}"; do
            count=$(unzip -l "${OUTPUT_FILE}" | grep "^.*${dir}/" | wc -l)
            echo -e "  ${dir}/: ${count} items"
        done
        
        if [ ${#missing_dirs[@]} -gt 0 ]; then
            echo -e "\n${YELLOW}Note: The following directories were not found and were skipped:${NC}"
            for dir in "${missing_dirs[@]}"; do
                echo -e "  - ${dir}/"
            done
        fi
        
        echo -e "\n${GREEN}✓ Successfully packaged experiment results!${NC}"
        echo -e "${CYAN}You can now download or transfer: ${OUTPUT_FILE}${NC}"
        
        # Show how to extract
        echo -e "\n${BLUE}To extract the archive:${NC}"
        echo -e "  unzip ${OUTPUT_FILE}"
        
    else
        echo -e "\n${RED}✗ Error: Failed to create zip file${NC}"
        exit 1
    fi
else
    echo -e "\n${RED}✗ Error: Zip command failed${NC}"
    exit 1
fi
