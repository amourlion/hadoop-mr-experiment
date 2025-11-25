# 多节点性能监测使用指南

本文档介绍如何使用更新后的脚本在Hadoop集群的多个节点上收集系统指标数据。

## 🔧 主要变更

### 1. collect_metrics.sh 脚本更新
- **新的参数格式**: `./collect_metrics.sh <节点名> [采集间隔]`
- **输出文件命名**: 自动生成 `{节点名}.csv` 文件
- **列格式**: 添加了 `node_name` 列作为第一列，便于多节点数据合并分析

### 2. 新增数据合并脚本
- **merge_node_metrics.sh**: 将多个节点的CSV文件合并成单个文件进行分析

## 📋 使用步骤

### 步骤1: 在各个节点收集数据

在**主节点（Master）**上运行：
```bash
# 使用便捷脚本
./run_scripts.sh collect_metrics.sh master 1

# 或直接调用
./scripts/collect_metrics.sh master 1
```

在**工作节点（Worker）**上运行：
```bash
# Worker节点1
./scripts/collect_metrics.sh worker01 1

# Worker节点2  
./scripts/collect_metrics.sh worker02 1

# 更多节点...
./scripts/collect_metrics.sh worker03 1
```

### 步骤2: 运行MapReduce任务
在主节点运行性能测试：
```bash
# 单个实验
./run_scripts.sh monitor_job.sh 0.3

# 批量实验  
./run_scripts.sh batch_experiment.sh
```

### 步骤3: 收集各节点的CSV文件
将各个节点的CSV文件收集到一个位置：
```bash
# 示例：通过scp收集文件
scp worker01:/path/to/worker01.csv ./
scp worker02:/path/to/worker02.csv ./
scp worker03:/path/to/worker03.csv ./
```

### 步骤4: 合并多节点数据
```bash
# 合并所有节点的指标数据
./run_scripts.sh merge_node_metrics.sh cluster_metrics.csv master.csv worker01.csv worker02.csv worker03.csv
```

## 📊 输出格式

### 单节点CSV格式
每个节点生成的CSV文件包含以下列：
```csv
node_name,timestamp,cpu_percent,memory_used_mb,memory_total_mb,memory_percent,load_avg,disk_reads,disk_writes,network_rx_mb,network_tx_mb,java_cpu_percent,java_memory_percent,java_processes
master,1764038886,3.2,1414,7658,18.5,0.06,0,0,0,0,0,0,0
```

### 合并后CSV格式
合并后的文件保持相同的列结构，可以按节点名称进行分组分析：
```csv
node_name,timestamp,cpu_percent,memory_used_mb,memory_total_mb,memory_percent,load_avg,disk_reads,disk_writes,network_rx_mb,network_tx_mb,java_cpu_percent,java_memory_percent,java_processes
master,1764038886,3.2,1414,7658,18.5,0.06,0,0,0,0,0,0,0
worker01,1764038887,2.1,1200,4096,29.3,0.12,45,23,1.2,0.8,15.6,8.2,3
worker02,1764038888,1.8,1150,4096,28.1,0.08,52,18,0.9,0.6,12.4,7.1,2
```

## 🛠️ 高级用法

### 远程批量启动收集
创建批量启动脚本：
```bash
#!/bin/bash
# start_cluster_monitoring.sh

NODES=("master" "worker01" "worker02" "worker03")
INTERVAL=1

for node in "${NODES[@]}"; do
    if [ "$node" == "master" ]; then
        # 本地启动
        ./scripts/collect_metrics.sh master $INTERVAL &
    else
        # 远程启动
        ssh $node "cd /path/to/project && ./scripts/collect_metrics.sh $node $INTERVAL" &
    fi
    echo "Started monitoring on $node"
done

echo "All nodes monitoring started"
```

### 自动数据收集和合并
```bash
#!/bin/bash
# collect_and_merge.sh

EXPERIMENT_ID=$(date +%Y%m%d_%H%M%S)
NODES=("master" "worker01" "worker02" "worker03")

# 停止所有节点的监控
for node in "${NODES[@]}"; do
    if [ "$node" == "master" ]; then
        pkill -f "collect_metrics.sh master"
    else
        ssh $node "pkill -f 'collect_metrics.sh $node'"
    fi
done

# 收集CSV文件
for node in "${NODES[@]}"; do
    if [ "$node" != "master" ]; then
        scp $node:$node.csv ./metrics/
    fi
done

# 合并数据
./scripts/merge_node_metrics.sh "metrics/cluster_${EXPERIMENT_ID}.csv" master.csv metrics/worker*.csv

echo "Cluster metrics saved to: metrics/cluster_${EXPERIMENT_ID}.csv"
```

## 📈 数据分析示例

合并后的数据可以用于各种分析：

### 1. 按节点分析资源使用情况
```bash
# 查看各节点的平均CPU使用率
awk -F',' 'NR>1 {cpu[$1]+=$3; count[$1]++} END {for(node in cpu) print node": "cpu[node]/count[node]"%"}' cluster_metrics.csv
```

### 2. 时间序列分析
```bash
# 按时间戳排序查看集群整体负载
tail -n +2 cluster_metrics.csv | sort -t',' -k2 -n
```

### 3. 导入到数据分析工具
合并后的CSV文件可以直接导入到：
- Excel/LibreOffice Calc
- Python pandas
- R
- Tableau
- 其他数据分析工具

## 🚨 注意事项

1. **时间同步**: 确保所有节点的系统时间同步，便于准确的时间序列分析
2. **存储空间**: 监控脚本会持续写入数据，注意磁盘空间使用
3. **网络传输**: 收集大量节点数据时，注意网络带宽影响
4. **权限设置**: 确保脚本在所有节点都有执行权限
5. **进程管理**: 实验结束后记得停止所有节点的监控进程

## 🎯 最佳实践

1. **命名规范**: 使用一致的节点命名规范（如 master, worker01, worker02）
2. **定期清理**: 定期清理旧的CSV文件避免磁盘空间不足
3. **备份数据**: 重要的实验数据及时备份
4. **监控间隔**: 根据实验需要调整数据收集间隔（1-5秒推荐）
