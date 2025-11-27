#!/bin/bash

###############################################################################
# Hadoop 磁盘扩容脚本
# 功能：将阿里云100GB数据盘(/dev/vdb)格式化并挂载到Hadoop数据目录
# 作者：Automated Setup Script
# 日期：2025-11-26
###############################################################################

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 配置变量
DISK_DEVICE="/dev/vdb"
MOUNT_POINT="/hadoop_data"
HADOOP_DATA_DIR="/opt/hadoop/data/dfs"
BACKUP_DIR="/opt/hadoop/data/dfs_backup_$(date +%Y%m%d_%H%M%S)"

echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}Hadoop 磁盘扩容配置脚本${NC}"
echo -e "${GREEN}================================${NC}"
echo ""

# 检查是否以root权限运行
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}错误: 请使用root权限运行此脚本${NC}"
    echo "使用方法: sudo bash $0"
    exit 1
fi

# 1. 检查磁盘是否存在
echo -e "${YELLOW}[1/9] 检查磁盘设备...${NC}"
if [ ! -b "$DISK_DEVICE" ]; then
    echo -e "${RED}错误: 磁盘设备 $DISK_DEVICE 不存在${NC}"
    echo "可用的磁盘设备："
    lsblk
    exit 1
fi
echo -e "${GREEN}✓ 磁盘设备 $DISK_DEVICE 存在${NC}"
echo ""

# 2. 检查磁盘是否已经被挂载
echo -e "${YELLOW}[2/9] 检查磁盘挂载状态...${NC}"
if mount | grep -q "$DISK_DEVICE"; then
    echo -e "${RED}警告: $DISK_DEVICE 已经被挂载${NC}"
    mount | grep "$DISK_DEVICE"
    echo ""
    read -p "是否继续？这将卸载现有挂载 (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    umount "$DISK_DEVICE" || true
fi
echo -e "${GREEN}✓ 磁盘未被挂载，可以继续${NC}"
echo ""

# 3. 分区磁盘
echo -e "${YELLOW}[3/9] 创建磁盘分区...${NC}"
echo -e "${RED}警告: 这将删除 $DISK_DEVICE 上的所有数据！${NC}"
read -p "确认继续? (yes/no): " -r
if [ "$REPLY" != "yes" ]; then
    echo "操作已取消"
    exit 1
fi

# 使用parted创建GPT分区表和单个分区
parted -s "$DISK_DEVICE" mklabel gpt
parted -s "$DISK_DEVICE" mkpart primary ext4 0% 100%
sleep 2  # 等待分区表更新

PARTITION="${DISK_DEVICE}1"
echo -e "${GREEN}✓ 分区创建完成: $PARTITION${NC}"
echo ""

# 4. 格式化分区
echo -e "${YELLOW}[4/9] 格式化分区为ext4...${NC}"
mkfs.ext4 -F "$PARTITION"
echo -e "${GREEN}✓ 格式化完成${NC}"
echo ""

# 5. 创建挂载点
echo -e "${YELLOW}[5/9] 创建挂载点目录...${NC}"
mkdir -p "$MOUNT_POINT"
echo -e "${GREEN}✓ 挂载点创建: $MOUNT_POINT${NC}"
echo ""

# 6. 临时挂载
echo -e "${YELLOW}[6/9] 临时挂载磁盘...${NC}"
mount "$PARTITION" "$MOUNT_POINT"
echo -e "${GREEN}✓ 磁盘已挂载到 $MOUNT_POINT${NC}"
df -h "$MOUNT_POINT"
echo ""

# 7. 备份现有Hadoop数据
echo -e "${YELLOW}[7/9] 迁移现有Hadoop数据...${NC}"
if [ -d "$HADOOP_DATA_DIR" ]; then
    echo "当前Hadoop数据大小："
    du -sh "$HADOOP_DATA_DIR"
    echo ""
    echo "开始复制数据到新磁盘..."
    
    # 在新磁盘上创建hadoop数据目录
    mkdir -p "$MOUNT_POINT/dfs"
    
    # 复制数据（保留权限和属性）
    rsync -avh --progress "$HADOOP_DATA_DIR/" "$MOUNT_POINT/dfs/"
    
    # 备份原数据目录
    echo "备份原数据目录到: $BACKUP_DIR"
    mv "$HADOOP_DATA_DIR" "$BACKUP_DIR"
    
    echo -e "${GREEN}✓ 数据迁移完成${NC}"
else
    # 如果原目录不存在，直接创建新目录
    mkdir -p "$MOUNT_POINT/dfs"
    echo -e "${GREEN}✓ 创建新的Hadoop数据目录${NC}"
fi
echo ""

# 8. 创建符号链接
echo -e "${YELLOW}[8/9] 创建符号链接...${NC}"
ln -sf "$MOUNT_POINT/dfs" "$HADOOP_DATA_DIR"
echo -e "${GREEN}✓ 符号链接创建: $HADOOP_DATA_DIR -> $MOUNT_POINT/dfs${NC}"
echo ""

# 9. 配置自动挂载
echo -e "${YELLOW}[9/9] 配置开机自动挂载...${NC}"
# 获取UUID
UUID=$(blkid -s UUID -o value "$PARTITION")
echo "磁盘UUID: $UUID"

# 备份fstab
cp /etc/fstab /etc/fstab.backup.$(date +%Y%m%d_%H%M%S)

# 检查fstab中是否已存在该挂载配置
if grep -q "$MOUNT_POINT" /etc/fstab; then
    echo -e "${YELLOW}警告: /etc/fstab 中已存在 $MOUNT_POINT 的配置${NC}"
    echo "跳过添加，请手动检查配置"
else
    # 添加到fstab
    echo "UUID=$UUID $MOUNT_POINT ext4 defaults,nofail 0 2" >> /etc/fstab
    echo -e "${GREEN}✓ 已添加到 /etc/fstab${NC}"
fi
echo ""

# 10. 设置权限
echo -e "${YELLOW}[10/9] 设置目录权限...${NC}"
chown -R ecs-user:ecs-user "$MOUNT_POINT/dfs"
chmod -R 755 "$MOUNT_POINT/dfs"
echo -e "${GREEN}✓ 权限设置完成${NC}"
echo ""

# 显示最终状态
echo -e "${GREEN}================================${NC}"
echo -e "${GREEN}配置完成！${NC}"
echo -e "${GREEN}================================${NC}"
echo ""
echo "磁盘信息："
lsblk "$DISK_DEVICE"
echo ""
echo "挂载信息："
df -h "$MOUNT_POINT"
echo ""
echo "Hadoop数据目录："
ls -la "$HADOOP_DATA_DIR"
echo ""
echo -e "${GREEN}✓ 100GB磁盘已成功配置并集成到Hadoop${NC}"
echo ""
echo -e "${YELLOW}后续步骤：${NC}"
echo "1. 重启Hadoop服务以应用更改："
echo "   sudo -u ecs-user /opt/hadoop/sbin/stop-dfs.sh"
echo "   sudo -u ecs-user /opt/hadoop/sbin/start-dfs.sh"
echo ""
echo "2. 检查HDFS状态："
echo "   sudo -u ecs-user hdfs dfsadmin -report"
echo ""
echo "3. 如果一切正常，可以删除备份（可选）："
echo "   rm -rf $BACKUP_DIR"
echo ""
