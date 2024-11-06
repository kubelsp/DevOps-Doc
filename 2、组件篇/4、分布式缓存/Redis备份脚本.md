###### Redis备份脚本

###### 安装redis-cli客户端工具

```shell
yum -y install epel-release

yum -y install http://rpms.remirepo.net/enterprise/remi-release-7.rpm

ll /etc/yum.repos.d/

yum --enablerepo=remi install redis -y　　#enablerepo指定yum源

redis-cli --version　　#安装完成后使用命令查看一下版本 redis-cli 7.2.4
```

> yum安装redis时，建议使用Remi repository源。因为Remi源提供了目前最新版本的Redis，可以通该源使用YUM安装目前最新版本的Redis。另外还提供了PHP和MySQL的最新yum源，以及相关服务程序。
>
> 注意：remi源安装完成后，默认为不启动，在需求使用remi repository源安装程序时，需求--enablerepo=remi选项指定使用remi repository源是可以被使用的，然后进行安装。 

###### for循环写10000个key做测试

```shell
cat > set_keys.sh << 'EOF'
#!/bin/bash

REDIS_HOST="192.168.1.200"
REDIS_PORT="30078"
REDIS_PASSWORD="Admin@2024"

for i in {1..10000}
do
  KEY="mykey$i"
  VALUE="myvalue$i"

  redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD SET $KEY "$VALUE"
done
EOF


chmod +x set_keys.sh

./set_keys.sh
```



### 单机 Redis 恢复备份：

```shell
mkdir -p /root/redis-backup/redis-pvc

mkdir -p /root/redis-backup/redis
```

```shell
# 备份脚本1：
cat > ~/backup_redis_1.sh << 'EOF'
#!/bin/bash

# 1、备份pvc数据目录
cp -r /data/k8s/redis-redis-data-redis-0-pvc-b78d9861-06fb-4891-9b9e-fa3a4ae3e334/ /root/redis-backup/redis-pvc/$(date +"%Y%m%d%H%M%S")
EOF

# 备份脚本2：
cat > ~/backup_redis_2.sh << 'EOF'
#!/bin/bash

# Redis 服务器地址、端口和密码
REDIS_HOST="192.168.1.200"
REDIS_PORT="30078"
REDIS_PASSWORD="Admin@2024"

# 备份目录
BACKUP_DIR="/root/redis-backup/redis"

# 生成当前时间的格式化字符串，作为备份文件名的一部分
CURRENT_DATE=$(date +"%Y%m%d%H%M%S")

# 使用 redis-cli 执行 AUTH 命令进行身份验证，执行 BGSAVE 命令生成快照，并添加时间戳作为文件名
redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD BGSAVE
redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD --rdb - > $BACKUP_DIR/$CURRENT_DATE-dump.rdb

echo "Redis 备份完成，文件保存在 $BACKUP_DIR/$CURRENT_DATE-dump.rdb"
EOF
```

```shell
chmod +x backup_redis_1.sh

chmod +x backup_redis_2.sh

[root@localhost ~]# crontab -l
0 0 * * * /root/backup_redis_1.sh &>/dev/null
0 0 * * * /root/backup_redis_2.sh &>/dev/null




redis-cli -h 192.168.1.200 -p 30078 -a Admin@2024 SAVE	#输出到redis内部数据目录
redis-cli -h 192.168.1.200 -p 30078 -a Admin@2024 BGSAVE	#输出到redis内部数据目录
redis-cli -h 192.168.1.200 -p 30078 -a Admin@2024 --rdb - > dump.rdb	#当前（任意）目录（推荐）

redis-cli -h 192.168.1.200 -p 30078 -a Admin@2024 BGREWRITEAOF
```

###### 恢复

```shell
# 1、恢复pvc数据目录

# 2、重写key
redis-cli -h 192.168.1.200 -p 30078 -a Admin@2024 --pipe < appendonly.aof.1.incr.aof
```

```shell
redis-cli -h 192.168.1.200 -p 30078 -a Admin@2024 SET mykey "myvalue"
```

```shell
#redis-cli -h 192.168.1.200 -p 30078 -a Admin@2024 --rdb - < dump.rdb
```

### Redis 集群恢复备份：

```shell
cat > backup_redis_cluster.sh << 'EOF'
#!/bin/bash

# Redis 集群节点地址和端口
REDIS_NODES=("127.0.0.1:7000" "127.0.0.1:7001" "127.0.0.1:7002")

# 备份目录
BACKUP_DIR="/path/to/backup/directory"

# 生成当前时间的格式化字符串，作为备份文件名的一部分
CURRENT_DATE=$(date +"%Y%m%d%H%M%S")

# 循环遍历集群节点备份数据
for NODE in "${REDIS_NODES[@]}"; do
  # 提取节点的地址和端口
  IFS=':' read -r -a NODE_INFO <<< "$NODE"
  REDIS_HOST="${NODE_INFO[0]}"
  REDIS_PORT="${NODE_INFO[1]}"

  # 使用 redis-cli 执行 CLUSTER SAVECONFIG 命令
  redis-cli -h $REDIS_HOST -p $REDIS_PORT CLUSTER SAVECONFIG

  # 使用 redis-cli 执行 BGSAVE 命令生成快照
  redis-cli -h $REDIS_HOST -p $REDIS_PORT BGSAVE

  # 等待快照生成完成
  sleep 5

  # 将快照文件移动到备份目录，并添加时间戳作为文件名
  mv "${REDIS_PORT}.rdb" "$BACKUP_DIR/dump_${REDIS_PORT}_${CURRENT_DATE}.rdb"

  echo "Redis 集群节点 $NODE 备份完成，文件保存在 $BACKUP_DIR/dump_${REDIS_PORT}_${CURRENT_DATE}.rdb"
done
EOF
```

```shell
chmod +x backup_redis_cluster.sh
```

```shell
./backup_redis_cluster.sh
```

```shell
[root@localhost ~]# crontab -l
0 0 * * * /root/backup_redis_cluster.sh &>/dev/null
```

