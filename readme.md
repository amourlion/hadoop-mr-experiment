# Hadoop MapReduce 实验：Reduce 启动时机（Slowstart）调优

本项目用于“大规模数据处理系统”课程实验：通过调节参数 `mapreduce.job.reduce.slowstart.completedmaps` 观察 Reduce 任务启动时机对作业并行度、Shuffle 重叠度、资源利用与总耗时的影响。  
运行环境基于 Hadoop 3.2.4，示例程序为简单词频统计，可稳定复现实验现象。

---

## ✅ 性能监测系统

本项目已集成完整的性能监测系统，可自动监测CPU利用率、内存使用量、作业执行时间等关键指标，并将结果保存为CSV格式。

### 📊 监测指标
- **系统资源**: CPU利用率、内存使用量、系统负载、磁盘I/O、网络I/O
- **作业执行**: 总执行时间、Map/Reduce任务数、数据读写量
- **Java进程**: Hadoop进程专用CPU和内存占用

### 🛠 监测脚本说明

| 脚本名称 | 功能描述 |
|----------|----------|
| `monitor_job.sh` | 主监测脚本，执行单次实验并收集所有指标 |
| `collect_metrics.sh` | 后台系统资源监测脚本 |
| `process_metrics.sh` | 数据处理脚本，生成最终CSV文件 |
| `batch_experiment.sh` | 批量实验脚本，自动测试多个slowstart值 |
| `generate_report.sh` | 分析报告生成脚本 |

### 📋 使用方法

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

# 使用自动生成的上传脚本
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

## 🏗 项目结构
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

## 🧩 Git 使用速览
```bash
git init
git add .
git commit -m "Initial commit"
git remote add origin git@github.com:yourname/hadoop-mr-experiment.git
git push -u origin master
```

---
## 重启后hadoop启动

在hadoop001:

start-dfs.sh

在hadoop001：
ssh hadoop002

yarn --daemon start resourcemanager