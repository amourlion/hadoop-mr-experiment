# Hadoop MapReduce 实验：Reduce 启动时机（Slowstart）调优

本项目用于"大规模数据处理系统"课程实验：通过调节参数 `mapreduce.job.reduce.slowstart.completedmaps` 观察 Reduce 任务启动时机对作业并行度、Shuffle 重叠度、资源利用与总耗时的影响。  
运行环境基于 Hadoop 3.2.4，示例程序为简单词频统计，可稳定复现实验现象。

---

## 🗂️ 项目脚本概览

### 核心脚本文件结构
```
/home/ecs-user/MRApplication/reduce-startup/
├── scripts/                           # 所有脚本统一存放目录
│   ├── generate_data.py              # 🆕 统一数据生成器（支持任意大小）
│   ├── collect_metrics.sh            # 🆕 多节点系统指标收集（支持节点名参数）
│   ├── merge_node_metrics.sh         # 🆕 多节点数据合并工具
│   ├── monitor_job.sh                # ✅ 单次实验监测（已优化CSV输出）
│   ├── batch_experiment.sh           # ✅ 批量实验脚本
│   ├── process_metrics.sh            # 数据处理脚本
│   ├── generate_report.sh            # 分析报告生成脚本
│   └── test_metrics_csv.sh           # CSV格式测试脚本
├── run_scripts.sh                     # 🆕 便捷脚本执行器
├── docs/                             
│   └── MULTI_NODE_USAGE.md           # 🆕 多节点使用指南
└── metrics/                          # CSV数据输出目录
    ├── experiment_*.csv              # 单次实验结果
    ├── batch_summary_*.csv           # 批量实验汇总
    └── *.csv                        # 各节点系统指标文件
```

### 🚀 快速开始
```bash
# 查看所有可用脚本
./run_scripts.sh

# 生成测试数据
./run_scripts.sh generate_data.py 100  # 生成100MB数据

# 运行单次实验
./run_scripts.sh monitor_job.sh 0.3

# 运行批量实验
./run_scripts.sh batch_experiment.sh

# 多节点数据收集（详见docs/MULTI_NODE_USAGE.md）
./run_scripts.sh collect_metrics.sh master 1
./run_scripts.sh merge_node_metrics.sh cluster_metrics.csv master.csv worker*.csv
```

---

## ✅ 性能监测系统

本项目已集成完整的性能监测系统，支持单节点和多节点Hadoop集群的性能数据收集，并将结果保存为标准化CSV格式。

### 📊 数据表格规范

#### 🕐 性能监测表（时序数据）- System Metrics CSV
用于记录系统资源的时序变化，文件命名：`{节点名}.csv`

| 列名 | 数据类型 | 单位 | 含义说明 |
|------|----------|------|----------|
| `node_name` | string | - | 节点名称标识（如master、worker01等） |
| `timestamp` | integer | seconds | Unix时间戳，数据采集时刻 |
| `cpu_percent` | float | % | CPU整体使用率（0-100） |
| `memory_used_mb` | integer | MB | 已使用内存大小 |
| `memory_total_mb` | integer | MB | 系统总内存大小 |
| `memory_percent` | float | % | 内存使用率（0-100） |
| `load_avg` | float | - | 系统1分钟平均负载 |
| `disk_reads` | integer | ops | 累计磁盘读操作次数 |
| `disk_writes` | integer | ops | 累计磁盘写操作次数 |
| `network_rx_mb` | float | MB | 累计网络接收流量 |
| `network_tx_mb` | float | MB | 累计网络发送流量 |
| `java_cpu_percent` | float | % | Hadoop Java进程CPU使用率 |
| `java_memory_percent` | float | % | Hadoop Java进程内存使用率 |
| `java_processes` | integer | count | 活跃的Hadoop进程数量 |

**示例数据：**
```csv
node_name,timestamp,cpu_percent,memory_used_mb,memory_total_mb,memory_percent,load_avg,disk_reads,disk_writes,network_rx_mb,network_tx_mb,java_cpu_percent,java_memory_percent,java_processes
master,1764038886,3.2,1414,7658,18.5,0.06,0,0,0,0,0,0,0
worker01,1764038887,25.4,2048,4096,50.0,1.25,145,67,12.5,8.3,18.7,15.2,3
```

