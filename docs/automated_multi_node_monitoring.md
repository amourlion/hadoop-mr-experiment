# 自动化多节点监控使用指南

本文档说明如何使用集成了自动化多节点监控功能的批量实验脚本。

## 📋 功能概述

增强版的 `batch_experiment.sh` 现在支持：

1. **自动部署**：自动将监控脚本部署到远程节点
2. **自动启动**：实验开始前自动启动所有节点的监控进程
3. **自动终止**：实验结束后自动停止所有监控进程
4. **自动回传**：自动从远程节点收集监控数据到本地

## 🚀 快速开始

### 前提条件

确保已配置 SSH 免密码登录：

```bash
# 测试 SSH 连接
ssh hadoop002 "echo 'Connection successful'"
ssh hadoop003 "echo 'Connection successful'"
```

### 一键执行

现在只需一个命令即可完成所有操作：

```bash
# 执行批量实验（自动完成监控部署、启动、数据收集）
./scripts/batch_experiment.sh /mr_input_5gb /mr_output
```

## 🔧 配置说明

### 远程节点配置

在 `scripts/batch_experiment.sh` 中修改以下配置：

```bash
# 要监控的远程节点列表
REMOTE_NODES=("hadoop002" "hadoop003")

# 远程监控目录
REMOTE_MONITOR_DIR="~/monitoring"

# 监控数据采集间隔（秒）
MONITOR_INTERVAL=1

# 本地数据存储目录
LOCAL_METRICS_DIR="system_metrics"
```

### 添加更多节点

```bash
# 修改节点列表
REMOTE_NODES=("hadoop002" "hadoop003" "hadoop004" "hadoop005")
```

## 📊 执行流程

脚本会按以下四个阶段自动执行：

### Phase 1: Multi-Node Monitoring Setup
```
→ 为每个远程节点创建监控目录
→ 部署 collect_metrics.sh 到远程节点
→ 启动远程监控进程
→ 验证监控进程状态
```

### Phase 2: Batch Experiments
```
→ 执行批量 MapReduce 实验
→ 远程监控持续收集数据
→ 生成实验结果报告
```

### Phase 3: Stop Monitoring and Collect Data
```
→ 停止所有远程监控进程
→ 从远程节点收集 CSV 数据文件
→ 保存到本地 system_metrics/ 目录
```

### Phase 4: Analysis and Reporting
```
→ 生成实验分析报告
→ 显示性能统计汇总
→ 列出收集的监控数据文件
```

## 📁 输出文件结构

执行完成后，文件组织如下：

```
/home/ecs-user/MRApplication/reduce-startup/
├── metrics/                                    # 实验结果
│   ├── batch_summary_batch_20251126_*.csv     # 批量实验汇总
│   ├── analysis_report_batch_20251126_*.txt   # 分析报告
│   └── experiment_*_slowstart_*.csv           # 各实验详细数据
│
└── system_metrics/                             # 监控数据
    ├── hadoop002_20251126_*.csv               # hadoop002 监控数据
    └── hadoop003_20251126_*.csv               # hadoop003 监控数据
```

## 💡 示例输出

### 成功执行示例

