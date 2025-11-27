# MapReduce PID 监控脚本使用指南

## 概述

`collect_mapreduce_metrics.sh` 是一个独立的MapReduce进程监控脚本，专门用于实时监控MRAppMaster和YarnChild进程的性能指标。该脚本使用pidstat工具收集进程级别的CPU、内存和I/O数据。

## 功能特性

- **智能进程发现**: 自动发现并监控MRAppMaster和YarnChild进程
- **实时监控**: 使用pidstat实时收集进程性能数据
- **自适应扫描**: 无进程时低频扫描，有进程时高频监控
- **跨节点兼容**: 适用于Master和Worker节点
- **独立运行**: 不依赖batch实验脚本，用户手动控制
- **生命周期管理**: 自动处理进程启动和结束事件

## 系统要求

### 必需软件包
- **sysstat**: 提供pidstat命令
```bash
# CentOS/RHEL/Amazon Linux
sudo yum install sysstat

# Ubuntu/Debian  
sudo apt-get install sysstat
```

### Java环境
- 已配置的Hadoop/YARN环境
- 可用的`jps`命令

## 使用方法

### 基本语法
```bash
./collect_mapreduce_metrics.sh <node_name> [scan_interval]
```

### 参数说明
- `node_name`: **必需** - 节点名称，用于标识输出文件
- `scan_interval`: **可选** - 无进程时的扫描间隔（秒），默认5秒

### 使用示例

#### 在三个节点上启动监控
```bash
# 在hadoop001上启动
./scripts/collect_mapreduce_metrics.sh hadoop001 5 &

# 在hadoop002上启动  
./scripts/collect_mapreduce_metrics.sh hadoop002 5 &

# 在hadoop003上启动
./scripts/collect_mapreduce_metrics.sh hadoop003 5 &
```

#### 自定义扫描间隔
```bash
# 使用3秒扫描间隔
./scripts/collect_mapreduce_metrics.sh hadoop001 3 &
```

#### 停止监控
```bash
# 停止所有监控进程
pkill -f collect_mapreduce_metrics.sh

# 或者使用Ctrl+C停止前台运行的脚本
```

## 输出文件

### 文件结构
监控脚本会在当前目录下创建`mapreduce_metrics/`目录，包含以下文件：

```
mapreduce_metrics/
├── {node_name}_mrapp_{timestamp}.txt        # MRAppMaster原始监控数据
├── {node_name}_mrapp_{timestamp}.csv        # MRAppMaster CSV格式数据
├── {node_name}_mrapp_{timestamp}.txt.header # MRAppMaster监控头信息
├── {node_name}_yarnchild_{timestamp}.txt    # YarnChild原始监控数据
├── {node_name}_yarnchild_{timestamp}.csv    # YarnChild CSV格式数据
├── {node_name}_yarnchild_{timestamp}.txt.header # YarnChild监控头信息
└── {node_name}_process_discovery_{timestamp}.log # 进程发现日志
```

**注意：** 监控结束时，脚本会自动调用Python脚本将pidstat原始输出转换为结构化的CSV格式，便于后续分析。

### 文件命名规则
- **时间戳格式**: `YYYYMMDD_HHMMSS`
- **节点标识**: 使用用户指定的node_name
- **进程类型**: mrapp (MRAppMaster) 或 yarnchild (YarnChild)

### 数据格式

#### pidstat原始输出格式 (.txt文件)
```
Linux 3.10.0 (hostname)    11/26/25    _x86_64_    (4 CPU)

16:23:45      UID       PID    %usr   %system  %guest    %CPU   CPU  Command
16:23:46        0     12345   15.00     5.00    0.00   20.00     1  java
```

#### CSV格式输出 (.csv文件)
```csv
# CPU Metrics
timestamp,uid,pid,usr_pct,system_pct,guest_pct,wait_pct,cpu_pct,cpu_core,command
04:31:04 PM,1000,832666,1.00,0.00,0.00,0.00,1.00,4,java

# Memory Metrics  
timestamp,uid,pid,minflt_per_s,majflt_per_s,vsz_kb,rss_kb,mem_pct,command
04:31:04 PM,1000,832666,2062.00,0.00,7249364,190860,1.21,java

# I/O Metrics
timestamp,uid,pid,kb_rd_per_s,kb_wr_per_s,kb_ccwr_per_s,iodelay,command
04:31:04 PM,1000,832666,0.00,20568.00,0.00,0,java
```

#### 头信息文件内容 (.txt.header文件)
```
# MRAppMaster Process Monitoring - Node: hadoop001
# Started at: Tue Nov 26 16:23:45 CST 2025
# PIDs: 12345
```

## 监控指标详解

### pidstat输出格式说明

pidstat输出包含三个部分，分别对应CPU、内存和I/O监控：

#### **1. CPU监控指标 (-u参数)**
```
04:32:39 PM   UID       PID    %usr %system  %guest   %wait    %CPU   CPU  Command
04:32:40 PM  1000    843659  206.00   12.00    0.00    0.00  218.00     3  java
```

**列名含义：**
- **Time**: 采样时间戳
- **UID**: 用户ID (1000通常是普通用户)
- **PID**: 进程ID
- **%usr**: 用户态CPU使用率 (用户空间代码执行时间百分比)
- **%system**: 内核态CPU使用率 (系统调用和内核代码执行时间百分比)  
- **%guest**: 虚拟CPU时间百分比 (虚拟化环境中)
- **%wait**: 等待I/O的CPU时间百分比
- **%CPU**: **总CPU使用率** (%usr + %system + %guest)
- **CPU**: 当前使用的CPU核心编号 (0-7表示8核CPU)
- **Command**: 进程命令名