#### 📈 实验结果表（对比数据）- Experiment Results CSV
用于记录不同实验配置的结果对比，文件命名：`experiment_{实验ID}_slowstart_{值}.csv`

| 列名 | 数据类型 | 单位 | 含义说明 |
|------|----------|------|----------|
| `experiment_id` | string | - | 实验唯一标识符（通常为时间戳） |
| `slowstart_value` | float | - | MapReduce慢启动参数值（0.0-1.0） |
| `start_time` | integer | seconds | 实验开始时间戳 |
| `end_time` | integer | seconds | 实验结束时间戳 |
| `total_time_sec` | integer | seconds | 作业总执行时间 |
| `avg_cpu_percent` | float | % | 实验期间平均CPU使用率 |
| `max_cpu_percent` | float | % | 实验期间最大CPU使用率 |
| `avg_memory_mb` | float | MB | 实验期间平均内存使用量 |
| `max_memory_mb` | float | MB | 实验期间最大内存使用量 |
| `avg_load` | float | - | 实验期间平均系统负载 |
| `max_load` | float | - | 实验期间最大系统负载 |
| `bytes_read` | long | bytes | 作业读取的总数据量 |
| `bytes_written` | long | bytes | 作业写入的总数据量 |
| `map_tasks` | integer | count | Map任务总数 |
| `reduce_tasks` | integer | count | Reduce任务总数 |
| `job_status` | string | - | 作业执行状态（SUCCESS/FAILED） |

**示例数据：**
```csv
experiment_id,slowstart_value,start_time,end_time,total_time_sec,avg_cpu_percent,max_cpu_percent,avg_memory_mb,max_memory_mb,avg_load,max_load,bytes_read,bytes_written,map_tasks,reduce_tasks,job_status
20231124_143000,0.3,1700812200,1700812220,20,45.2,78.5,1024,1456,0.85,2.14,1073741824,52428800,8,2,SUCCESS
20231124_143500,0.7,1700812500,1700812528,28,42.1,68.3,998,1289,0.72,1.89,1073741824,52428800,8,2,SUCCESS
```

### 📋 标准规范（供其他子项目参考）

#### 1. 文件命名规范
- **系统指标**: `{节点名}.csv` （如：master.csv, worker01.csv）
- **实验结果**: `experiment_{实验ID}_slowstart_{值}.csv`
- **批量汇总**: `batch_summary_{时间戳}.csv`
- **集群合并**: `cluster_{实验ID}.csv`

#### 2. 数据格式要求
- **时间戳**: 使用Unix时间戳（秒级精度）
- **百分比**: 使用0-100范围的浮点数
- **内存/存储**: 统一使用MB或bytes单位
- **字符串**: 使用英文，避免特殊字符
- **布尔值**: 使用SUCCESS/FAILED等明确字符串

#### 3. CSV文件要求
- **编码**: UTF-8
- **分隔符**: 英文逗号（,）
- **表头**: 第一行必须为列名
- **无空行**: 数据行之间不允许空行
- **数值精度**: 浮点数保留1-2位小数

#### 4. 多节点数据合并
- 所有节点的CSV文件必须具有相同的列结构
- 第一列必须为`node_name`以便区分数据来源
- 合并后按`timestamp`排序便于时序分析
- 使用`scripts/merge_node_metrics.sh`进行标准化合并

### � 使用方法

#### 1. 单次实验监测
```bash
# 基本用法 - 使用默认参数
./monitor_job.sh

# 指定slowstart值
./monitor_job.sh 0.3

# 完整参数
./monitor_job.sh 0.3 /mr_input /mr_output_03 experiment_001
```

**参数说明:**
- `slowstart_value`: Reduce慢启动值 (0.1-1.0)
- `input_path`: HDFS输入路径 (默认: /mr_input)
- `output_path`: HDFS输出路径 (默认: /mr_output)
- `experiment_id`: 实验标识符 (默认: 自动生成时间戳)

#### 2. 批量实验
```bash
# 运行预设的slowstart值 (0.1, 0.3, 0.5, 0.7, 1.0)
./batch_experiment.sh

# 指定输入输出路径
./batch_experiment.sh /mr_input /mr_output_batch
```