```
=== Hadoop MapReduce Batch Experiment with Multi-Node Monitoring ===
Input Path: /mr_input_5gb
Output Base Path: /mr_output
Experiment Base ID: batch_20251126_130215
Slowstart Values: 0.1 0.3 0.5 0.7 1.0
Remote Nodes: hadoop002 hadoop003

=== Phase 1: Multi-Node Monitoring Setup ===

Setting up monitoring on hadoop002:
  → Deploying monitoring script to hadoop002...
  ✓ Successfully deployed to hadoop002
  → Starting monitoring on hadoop002...
  ✓ Monitoring started on hadoop002 (PID: 12345)

Setting up monitoring on hadoop003:
  → Deploying monitoring script to hadoop003...
  ✓ Successfully deployed to hadoop003
  → Starting monitoring on hadoop003...
  ✓ Monitoring started on hadoop003 (PID: 23456)

Monitoring Setup Summary:
  Deployed: 2/2 nodes
  Started: 2/2 nodes
✓ Monitoring is active on 2 node(s)

=== Phase 2: Batch Experiments ===
Starting batch experiments...

--- Experiment 1/5: slowstart=0.1 ---
...

=== Phase 3: Stop Monitoring and Collect Data ===

Processing hadoop002:
  → Stopping monitoring on hadoop002...
  ✓ Monitoring stopped on hadoop002
  → Collecting data from hadoop002...
  ✓ Collected hadoop002_20251126_130215.csv (2.3M) from hadoop002

Processing hadoop003:
  → Stopping monitoring on hadoop003...
  ✓ Monitoring stopped on hadoop003
  → Collecting data from hadoop003...
  ✓ Collected hadoop003_20251126_130215.csv (2.1M) from hadoop003

Data Collection Summary:
  Stopped: 2/2 nodes
  Collected: 2/2 nodes

✓ Successfully collected monitoring data from 2 node(s):
  hadoop002: system_metrics/hadoop002_20251126_130215.csv
  hadoop003: system_metrics/hadoop003_20251126_130215.csv

=== Phase 4: Analysis and Reporting ===

=== Batch Experiment Summary ===
Total Experiments: 5
Successful: 5
Failed: 0
Total Batch Time: 1234 seconds

=== Collected Monitoring Data ===
Node        | File Location
------------|--------------------------------------------
hadoop002   | system_metrics/hadoop002_20251126_130215.csv
hadoop003   | system_metrics/hadoop003_20251126_130215.csv

All tasks completed successfully!
```

## ⚠️ 容错机制

脚本包含完善的容错处理：

### 节点部署失败
- 自动跳过失败的节点
- 继续处理其他节点
- 显示详细错误信息

### 监控启动失败
- 实验仍会继续执行
- 显示警告信息
- 不影响实验结果

### 数据收集失败
- 跳过无法收集的节点
- 收集可用节点的数据
- 记录失败原因

## 🔍 故障排查

### 问题1: SSH 连接失败

**症状：**
```
✗ Failed to create directory on hadoop002
```

**解决方案：**
```bash
# 测试 SSH 连接
ssh hadoop002 "echo test"

# 检查 SSH 密钥
ls -la ~/.ssh/

# 重新配置免密登录
ssh-copy-id hadoop002
```

### 问题2: 监控进程无法启动

**症状：**
```
⚠ Could not verify monitoring process on hadoop002
```

**解决方案：**
```bash
# 检查远程节点上的脚本权限
ssh hadoop002 "ls -la ~/monitoring/"

# 手动测试脚本执行
ssh hadoop002 "~/monitoring/collect_metrics.sh hadoop002 1"
```

### 问题3: 数据文件不存在

**症状：**
```
⚠ No monitoring data found on hadoop002
```

**解决方案：**
```bash
# 检查远程文件
ssh hadoop002 "ls -la ~/monitoring/"

# 查看脚本输出目录
ssh hadoop002 "ls -la ~/monitoring/system_metrics/"
```

### 问题4: 磁盘空间不足

**解决方案：**
```bash
# 检查本地磁盘空间
df -h .

# 检查远程节点空间
ssh hadoop002 "df -h ~"
ssh hadoop003 "df -h ~"

# 清理旧数据
rm -f system_metrics/*.csv.old
```

## 📈 数据分析

### 查看收集的监控数据

```bash
# 查看文件列表
ls -lh system_metrics/

# 查看数据头部
head -n 5 system_metrics/hadoop002_*.csv

# 统计数据行数
wc -l system_metrics/*.csv
```

### 分析节点性能

```bash
# hadoop002 的平均 CPU 使用率
awk -F',' 'NR>1 {sum+=$3; count++} END {print "平均CPU:", sum/count"%"}' \
    system_metrics/hadoop002_*.csv

# hadoop003 的最大内存使用
awk -F',' 'NR>1 {if($4>max) max=$4} END {print "最大内存:", max"MB"}' \
    system_metrics/hadoop003_*.csv
```

### 使用 Python 分析

```python
import pandas as pd
import glob

# 读取所有节点数据
files = glob.glob('system_metrics/hadoop*_*.csv')
dfs = [pd.read_csv(f) for f in files]
df = pd.concat(dfs, ignore_index=True)

# 按节点分组统计
stats = df.groupby('node_name').agg({
    'cpu_percent': ['mean', 'max'],
    'memory_percent': ['mean', 'max'],
    'load_avg': 'mean'
})

print(stats)
```

