# Hadoop MapReduce 实验：Reduce 启动时机（Slowstart）调优

本项目用于“大规模数据处理系统”课程实验：通过调节参数 `mapreduce.job.reduce.slowstart.completedmaps` 观察 Reduce 任务启动时机对作业并行度、Shuffle 重叠度、资源利用与总耗时的影响。  
运行环境基于 Hadoop 3.2.4，示例程序为简单词频统计，可稳定复现实验现象。

---

## TODO
目前这个版本只给出了一个e2e的示例，为了完成实验，还需要完成以下需求：

- 性能监测及记录(方便后继可视化)
- 给出更多示例程序
- 词频统计模拟数据集生成

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