#### 3. 手动运行系统监测
```bash
# 后台监测系统资源，每秒采集一次
./collect_metrics.sh system_metrics.tmp &

# 停止监测
kill %1  # 或使用具体的PID
```

### 📁 输出文件说明

#### CSV文件格式
监测脚本生成的CSV文件包含以下列：

```csv
experiment_id,slowstart_value,start_time,end_time,total_time_sec,
avg_cpu_percent,max_cpu_percent,avg_memory_mb,max_memory_mb,
avg_load,max_load,bytes_read,bytes_written,map_tasks,reduce_tasks,job_status
```

#### 文件结构
```
metrics/
├── experiment_<id>_slowstart_<value>.csv    # 单次实验结果
├── batch_summary_<timestamp>.csv            # 批量实验汇总
├── analysis_report_<timestamp>.txt          # 分析报告
└── system_<id>.tmp                         # 临时系统指标文件
```

### 🔍 输出示例

#### 单次实验输出
```bash
=== Hadoop MapReduce Performance Monitor ===
Experiment ID: 20231124_143000
Slowstart Value: 0.3
Input Path: /mr_input
Output Path: /mr_output_03

Starting system resource monitoring...
Updating slowstart value to 0.3...
Compiling project...
Starting Hadoop job at Mon Nov 24 14:30:05 CST 2023...
Job completed at Mon Nov 24 14:30:25 CST 2023
Total execution time: 20 seconds

=== Experiment Summary ===
Experiment ID: 20231124_143000
Slowstart Value: 0.3
Total Time: 20 seconds
Job Status: SUCCESS
Metrics saved to: metrics/experiment_20231124_143000_slowstart_0.3.csv
```

#### 批量实验分析表格
```
Slowstart | Total Time | Avg CPU | Max Memory | Status
----------|------------|---------|------------|--------
0.1       | 25s        | 45.2%   | 1024MB     | SUCCESS
0.3       | 20s        | 52.8%   | 1156MB     | SUCCESS
0.5       | 22s        | 48.1%   | 1089MB     | SUCCESS
0.7       | 24s        | 44.3%   | 998MB      | SUCCESS
1.0       | 28s        | 41.7%   | 945MB      | SUCCESS
```

---

## 📦 大数据集生成器

为了获得更明显的性能差异，项目提供了大数据集生成工具。

### 🎯 数据集特点
- **可配置大小**: 支持生成任意大小的数据集 (默认1GB)
- **真实内容**: 包含Hadoop/大数据相关词汇，模拟真实场景
- **多文件分布**: 自动拆分为多个文件，便于并行处理
- **结构化数据**: 30%结构化模式 + 70%随机内容，提供丰富的reduce操作

### 📋 使用方法

#### 生成1GB数据集 (推荐)
```bash
# 基本用法 - 生成1GB数据集，4个文件
./generate_dataset.py

# 指定大小和文件数
./generate_dataset.py --size 2.0 --files 8

# 完整参数
./generate_dataset.py --size 1.5 --files 6 --output input-custom --prefix dataset
```

#### 参数说明
- `--size`: 数据集大小 (GB) (默认: 1.0)
- `--files`: 文件数量 (默认: 4)
- `--output`: 输出目录 (默认: input-large)
- `--prefix`: 文件前缀 (默认: data)

#### 上传到HDFS
```bash
# 切换到数据集目录
cd input-large

# 使用自动生成的上传脚本cd
./upload_to_hdfs.sh

# 或指定HDFS路径
./upload_to_hdfs.sh /mr_input_1gb
```

### 🔄 完整实验流程

#### 1. 生成大数据集
```bash
./generate_dataset.py --size 1.0 --files 4
cd input-large && ./upload_to_hdfs.sh /mr_input_large
```

#### 2. 使用大数据集进行监测实验
```bash
# 单次实验
./monitor_job.sh 0.3 /mr_input_large /mr_output_large_03
./monitor_job.sh 0.3 /mr_input_zg /mr_output_zg

# 批量实验
./batch_experiment.sh /mr_input_large /mr_output_large
```