## 🛠️ 高级配置

### 修改监控间隔

更密集的数据采集（每 0.5 秒）：
```bash
MONITOR_INTERVAL=0.5
```

更稀疏的数据采集（每 5 秒）：
```bash
MONITOR_INTERVAL=5
```

### 自定义远程目录

```bash
REMOTE_MONITOR_DIR="/opt/monitoring"
```

### 修改 Slowstart 参数范围

```bash
SLOWSTART_VALUES=(0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0)
```

## 📝 最佳实践

1. **实验前检查**
   - 确认所有节点 SSH 连接正常
   - 检查远程节点磁盘空间充足
   - 验证 collect_metrics.sh 脚本可执行

2. **实验中监控**
   - 可以在另一个终端实时查看远程监控数据
   ```bash
   ssh hadoop002 "tail -f ~/monitoring/system_metrics/hadoop002_*.csv"
   ```

3. **实验后处理**
   - 脚本已自动停止监控和收集数据
   - 及时备份重要的实验结果
   - 可选择性清理远程节点的监控文件

4. **数据管理**
   - 使用时间戳识别不同批次的实验
   - 定期备份 system_metrics/ 目录
   - 建立实验日志记录习惯

## 🔄 与手动流程的对比

### 手动流程（旧方式）
```bash
# 1. 手动部署脚本到每个节点
ssh hadoop002 "mkdir -p ~/monitoring"
scp scripts/collect_metrics.sh hadoop002:~/monitoring/
ssh hadoop003 "mkdir -p ~/monitoring"
scp scripts/collect_metrics.sh hadoop003:~/monitoring/

# 2. 手动启动监控
ssh hadoop002 "cd ~/monitoring && nohup ./collect_metrics.sh hadoop002 1 &"
ssh hadoop003 "cd ~/monitoring && nohup ./collect_metrics.sh hadoop003 1 &"

# 3. 运行实验
./scripts/batch_experiment.sh /mr_input_5gb /mr_output

# 4. 手动停止监控
ssh hadoop002 "pkill -f collect_metrics.sh"
ssh hadoop003 "pkill -f collect_metrics.sh"

# 5. 手动收集数据
scp hadoop002:~/monitoring/hadoop002*.csv ./system_metrics/
scp hadoop003:~/monitoring/hadoop003*.csv ./system_metrics/
```

### 自动化流程（新方式）
```bash
# 一键完成所有操作
./scripts/batch_experiment.sh /mr_input_5gb /mr_output
```

**优势：**
- ✅ 减少人工操作步骤
- ✅ 避免遗忘停止监控进程
- ✅ 自动化数据收集，减少错误
- ✅ 统一的错误处理和日志输出
- ✅ 支持多节点批量操作

## 🆘 常见问题

**Q: 如果只想监控一个节点怎么办？**

A: 修改节点列表：
```bash
REMOTE_NODES=("hadoop002")
```

**Q: 可以在实验进行中途添加监控吗？**

A: 当前版本不支持。监控必须在实验开始前启动。

**Q: 如何查看某个节点的实时监控状态？**

A: 使用以下命令：
```bash
ssh hadoop002 "ps aux | grep collect_metrics"
ssh hadoop002 "tail -f ~/monitoring/system_metrics/hadoop002_*.csv"
```

**Q: 监控数据会占用多少空间？**

A: 取决于实验时长。通常每小时约 10-50MB 每节点。

**Q: 如果实验中途失败，监控进程会自动停止吗？**

A: 不会。但脚本在 Phase 3 会自动停止所有监控进程。如果脚本异常退出，需要手动停止：
```bash
ssh hadoop002 "pkill -f collect_metrics"
ssh hadoop003 "pkill -f collect_metrics"
```

## 📚 相关文档

- [multi_node_monitoring_usage.md](./multi_node_monitoring_usage.md) - 手动多节点监控流程
- [MULTI_NODE_USAGE.md](./MULTI_NODE_USAGE.md) - 多节点性能监测基础
- [README.md](../readme.md) - 项目主文档

---

**创建日期：** 2025-11-26  
**适用版本：** batch_experiment.sh v2.0 (自动化多节点监控版)
