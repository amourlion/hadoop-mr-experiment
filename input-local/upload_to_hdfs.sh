#!/bin/bash

# Upload generated dataset to HDFS
# Usage: ./upload_to_hdfs.sh [hdfs_path]

HDFS_PATH=${1:-"/mr_input_zg"}

echo "Creating HDFS directory: $HDFS_PATH"
hdfs dfs -mkdir -p "$HDFS_PATH"

echo "Uploading dataset files..."
hdfs dfs -put -f "test01.txt" "$HDFS_PATH/"
hdfs dfs -put -f "test02.txt" "$HDFS_PATH/"

echo "Upload completed. Verifying..."
hdfs dfs -ls "$HDFS_PATH"
hdfs dfs -du -h "$HDFS_PATH"