#### 3. 预期效果
使用1GB数据集后，你应该能观察到：
- **更明显的性能差异**: 不同slowstart值的影响更加显著
- **更长的执行时间**: 便于观察各阶段的资源使用模式
- **更多Map/Reduce任务**: 提供更丰富的并行度分析数据
- **更真实的资源竞争**: 更好地反映生产环境特征

## TODO
目前版本已完成核心功能：

- ✅ 性能监测及记录(CSV格式)
- ✅ 大数据集生成工具
- 给出更多示例程序 (待实现)

---

## ✨ 目标
- 理解 Reduce 慢启动机制（Slowstart）
- 掌握参数 `mapreduce.job.reduce.slowstart.completedmaps` 的调优效果
- 采集不同设置下的作业执行时间与阶段行为
- 分析 Map / Shuffle / Reduce 的并行关系及资源利用

---

## 🏗 Hadoop工程项目结构
```
reduce-startup/
├── src/
│   └── main/java/edu/example/mapreduce/
│       ├── Main.java        # Job 提交与参数设置
│       ├── MapperA.java     # Map 实现
│       └── ReducerA.java    # Reduce 实现
├── pom.xml                  # Maven 构建
├── .gitignore
└── README.md
```

---

## 🧰 环境依赖
| 组件 | 版本建议 |
|------|----------|
| Hadoop | 3.2.4 |
| Java | OpenJDK 8|
| Maven | 3.6 |
| OS | Ubuntu 20.04 |

---

## ⚙️ Hadoop 基础检查
```bash
hadoop version
```
确保输出中版本为 3.2.4。

---

## 📂 准备输入数据（仅首次）
```bash
hdfs dfs -mkdir -p /mr_input

echo "hello hadoop hello mapreduce" > data1.txt
echo "hello world mapreduce experiment" > data2.txt
hdfs dfs -put -f data1.txt data2.txt /mr_input
```

---

## 🔧 编译打包
```bash
mvn clean package -DskipTests
```
生成 Fat JAR：
```
target/reduce-startup-1.0-SNAPSHOT-jar-with-dependencies.jar
```

---

## 🚀 运行示例
```bash
hadoop jar target/reduce-startup-1.0-SNAPSHOT-jar-with-dependencies.jar \
    /mr_input /mr_output_01
```
查看结果：
```bash
hdfs dfs -ls /mr_output_01
hdfs dfs -cat /mr_output_01/part-r-00000
```

---

## 🧪 核心参数：Reduce 慢启动
在 `Main.java` 中：
```java
conf.setFloat("mapreduce.job.reduce.slowstart.completedmaps", 0.3f);
```
含义：当指定比例的 Map 完成后允许调度 Reduce（进入 Shuffle / Fetch）。

推荐实验组合：
| 编号 | slowstart 值 | 描述 |
|------|--------------|------|
| A1 | 0.1 | 极早启动，可能空转等待 Map 输出 |
| A2 | 0.3 | 适度提前，增加 Shuffle 与 Map 重叠 |
| A3 | 0.7 | 偏晚，Map 集中占资源 |
| A4 | 1.0 | 串行倾向，Map 全部完成后才启动 Reduce |

---

## 🧪 实验步骤（对每个值重复）
1. 修改参数  
   编辑 `Main.java`：
   ```java
   conf.setFloat("mapreduce.job.reduce.slowstart.completedmaps", 0.7f);
   ```
2. 重新打包  
   ```bash
   mvn clean package -DskipTests
   ```
3. 选择新的输出目录（避免已存在导致失败）  
   ```bash
   hdfs dfs -rm -r -f /mr_output_07
   ```
4. 运行并计时  
   ```bash
   time hadoop jar target/reduce-startup-1.0-SNAPSHOT-jar-with-dependencies.jar \
        /mr_input /mr_output_07
   ```
   记录 `real` 时间。
5. 采集指标  
   - 控制台：Map / Reduce 进度条、Shuffle 阶段开始时间  
   - YARN UI: `http://<ResourceManager>:8088` → Application → Attempts  
   - JobHistory（若开启）：`http://<HistoryServer>:19888/jobhistory`  
   - `mapreduce.task.io.sort.mb`/并行度可辅助解释差异
6. 整理结果入表（示例）：

