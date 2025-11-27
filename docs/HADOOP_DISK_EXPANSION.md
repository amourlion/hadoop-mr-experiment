# Hadoop 磁盘扩容指南

## 📋 概述

本文档详细说明如何将阿里云ECS上的100GB数据盘挂载并集成到Hadoop集群中，扩展HDFS存储容量。

## 🔍 当前状态

### 磁盘信息
- **设备名称**: `/dev/vdb`
- **容量**: 100 GiB
- **类型**: ESSD AutoPL 云盘
- **IOPS**: 6800
- **状态**: 已挂载到实例 i-bp17ue5tnwdnupp4di68 (hadoop001)
- **设备名**: `/dev/xvdb` (阿里云显示) / `/dev/vdb` (系统内)

### Hadoop当前配置
- **数据目录**: `/opt/hadoop/data/dfs`
- **当前使用**: 19GB
- **系统根分区**: `/dev/vda3` (40GB, 87%已用)
- **问题**: 根分区空间紧张，需要扩容

## 🚀 快速开始

### 一键执行脚本

```bash
# 以root权限执行自动化脚本
sudo bash scripts/setup_hadoop_disk.sh
```

脚本会自动完成以下操作：
1. ✅ 检查磁盘设备 `/dev/vdb`
2. ✅ 创建GPT分区表和分区
3. ✅ 格式化为ext4文件系统
4. ✅ 挂载到 `/hadoop_data`
5. ✅ 迁移现有Hadoop数据（19GB）
6. ✅ 创建符号链接
7. ✅ 配置开机自动挂载
8. ✅ 设置正确的权限

### 重启Hadoop服务

```bash
# 停止HDFS服务
sudo -u ecs-user /opt/hadoop/sbin/stop-dfs.sh

# 启动HDFS服务
sudo -u ecs-user /opt/hadoop/sbin/start-dfs.sh
```

### 验证配置

```bash
# 检查磁盘挂载
df -h /hadoop_data

# 检查HDFS状态
sudo -u ecs-user hdfs dfsadmin -report

# 检查数据目录
ls -la /opt/hadoop/data/dfs
```

## 📝 详细步骤说明

### 步骤1: 检查磁盘状态

```bash
# 查看所有块设备
lsblk

# 预期输出：
# NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
# vda    252:0    0   40G  0 disk
# ├─vda1 252:1    0    1M  0 part
# ├─vda2 252:2    0  191M  0 part /boot/efi
# └─vda3 252:3    0 39.8G  0 part /
# vdb    252:16   0  100G  0 disk  ← 这是要配置的新磁盘
```

### 步骤2: 分区和格式化

```bash
# 创建GPT分区表
sudo parted -s /dev/vdb mklabel gpt

# 创建单个分区使用全部空间
sudo parted -s /dev/vdb mkpart primary ext4 0% 100%

# 格式化为ext4
sudo mkfs.ext4 -F /dev/vdb1
```

### 步骤3: 挂载磁盘

```bash
# 创建挂载点
sudo mkdir -p /hadoop_data

# 临时挂载
sudo mount /dev/vdb1 /hadoop_data

# 检查挂载
df -h /hadoop_data
```

### 步骤4: 迁移Hadoop数据

```bash
# 检查当前数据大小
du -sh /opt/hadoop/data/dfs

# 创建新的数据目录
sudo mkdir -p /hadoop_data/dfs

# 使用rsync迁移数据（保留权限）
sudo rsync -avh --progress /opt/hadoop/data/dfs/ /hadoop_data/dfs/

# 备份原数据
sudo mv /opt/hadoop/data/dfs /opt/hadoop/data/dfs_backup_$(date +%Y%m%d_%H%M%S)

# 创建符号链接
sudo ln -sf /hadoop_data/dfs /opt/hadoop/data/dfs
```

### 步骤5: 配置自动挂载

