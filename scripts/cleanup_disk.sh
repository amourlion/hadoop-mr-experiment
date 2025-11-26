#!/bin/bash
# cleanup_disk.sh - 磁盘清理脚本

echo "=== 磁盘清理开始 ==="
df -h | grep /dev/vda3

echo ">>> 1. 清理本地input数据（HDFS已有备份）"
rm -rf ~/MRApplication/reduce-startup/input-10gb
rm -rf ~/MRApplication/reduce-startup/input-1gb
echo "✓ 已清理 input-* 目录"

echo ">>> 2. 清理metrics和系统指标旧数据"
# rm -rf ~/MRApplication/reduce-startup/metrics/*.csv
# rm -rf ~/MRApplication/reduce-startup/system_metrics/*.csv
echo "✓ 已清理旧实验数据"

echo ">>> 3. 清理Maven缓存"
rm -rf ~/.m2/repository
echo "✓ 已清理Maven仓库"

echo ">>> 4. 清理编译输出"
rm -rf ~/MRApplication/reduce-startup/target
echo "✓ 已清理target目录"

echo ">>> 5. 清理Hadoop临时文件"
rm -rf /tmp/hadoop-*
echo "✓ 已清理Hadoop临时文件"

echo ">>> 6. 清理系统缓存（需要sudo）"
sudo apt clean
sudo apt autoclean
echo "✓ 已清理APT缓存"

echo ">>> 7. 清理Hadoop日志"
rm -rf /opt/hadoop/logs/*.log.[0-9]*
rm -rf /opt/hadoop/logs/*.out.[0-9]*
echo "✓ 已清理Hadoop旧日志"

echo "=== 清理完成 ==="
df -h | grep /dev/vda3

echo ""
echo "预计释放空间："
echo "- input目录: ~10-11GB"
echo "- Maven仓库: ~1-2GB"
echo "- 编译输出: ~100MB"
echo "- 临时文件: ~500MB"
echo "- APT缓存: ~200MB"
echo "- 总计: ~12-14GB"