| slowstart | Reduce 实际启动点 (Map 完成 %) | Shuffle 重叠度 | 总时间 (s) | 观察 |
|-----------|-------------------------------|----------------|-----------|------|
| 0.1 | ~10% | 高 | ? | Reduce 早，可能无数据空轮询 |
| 0.3 | ~30% | 中高 | ? | 常见较优折中 |
| 0.7 | ~70% | 低 | ? | 资源倾向 Map |
| 1.0 | 100% | 最低 | ? | 近似串行 |

填写 ? 为实测值。

---

## 📊 进一步分析建议
- 对比各配置下：
  - Map 阶段平均 CPU 利用率（使用 `top` / `yarn node -list` / 监控）
  - Shuffle Fetch 等待时间（Reduce Task 日志中 FetchStarted vs FirstMapOutputFetched）
  - Spill 次数与 Merge 时间（Map Task 日志）
- 可写脚本批量运行：
  ```bash
  for v in 0.1 0.3 0.7 1.0; do
    sed -i "s/slowstart.completedmaps\", [0-9.]\+/slowstart.completedmaps\", $v/" \
        src/main/java/edu/example/mapreduce/Main.java
    mvn -q package -DskipTests
    out=/mr_output_${v//./}
    hdfs dfs -rm -r -f $out
    echo "== slowstart = $v =="
    /usr/bin/time -f "%E" hadoop jar target/reduce-startup-1.0-SNAPSHOT-jar-with-dependencies.jar /mr_input $out
  done
  ```
  将时间汇总至 CSV。

---

## 🛠 常见问题
| 问题 | 处理 |
|------|------|
| 输出目录存在 | 先 `hdfs dfs -rm -r -f /mr_output_xx` |
| ClassNotFound | 确认使用带依赖的 JAR |
| 权限错误 | 检查 HDFS 目录 owner 与 `hadoop fs -chmod` |
| Reduce 不启动 | slowstart=1.0 等待全部 Map 完成属正常 |
| 任务卡住 | 查看 NodeManager 日志、磁盘是否满 |

---

### 🧩 Git 使用速览
```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin git@github.com:yourname/hadoop-mr-experiment.git
git push -u origin master
```

---
### 重启后hadoop启动

在hadoop001:

start-dfs.sh

ssh hadoop002

start-yarn.sh

exit

## hadoop面板查看

hadoop001:9870 是文件管理系统的面板

hadoop002:8088 是分布式任务面板

## 🛠 常见问题
### 大数据崩溃问题
cd /opt/hadoop/etc/hadoop  进入配置文件目录下

在 mapred-site.xml 加入
'''
<!-- Map 任务内存（根据最弱节点 4G 规划）-->
    <property>
        <name>mapreduce.map.memory.mb</name>
        <value>1024</value>
    </property>
    <property>
        <name>mapreduce.map.java.opts</name>
        <value>-Xmx820m</value>
    </property>

    <!-- Reduce 任务内存（约 2G） -->
    <property>
        <name>mapreduce.reduce.memory.mb</name>
        <value>2048</value>
    </property>
    <property>
        <name>mapreduce.reduce.java.opts</name>
        <value>-Xmx1640m</value>
    </property>

    <!-- Shuffle IO -->
    <property>
        <name>mapreduce.task.io.sort.mb</name>
        <value>256</value>
    </property>

    <!-- 每个节点并行任务数量（由 CPU 决定） -->
    <property>
        <name>mapreduce.tasktracker.map.tasks.maximum</name>
        <value>3</value>
    </property>
    <property>
        <name>mapreduce.tasktracker.reduce.tasks.maximum</name>
        <value>2</value>
    </property>
'''

在 yarn-site.xml 加入
'''
<!-- 以下新增 -->
    <property>
        <name>yarn.nodemanager.resource.memory-mb</name>
        <value>6144</value> <!-- 给 4C8G 节点 -->
    </property>

    <!-- CPU Core 数 -->
    <property>
        <name>yarn.nodemanager.resource.cpu-vcores</name>
        <value>4</value>
    </property>

    <!-- Container 最小和最大内存 -->
    <property>
        <name>yarn.scheduler.minimum-allocation-mb</name>
        <value>512</value>
    </property>

    <property>
        <name>yarn.scheduler.maximum-allocation-mb</name>
        <value>4096</value>
    </property>
'''