```bash
# 获取磁盘UUID
sudo blkid /dev/vdb1

# 备份fstab
sudo cp /etc/fstab /etc/fstab.backup

# 添加挂载配置（替换UUID为实际值）
echo "UUID=your-uuid-here /hadoop_data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

# 测试fstab配置
sudo mount -a
```

### 步骤6: 设置权限

```bash
# 设置所有者为ecs-user
sudo chown -R ecs-user:ecs-user /hadoop_data/dfs

# 设置权限
sudo chmod -R 755 /hadoop_data/dfs
```

## 🔄 重启Hadoop服务

### 单节点模式（hadoop001）

```bash
# 停止服务
sudo -u ecs-user /opt/hadoop/sbin/stop-dfs.sh

# 启动服务
sudo -u ecs-user /opt/hadoop/sbin/start-dfs.sh
```

### 多节点模式

```bash
# 在hadoop001上停止HDFS
sudo -u ecs-user /opt/hadoop/sbin/stop-dfs.sh

# 在hadoop002上停止YARN
ssh hadoop002
sudo -u ecs-user /opt/hadoop/sbin/stop-yarn.sh
exit

# 启动HDFS
sudo -u ecs-user /opt/hadoop/sbin/start-dfs.sh

# 在hadoop002上启动YARN
ssh hadoop002
sudo -u ecs-user /opt/hadoop/sbin/start-yarn.sh
exit
```

## ✅ 验证步骤

### 1. 检查磁盘挂载

```bash
df -h

# 应该看到：
# Filesystem      Size  Used Avail Use% Mounted on
# /dev/vdb1        98G   19G   75G  20% /hadoop_data
```

### 2. 检查符号链接

```bash
ls -la /opt/hadoop/data/dfs

# 应该显示：
# lrwxrwxrwx 1 root root 17 Nov 26 13:30 /opt/hadoop/data/dfs -> /hadoop_data/dfs
```

### 3. 检查HDFS状态

```bash
sudo -u ecs-user hdfs dfsadmin -report

# 应该显示DataNode的存储容量已增加
```

### 4. 测试写入数据

```bash
# 创建测试文件
echo "test data" > test.txt

# 上传到HDFS
sudo -u ecs-user hdfs dfs -put test.txt /test_disk.txt

# 验证
sudo -u ecs-user hdfs dfs -ls /
sudo -u ecs-user hdfs dfs -cat /test_disk.txt

# 清理
rm test.txt
sudo -u ecs-user hdfs dfs -rm /test_disk.txt
```

### 5. 检查Web界面

访问 Hadoop Web UI 确认存储容量：
- **NameNode**: http://hadoop001:9870
- **YARN ResourceManager**: http://hadoop002:8088

在 NameNode UI 的 "Datanodes" 页面查看存储容量是否增加。

## 📊 预期结果

### 磁盘空间对比

**扩容前：**
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda3        40G   33G  5.2G  87% /
```

**扩容后：**
```
Filesystem      Size  Used Avail Use% Mounted on
/dev/vda3        40G   14G   24G  37% /          ← 减少了19GB (Hadoop数据已迁移)
/dev/vdb1        98G   19G   75G  20% /hadoop_data  ← 新增100GB磁盘
```

### HDFS容量增加

- **原容量**: ~40GB (受限于根分区)
- **新容量**: ~100GB (使用独立数据盘)
- **增加**: +60GB 可用空间

## 🛠️ 故障排除

### 问题1: 磁盘未出现

```bash
# 检查阿里云控制台，确认磁盘已挂载到实例
# 在ECS实例中重新扫描SCSI总线
echo "- - -" | sudo tee /sys/class/scsi_host/host*/scan
lsblk
```

### 问题2: 权限错误

```bash
# 确保所有目录所有者为ecs-user
sudo chown -R ecs-user:ecs-user /hadoop_data/dfs
sudo chown -R ecs-user:ecs-user /opt/hadoop/data

