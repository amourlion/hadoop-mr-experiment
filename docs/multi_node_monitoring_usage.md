# 多节点监测使用方案

本文档提供了在Hadoop集群多个节点上部署性能监测脚本并运行批量实验的完整操作指南。

## 📋 执行方案概述

本方案包含以下主要步骤:
1. HDFS数据准备
2. 清理本地实验数据
3. 在远程节点部署监测脚本
4. 修改批量实验配置
5. 执行批量实验
6. 收集和合并监测数据

---

## 🚀 完整执行流程

### **阶段1: 准备工作**
#### 1.1 实验数据准备

#### 1.2 清理本地实验数据
```bash
# 清理之前的实验结果数据
rm -rf metrics/*

# 清理之前的系统监测数据
rm -rf system_metrics/*
```

---

### **阶段2: 部署远程监测脚本**

#### 2.1 在hadoop002节点部署
```bash
# 步骤1: 创建远程监测目录
ssh hadoop002 "mkdir -p ~/monitoring"

# 步骤2: 拷贝监测脚本到hadoop002
scp scripts/collect_metrics.sh hadoop002:~/monitoring/

# 步骤3: 验证脚本已成功拷贝
ssh hadoop002 "ls -lh ~/monitoring/"
```

#### 2.2 在hadoop003节点部署
```bash
# 步骤1: 创建远程监测目录
ssh hadoop003 "mkdir -p ~/monitoring"

# 步骤2: 拷贝监测脚本到hadoop003
scp scripts/collect_metrics.sh hadoop003:~/monitoring/

# 步骤3: 验证脚本已成功拷贝
ssh hadoop003 "ls -lh ~/monitoring/"
```

#### 2.3 启动远程节点监测
```bash
# 启动hadoop002监测 (采集间隔1秒)
ssh hadoop002 "cd ~/monitoring && nohup ./collect_metrics.sh hadoop002 1 > /dev/null 2>&1 &"

# 启动hadoop003监测 (采集间隔1秒)
ssh hadoop003 "cd ~/monitoring && nohup ./collect_metrics.sh hadoop003 1 > /dev/null 2>&1 &"

# 验证监测进程已启动
ssh hadoop002 "ps aux | grep collect_metrics"
ssh hadoop003 "ps aux | grep collect_metrics"
```

**输出文件位置:**
- hadoop002: `~/monitoring/hadoop002.csv`
- hadoop003: `~/monitoring/hadoop003.csv`

---

### **阶段3: 修改批量实验配置**

修改 `scripts/batch_experiment.sh` 文件中的slowstart参数配置:

```bash
# 找到以下行:
SLOWSTART_VALUES=(0.1 0.3 0.5 0.7 1.0)

# 修改为:
SLOWSTART_VALUES=(0.1 0.3 0.5 0.7 0.9)
```

**修改方法:**
```bash
# 使用sed命令直接修改
sed -i 's/SLOWSTART_VALUES=(0.1 0.3 0.5 0.7 1.0)/SLOWSTART_VALUES=(0.1 0.3 0.5 0.7 0.9)/' scripts/batch_experiment.sh

# 验证修改
grep "SLOWSTART_VALUES" scripts/batch_experiment.sh
```

---

### **阶段4: 运行批量实验**

```bash
# 执行批量实验
# 参数1: HDFS输入路径
# 参数2: HDFS输出路径基础名
./scripts/batch_experiment.sh /mr_input_5gb /mr_output
```

**实验说明:**
- 将自动运行5组实验,slowstart参数分别为: 0.1, 0.3, 0.5, 0.7, 0.9
- 每组实验之间有10秒间隔
- 每组实验的输出路径为: `/mr_output_slowstart_01`, `/mr_output_slowstart_03`, 等
- 实验过程中,远程节点的监测脚本会持续收集系统性能数据

**预期输出:**
```
=== Hadoop MapReduce Batch Experiment ===
Input Path: /mr_input_5gb
Output Base Path: /mr_output
Experiment Base ID: batch_20251126_112605
Slowstart Values: 0.1 0.3 0.5 0.7 0.9

Starting batch experiments...

--- Experiment 1/5: slowstart=0.1 ---
...
✓ Experiment 1 completed successfully in XXXs

--- Experiment 2/5: slowstart=0.3 ---
...
```

---

### **阶段5: 实验完成后收集数据**

