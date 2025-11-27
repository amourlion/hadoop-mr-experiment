#!/bin/bash

# ================= 配置区 =================
NODE_NAME=${1:-"unknown_node"}
OUTPUT_DIR="mapreduce_metrics"
# 进程级指标文件 (CPU, Mem, Disk IO)
PROCESS_LOG="${OUTPUT_DIR}/${NODE_NAME}_process_metrics.txt"
# 系统级网络指标文件 (Network IO)
NET_LOG="${OUTPUT_DIR}/${NODE_NAME}_network_metrics.txt"
# =========================================

mkdir -p "$OUTPUT_DIR"

# 设置语言环境，确保小数是个点(.)而不是逗号(,)
export LC_ALL=C

echo "=== MapReduce 深度监控启动 ==="
echo "节点: $NODE_NAME"
echo "进程数据: $PROCESS_LOG"
echo "网络数据: $NET_LOG"

# 初始化文件头
# 1. 进程日志头 (模拟 pidstat 输出)
echo "Time        UID      PID    %usr %system  %guest   %wait    %CPU   CPU  Command" > "$PROCESS_LOG"
# 2. 网络日志头
echo "Time        IFACE      rxpck/s   txpck/s    rxkB/s    txkB/s   rxcmp/s   txcmp/s  rxmcst/s" > "$NET_LOG"

while true; do
    # 1. 获取时间戳
    TIMESTAMP=$(date +"%H:%M:%S")

    # 2. 动态发现 PID (匹配 MRAppMaster 和 YarnChild)
    PIDS=$(pgrep -f "YarnChild|MRAppMaster" | tr '\n' ',' | sed 's/,$//')

    # 3. 采集网络指标 (系统级)
    # 使用 sar -n DEV 采集 1秒，取平均值，过滤掉不相关的行
    # grep -v "lo" 排除回环接口，只看物理网卡(如 eth0)
    sar -n DEV 1 1 | grep -E "Average|Average:" | grep -v "IFACE" | grep -v "lo" | while read line; do
        # 这里的 awk 是为了去掉 sar 输出里的 "Average:" 前缀
        clean_line=$(echo "$line" | sed 's/Average: //g' | sed 's/Average //g')
        echo "$TIMESTAMP  $clean_line" >> "$NET_LOG"
    done & 
    # 注意：sar 放到后台运行，为了和下面的 pidstat 并行，减少时间误差

    # 4. 采集进程指标 (如果发现了 PID)
    if [ -n "$PIDS" ]; then
        # -u: CPU, -r: 内存, -d: 磁盘IO
        # 1 1: 间隔1秒，采样1次
        # 过滤掉不需要的头部信息，只保留数据行
        pidstat -u -r -d -p "$PIDS" 1 1 | grep -v "Linux" | grep -v "Command" | grep -v "^$" | while read line; do
            # 如果行里包含 UID (是表头)，则忽略，因为我们已经有文件头了
            if [[ "$line" != *"UID"* ]]; then
                 echo "$TIMESTAMP  $line" >> "$PROCESS_LOG"
            fi
        done
        
        # 简单的进度展示
        COUNT=$(echo "$PIDS" | tr ',' '\n' | wc -l)
        echo -ne "\r[Monitoring] 活跃进程数: $COUNT | 时间: $TIMESTAMP "
    else
        echo -ne "\r[Waiting] 等待 MapReduce 任务启动...           "
    fi
    
    # 等待后台的 sar 结束
    wait
done