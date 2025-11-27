#!/bin/bash

# Improved MapReduce Metrics Collector
# Usage: ./collect_metrics_v2.sh <node_name>

NODE_NAME=${1:-"unknown_node"}
OUTPUT_DIR="mapreduce_metrics"
mkdir -p "$OUTPUT_DIR"

# 文件名
METRICS_FILE="${OUTPUT_DIR}/${NODE_NAME}_metrics_$(date +%Y%m%d_%H%M%S).txt"

# 写入表头 (模拟 pidstat 格式，方便后续处理)
echo "Time        UID      PID    %usr %system  %guest   %wait    %CPU   CPU  Command" > "$METRICS_FILE"

echo "Start monitoring on $NODE_NAME. Output: $METRICS_FILE"

while true; do
    # 1. 实时获取当前所有的 YarnChild 和 MRAppMaster 的 PID
    # 使用 pgrep 比 jps 更快更直接
    # -f 匹配完整命令行，-d, 用逗号分隔用于 pidstat
    PIDS=$(pgrep -f "YarnChild|MRAppMaster" | tr '\n' ',' | sed 's/,$//')

    if [ -n "$PIDS" ]; then
        # 2. 获取当前时间戳
        TIMESTAMP=$(date +"%I:%M:%S %p")
        
        # 3. 运行一次 pidstat (不加 &, 只跑一次采样)
        # -h 这一行是为了去掉 pidstat 自带的头部，方便追加写入
        # 这里的 1 1 表示：采样间隔1秒，采样次数1次
        pidstat -u -r -d -p "$PIDS" 1 1 | grep -v "Linux" | grep -v "Command" | grep -v "^$" | while read line; do
            # 给每一行加上时间戳，模拟 pidstat -t 的效果
            echo "$TIMESTAMP  $line" >> "$METRICS_FILE"
        done
        
        # 屏幕打印简单的状态，让你知道它在动
        COUNT=$(echo "$PIDS" | tr ',' '\n' | wc -l)
        echo -ne "\r[Running] Monitoring $COUNT processes at $TIMESTAMP..."
    else
        echo -ne "\r[Waiting] No MapReduce processes found..."
        sleep 1
    fi
done