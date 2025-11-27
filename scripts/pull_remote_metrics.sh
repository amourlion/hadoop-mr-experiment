#!/usr/bin/env bash
# 使用 scp 从远程节点拉取 mapreduce_metrics 与 system_metrics 数据
set -euo pipefail

HOSTS=(hadoop002 hadoop003)
TS=$(date +%Y%m%d_%H%M%S)
BASE_DIR="remote_metrics_${TS}"

mkdir -p "$BASE_DIR"

for H in "${HOSTS[@]}"; do
  echo "[INFO] Pulling $H"
  TARGET="$BASE_DIR/$H"
  mkdir -p "$TARGET"
  # 拉取 MapReduce 指标目录
  scp -r "$H:~/mapreduce_metrics" "$TARGET/" 2>/dev/null || {
    echo "[WARN] $H mapreduce_metrics 空或不存在"
    mkdir -p "$TARGET/mapreduce_metrics"
  }
  # 拉取系统指标目录
  scp -r "$H:~/monitoring/system_metrics" "$TARGET/" 2>/dev/null || {
    echo "[WARN] $H system_metrics 空或不存在"
    mkdir -p "$TARGET/system_metrics"
  }
done

echo "[INFO] 完成，本地目录: $BASE_DIR"