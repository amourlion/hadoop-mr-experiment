#!/usr/bin/env bash
# 仅清理远端数据目录内容（保留目录本身）
set -euo pipefail

HOSTS=(hadoop002 hadoop003)
# 需要清理的目录（可按需增减）
REMOTE_DIRS=(
  "$HOME/mapreduce_metrics"
  "$HOME/monitoring/system_metrics"
)

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

echo "[INFO] Hosts: ${HOSTS[*]}"
echo "[INFO] Dirs: ${REMOTE_DIRS[*]}"
[ $DRY_RUN -eq 1 ] && echo "[INFO] Dry-run mode (不实际删除)"

for H in "${HOSTS[@]}"; do
  echo "[INFO] === $H ==="
  for D in "${REMOTE_DIRS[@]}"; do
    if [ $DRY_RUN -eq 1 ]; then
      ssh "$H" /bin/sh -c "ls -1 ${D} 2>/dev/null | wc -l | awk '{print \"[DRY] \"$0\" files in ${D}\"}' || echo '[DRY] ${D} 不存在'"
    else
      ssh "$H" /bin/sh <<EOS
[ -d "${D}" ] || mkdir -p "${D}"
rm -rf "${D}/"* 2>/dev/null || true
echo "[REMOTE] Cleared ${D}"
EOS
    fi
  done
done

echo "[INFO] Done."
echo "[INFO] 使用: ./scripts/remote_clean_metrics.sh [--dry-run]"