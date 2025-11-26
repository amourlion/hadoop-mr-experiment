# 快速开始：自动化多节点监控

## 🚀 一键执行

```bash
# 执行批量实验（自动完成所有监控任务）
./scripts/batch_experiment.sh /mr_input_5gb /mr_output
```

## ✅ 前提条件检查

```bash
# 1. 测试 SSH 连接
ssh hadoop002 "echo 'OK'"
ssh hadoop003 "echo 'OK'"

# 2. 检查磁盘空间
df -h .
ssh hadoop002 "df -h ~"
ssh hadoop003 "df -h ~"

# 3. 验证脚本存在
ls -la scripts/batch_experiment.sh
ls -la scripts/collect_metrics.sh
```

## 📋 自动化功能

脚本会自动完成：

1. ✅ 部署监控脚本到 hadoop002 和 hadoop003
2. ✅ 启动远程节点监控进程
3. ✅ 执行批量 MapReduce 实验
4. ✅ 停止远程监控进程
5. ✅ 收集所有节点的监控数据到本地

## 📁 结果文件位置

```
metrics/                    # 实验结果
├── batch_summary_*.csv    # 批量实验汇总
└── analysis_report_*.txt  # 分析报告

system_metrics/            # 监控数据
├── hadoop002_*.csv        # hadoop002 数据
└── hadoop003_*.csv        # hadoop003 数据
```

## 🔧 自定义配置

如需修改监控节点，编辑 `scripts/batch_experiment.sh`：

```bash
# 第18行：修改节点列表
REMOTE_NODES=("hadoop002" "hadoop003")

# 第19行：修改远程目录
REMOTE_MONITOR_DIR="~/monitoring"

# 第20行：修改采集间隔（秒）
MONITOR_INTERVAL=1
```

## ⚠️ 常见问题

**Q: SSH 连接失败？**
```bash
ssh-copy-id hadoop002
ssh-copy-id hadoop003
```

**Q: 如何停止失控的监控进程？**
```bash
ssh hadoop002 "pkill -f collect_metrics"
ssh hadoop003 "pkill -f collect_metrics"
```

**Q: 如何查看实时监控？**
```bash
ssh hadoop002 "ps aux | grep collect_metrics"
```

## 📚 详细文档

- [自动化多节点监控完整指南](./automated_multi_node_monitoring.md)
- [手动多节点监控方案](./multi_node_monitoring_usage.md)

---

**提示：** 确保已配置 SSH 免密码登录后再执行！
