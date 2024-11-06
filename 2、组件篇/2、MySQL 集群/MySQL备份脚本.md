###### mysql备份脚本

脚本1：过滤包含prd的库

```shell
cat > ~/mysql_backup.sh << 'EOF'

#!/bin/bash

DB_HOST=$1
DB_PORT=$2
DB_USER=$3
DB_PASS=$4
BACKUP_DIR=$5

time=$(date +%Y_%m_%d_%H_%M_%S)
mkdir -p "$BACKUP_DIR/$time"
echo "$BACKUP_DIR/$time"

# 获取所有数据库列表，并过滤出需要备份的数据库
backup_db_list=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES;" | grep "prd")

for db in $backup_db_list; do
  # 备份数据库
  mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -R "$db" --set-gtid-purged=OFF | gzip > "$BACKUP_DIR/$time/$db.sql.gz"
done

# 删除一个月前的备份目录
find "$BACKUP_DIR" -type d -mtime +30 -exec rm -rf {} \; > /dev/null 2>&1
EOF
```

```shell
[root@localhost ~]# crontab -l

/root/mysql_backup.sh "$DB_HOST" "$DB_PORT" "$DB_USER" "$DB_PASS" $BACKUP_DIR &>/dev/null
/root/mysql_backup.sh 192.168.0.195 3306 root Admin@2023 /data/mysql-backup/db/prd &>/dev/null

0 0 * * * /root/mysql_backup.sh 192.168.1.201 3306 root Admin@2024 /data/mysql-backup/db/prd &>/dev/null
```

脚本2：同时备份多个数据库（数组）

```shell
cat > ~/mysql_backup.sh << 'EOF'
#!/bin/bash

DB_HOST=$1
DB_PORT=$2
DB_USER=$3
DB_PASS=$4
BACKUP_DIR=$5

time=$(date +%Y_%m_%d_%H_%M_%S)
mkdir -p "$BACKUP_DIR/$time"

# 多个数据库名，每个数据库一行
databases=(
  "database1"
  "database2"
  # 添加更多的数据库名...
)

for db in "${databases[@]}"; do
  # 备份数据库
  mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -R "$db" --set-gtid-purged=OFF | gzip > "$BACKUP_DIR/$time/$db.sql.gz"
done

# 删除一个月前的备份目录
find "$BACKUP_DIR" -type d -mtime +30 -exec rm -rf {} \; > /dev/null 2>&1
EOF
```

```shell
[root@localhost ~]# crontab -l

/root/mysql_backup.sh "$DB_HOST" "$DB_PORT" "$DB_USER" "$DB_PASS" $BACKUP_DIR &>/dev/null
/root/mysql_backup.sh 192.168.0.195 3306 root Admin@2023 /data/mysql-backup/db/prd &>/dev/null
```