# 检查权限
ls -la /hadoop_data/dfs
ls -la /opt/hadoop/data/dfs
```

### 问题3: HDFS启动失败

```bash
# 查看日志
sudo -u ecs-user tail -f /opt/hadoop/logs/hadoop-*-namenode-*.log
sudo -u ecs-user tail -f /opt/hadoop/logs/hadoop-*-datanode-*.log

# 常见原因：
# 1. 权限问题 - 运行上面的权限修复命令
# 2. 数据目录不存在 - 检查符号链接和目标目录
# 3. 端口冲突 - 检查是否有旧进程占用端口
```

### 问题4: 开机后磁盘未自动挂载

```bash
# 检查fstab配置
cat /etc/fstab | grep hadoop_data

# 手动测试挂载
sudo mount -a

# 如果出错，检查UUID是否正确
sudo blkid /dev/vdb1
```

### 问题5: 数据丢失担忧

自动化脚本会：
1. 创建备份目录（带时间戳）
2. 使用rsync复制（保留所有元数据）
3. 仅在复制成功后才移动原目录

如需恢复原数据：
```bash
# 查找备份
ls -la /opt/hadoop/data/dfs_backup_*

# 恢复备份（如果需要）
sudo rm /opt/hadoop/data/dfs
sudo mv /opt/hadoop/data/dfs_backup_YYYYMMDD_HHMMSS /opt/hadoop/data/dfs
```

## 📈 性能优化建议

### 1. 调整HDFS块大小

对于大文件，可以增加块大小：

```xml
<!-- 在 hdfs-site.xml 中添加 -->
<property>
    <name>dfs.blocksize</name>
    <value>268435456</value> <!-- 256MB -->
</property>
```

### 2. 配置多个数据目录

如果有多个磁盘，可以配置HDFS使用多个数据目录：

```xml
<property>
    <name>dfs.datanode.data.dir</name>
    <value>file:///hadoop_data/dfs,file:///mnt/disk2/dfs</value>
</property>
```

### 3. 监控磁盘使用

```bash
# 添加到crontab定期检查
0 */6 * * * df -h /hadoop_data | mail -s "Hadoop Disk Usage" admin@example.com
```

## 🔒 安全建议

1. **定期备份**: 使用快照功能定期备份磁盘
2. **监控空间**: 设置告警，磁盘使用超过80%时通知
3. **数据冗余**: 配置HDFS副本数（默认为3）
4. **权限控制**: 确保只有Hadoop用户有权限访问数据目录

## 📚 相关文档

- [阿里云ECS磁盘扩容文档](https://help.aliyun.com/document_detail/25452.html)
- [Hadoop HDFS管理指南](https://hadoop.apache.org/docs/r3.2.4/hadoop-project-dist/hadoop-hdfs/HdfsUserGuide.html)
- [本项目README](../readme.md)

## ✅ 检查清单

使用此清单确保所有步骤都已完成：

- [ ] 磁盘已在阿里云控制台挂载到ECS实例
- [ ] 磁盘设备 `/dev/vdb` 在系统中可见
- [ ] 已创建分区并格式化为ext4
- [ ] 磁盘已挂载到 `/hadoop_data`
- [ ] Hadoop数据已迁移到新磁盘
- [ ] 符号链接已创建并正确指向
- [ ] fstab已配置开机自动挂载
- [ ] 目录权限已设置为ecs-user
- [ ] Hadoop服务已重启
- [ ] HDFS状态报告显示增加的容量
- [ ] 测试数据可以成功写入和读取
- [ ] Web界面显示正确的存储容量

## 🎯 总结

通过本指南，你已经成功：
1. ✅ 将100GB数据盘挂载到Hadoop服务器
2. ✅ 迁移现有Hadoop数据到新磁盘
3. ✅ 释放根分区空间（从87%降至约37%）
4. ✅ 扩展HDFS存储容量到~100GB
5. ✅ 配置开机自动挂载
6. ✅ 验证Hadoop正常工作

现在你可以：
- 运行更大规模的MapReduce任务
- 存储更多的实验数据
- 不用担心磁盘空间不足的问题

如有问题，请查看故障排除部分或联系系统管理员。