#### 5.1 停止远程监测
```bash
# 停止hadoop002监测进程
ssh hadoop002 "pkill -f 'collect_metrics.sh hadoop002'"

# 停止hadoop003监测进程
ssh hadoop003 "pkill -f 'collect_metrics.sh hadoop003'"

# 验证进程已停止
ssh hadoop002 "ps aux | grep collect_metrics"
ssh hadoop003 "ps aux | grep collect_metrics"
```

#### 5.2 收集远程节点数据
```bash
# 从hadoop002收集CSV文件到本地system_metrics目录
scp hadoop002:~/monitoring/hadoop002.csv ./system_metrics/

# 从hadoop003收集CSV文件到本地system_metrics目录
scp hadoop003:~/monitoring/hadoop003.csv ./system_metrics/

# 验证文件已成功收集
ls -lh ./system_metrics/
```

#### 5.3 合并所有节点数据 (可选)
```bash
# 将所有节点的监测数据合并成一个CSV文件
./scripts/merge_node_metrics.sh \
    system_metrics/cluster_merged.csv \
    system_metrics/hadoop002.csv \
    system_metrics/hadoop003.csv

# 查看合并后的数据
head -n 10 system_metrics/cluster_merged.csv
```

---

## 📁 目录结构

### 远程节点 (hadoop002/hadoop003)
```
~/monitoring/
  ├── collect_metrics.sh      # 性能监测脚本
  ├── hadoop002.csv           # hadoop002的监测数据
  └── hadoop003.csv           # hadoop003的监测数据
```

### 本地节点
```
/home/ecs-user/MRApplication/reduce-startup/
  ├── metrics/                           # 批量实验结果数据
  │   ├── batch_summary_*.csv           # 实验汇总数据
  │   ├── analysis_report_*.txt         # 自动生成的分析报告
  │   └── experiment_*_timeline_*.csv   # 各个实验的时间线数据
  │
  └── system_metrics/                    # 系统性能监测数据
      ├── hadoop002.csv                  # hadoop002节点数据
      ├── hadoop003.csv                  # hadoop003节点数据
      └── cluster_merged.csv             # 合并后的集群数据
```

---

## 📊 数据文件说明

### 实验结果数据 (metrics/)

**批量实验汇总文件:** `batch_summary_*.csv`
```csv
experiment_id,slowstart_value,start_time,end_time,total_time_sec,avg_cpu_percent,max_cpu_percent,avg_memory_mb,max_memory_mb,avg_load,max_load,bytes_read,bytes_written,map_tasks,reduce_tasks,job_status
```

**分析报告文件:** `analysis_report_*.txt`
- 包含所有实验的性能分析
- slowstart参数对比
- 最优配置推荐

### 系统监测数据 (system_metrics/)

**节点监测文件:** `hadoop002.csv`, `hadoop003.csv`
```csv
node_name,timestamp,cpu_percent,memory_used_mb,memory_total_mb,memory_percent,load_avg,disk_reads,disk_writes,network_rx_mb,network_tx_mb,java_cpu_percent,java_memory_percent,java_processes
```

**列说明:**
- `node_name`: 节点名称
- `timestamp`: Unix时间戳
- `cpu_percent`: CPU使用率百分比
- `memory_used_mb`: 已使用内存(MB)
- `memory_total_mb`: 总内存(MB)
- `memory_percent`: 内存使用率百分比
- `load_avg`: 系统平均负载
- `disk_reads`: 磁盘读取次数
- `disk_writes`: 磁盘写入次数
- `network_rx_mb`: 网络接收流量(MB)
- `network_tx_mb`: 网络发送流量(MB)
- `java_cpu_percent`: Java进程CPU使用率
- `java_memory_percent`: Java进程内存使用率
- `java_processes`: Java进程数量

---

## ⚠️ 重要注意事项

### 1. SSH免密登录配置
确保当前节点可以无密码SSH到hadoop002和hadoop003:
```bash
# 生成SSH密钥(如果还没有)
ssh-keygen -t rsa -b 4096

# 将公钥复制到远程节点
ssh-copy-id hadoop002
ssh-copy-id hadoop003

# 测试免密登录
ssh hadoop002 "echo 'SSH连接成功'"
ssh hadoop003 "echo 'SSH连接成功'"
```

### 2. 磁盘空间检查
```bash
# 检查本地磁盘空间
df -h .

# 检查远程节点磁盘空间
ssh hadoop002 "df -h ~"
ssh hadoop003 "df -h ~"

# 检查HDFS空间
hdfs dfs -df -h
```