**重要说明：** %CPU可能超过100%，因为Java进程是多线程的，在多核CPU上可能同时使用多个CPU核心。

#### **2. 内存监控指标 (-r参数)**
```
04:32:39 PM   UID       PID  minflt/s  majflt/s     VSZ     RSS   %MEM  Command
04:32:40 PM  1000    843659  13063.00      0.00 7238944  183416   1.16  java
```

**列名含义：**
- **minflt/s**: 每秒minor page faults数量 (页面在内存中但需要重新映射)
- **majflt/s**: 每秒major page faults数量 (页面需要从磁盘加载)
- **VSZ**: 虚拟内存大小(KB) - 进程虚拟地址空间总大小
- **RSS**: 物理内存使用(KB) - Resident Set Size，实际占用的物理内存
- **%MEM**: 物理内存使用百分比 (RSS/总内存*100)
- **Command**: 进程命令名

**性能提示：**
- **高minflt/s**: 正常，表示内存访问活跃
- **高majflt/s**: 可能表示内存不足，需要频繁从磁盘swap
- **VSZ vs RSS**: VSZ通常比RSS大很多，VSZ包含了所有虚拟内存映射

#### **3. I/O监控指标 (-d参数)**
```
04:32:39 PM   UID       PID   kB_rd/s   kB_wr/s kB_ccwr/s iodelay  Command
04:32:40 PM  1000    843659      0.00    256.00      4.00       0  java
```

**列名含义：**
- **kB_rd/s**: 每秒读取的KB数 (从磁盘读取)
- **kB_wr/s**: 每秒写入的KB数 (写入磁盘)  
- **kB_ccwr/s**: 每秒cancelled write KB数 (被取消的写入操作)
- **iodelay**: I/O延迟 (等待I/O完成的时间，单位：时钟周期)
- **Command**: 进程命令名

**MapReduce场景分析：**
- **Map阶段**: kB_rd/s较高 (读取输入数据)
- **Shuffle阶段**: kB_rd/s和kB_wr/s都较高 (读写中间数据)
- **Reduce阶段**: kB_wr/s较高 (写入最终结果)

## 工作模式

### 发现模式
- **触发条件**: 没有MapReduce进程运行时
- **行为**: 每隔`scan_interval`秒扫描一次进程
- **日志**: 记录"No MapReduce processes found"

### 监控模式  
- **触发条件**: 发现MRAppMaster或YarnChild进程时
- **行为**: 每秒收集一次性能数据
- **处理**: 自动处理进程结束事件

### 进程生命周期管理
```
进程发现 → 启动pidstat监控 → 持续数据收集 → 进程结束检测 → 停止监控 → 返回发现模式
```

## 监控策略建议

### Master节点 (hadoop001)
重点监控：
- **MRAppMaster**: 作业协调性能
- **YarnChild**: 如果有计算任务分配到此节点

### Worker节点 (hadoop002, hadoop003)  
重点监控：
- **YarnChild**: Map/Reduce任务执行性能
- **MRAppMaster**: 如果调度到此节点

### 监控时机
- **实验前启动**: 在运行MapReduce作业前启动监控
- **后台运行**: 使用&符号后台运行
- **实验后停止**: 实验完成后手动停止或自动结束

## 故障排除

### 常见错误

#### pidstat命令未找到
```bash
Error: pidstat not found. Please install sysstat package
```
**解决方案**: 安装sysstat包

#### 权限问题
```bash
Permission denied
```  
**解决方案**: 确保脚本有执行权限
```bash
chmod +x scripts/collect_mapreduce_metrics.sh
```

#### 磁盘空间不足
**现象**: 监控数据文件创建失败
**解决方案**: 清理旧的监控数据或扩展磁盘空间

### 调试方法

#### 查看日志文件
```bash
tail -f mapreduce_metrics/{node_name}_process_discovery_*.log
```

#### 手动测试进程发现
```bash  
jps | grep -E "(MRAppMaster|YarnChild)"
```

#### 检查pidstat可用性
```bash
pidstat -V
```

## 与现有工具集成

### 与batch实验脚本配合使用
1. 启动MapReduce监控脚本
2. 运行batch实验脚本  
3. 实验完成后收集监控数据
4. 停止监控脚本

### 数据分析
监控数据可以与以下工具配合分析：
- 现有的`merge_node_metrics.sh`脚本
- 时间线可视化工具
- 性能分析报告生成器

## 最佳实践

1. **提前启动**: 在MapReduce作业开始前启动监控
2. **合理间隔**: 根据实验持续时间调整扫描间隔
3. **资源考虑**: 监控本身会消耗少量系统资源
4. **数据管理**: 定期清理旧的监控数据文件
5. **多节点协调**: 确保所有相关节点都启动了监控

## 输出数据分析示例

### 识别Map/Reduce阶段
- **Map阶段**: 大量YarnChild进程启动，I/O密集
- **Shuffle阶段**: 网络活动增加，部分进程结束  
- **Reduce阶段**: 新YarnChild进程，内存使用增加

### 性能瓶颈识别
- **CPU瓶颈**: %CPU持续接近100%
- **内存瓶颈**: RSS接近系统限制
- **I/O瓶颈**: kB_rd/s, kB_wr/s异常高

### 节点负载对比