### 3. 时间同步
确保所有节点时间同步,便于数据分析:
```bash
# 检查各节点时间
date
ssh hadoop002 "date"
ssh hadoop003 "date"
```

### 4. 实验时间估算
- 5GB数据 × 5组实验 ≈ 预计总时间较长
- 每组实验间隔10秒
- 建议在空闲时段运行

### 5. 进程管理
实验结束后务必停止所有监测进程,避免:
- 持续占用CPU/内存资源
- 生成大量日志文件占用磁盘空间

---

## 🛠️ 常用命令速查

### 检查监测进程状态
```bash
# 检查所有节点的监测进程
for node in hadoop002 hadoop003; do
    echo "=== $node ==="
    ssh $node "ps aux | grep collect_metrics | grep -v grep"
done
```

### 实时查看监测数据
```bash
# 查看hadoop002最新数据
ssh hadoop002 "tail -f ~/monitoring/hadoop002.csv"

# 查看hadoop003最新数据
ssh hadoop003 "tail -f ~/monitoring/hadoop003.csv"
```

### 清理远程监测数据
```bash
# 清理hadoop002监测数据
ssh hadoop002 "rm -rf ~/monitoring/*.csv"

# 清理hadoop003监测数据
ssh hadoop003 "rm -rf ~/monitoring/*.csv"
```

### 批量停止所有监测
```bash
# 一键停止所有节点监测
for node in hadoop002 hadoop003; do
    ssh $node "pkill -f collect_metrics"
    echo "$node 监测已停止"
done
```

---

## 🎯 最佳实践建议

1. **实验前检查清单**
   - [ ] HDFS输入数据已准备
   - [ ] 本地磁盘空间充足
   - [ ] SSH免密登录配置完成
   - [ ] 所有节点时间已同步
   - [ ] 之前的实验数据已备份或清理

2. **实验中监控**
   - 定期检查监测进程是否正常运行
   - 监控磁盘空间使用情况
   - 关注实验日志输出

3. **实验后处理**
   - 及时停止所有监测进程
   - 收集并备份重要数据
   - 生成实验报告和可视化图表
   - 清理不需要的临时文件

4. **数据管理**
   - 使用时间戳命名实验数据
   - 定期备份重要实验结果
   - 建立实验日志记录习惯

---

## 📈 数据分析示例

### 使用awk分析节点性能
```bash
# 计算hadoop002的平均CPU使用率
awk -F',' 'NR>1 {sum+=$3; count++} END {print "平均CPU:", sum/count"%"}' \
    system_metrics/hadoop002.csv

# 找出hadoop003的最大内存使用
awk -F',' 'NR>1 {if($4>max) max=$4} END {print "最大内存:", max"MB"}' \
    system_metrics/hadoop003.csv
```

### 导入Python进行分析
```python
import pandas as pd

# 读取合并后的集群数据
df = pd.read_csv('system_metrics/cluster_merged.csv')

# 按节点分组统计
stats = df.groupby('node_name').agg({
    'cpu_percent': ['mean', 'max'],
    'memory_percent': ['mean', 'max'],
    'load_avg': 'mean'
})

print(stats)
```

---

## 🆘 故障排除

### 问题1: SSH连接失败
```bash
# 解决方案: 检查网络连接和SSH配置
ping hadoop002
ssh -v hadoop002
```

### 问题2: 监测脚本无法执行
```bash
# 解决方案: 检查脚本权限
ssh hadoop002 "chmod +x ~/monitoring/collect_metrics.sh"
```

### 问题3: 磁盘空间不足
```bash
# 解决方案: 清理旧数据或扩展磁盘
ssh hadoop002 "du -sh ~/monitoring/*"
ssh hadoop002 "rm -rf ~/monitoring/*.csv.old"
```

### 问题4: 数据收集失败
```bash
# 解决方案: 检查文件是否存在
ssh hadoop002 "ls -lh ~/monitoring/"
ssh hadoop002 "tail ~/monitoring/hadoop002.csv"
```

---

## 📚 相关文档

- [MULTI_NODE_USAGE.md](./MULTI_NODE_USAGE.md) - 多节点性能监测基础文档
- [README.md](../readme.md) - 项目主文档
- [visualization/README.md](../visualization/README.md) - 数据可视化文档

---

**最后更新:** 2025-11-26
**维护者:** Hadoop实验团队
