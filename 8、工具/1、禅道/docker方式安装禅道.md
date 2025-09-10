### 1、使用内置数据库（推荐）

```shell
docker pull easysoft/zentao:18.11
```

```shell
docker run -d \
--name zentao \
--restart always \
--privileged=true \
-p 8686:80 \
-v ~/zentao-data/data:/data \
-e MYSQL_INTERNAL=true \
-e PHP_MAX_EXECUTION_TIME=300 \
-e PHP_POST_MAX_SIZE=512M \
-e PHP_UPLOAD_MAX_FILESIZE=512M \
-e TIME_ZONE='Asia/Shanghai' \
easysoft/zentao:18.11
```

### 2、使用外部数据库

```shell
docker run -d \
--name zentao \
--restart always \
--privileged=true \
-p 8686:80 \
-v ~/zentao-data/data:/data \
-e MYSQL_INTERNAL=false \
-e ZT_MYSQL_HOST=<你的MySQL服务地址> \
-e ZT_MYSQL_PORT=<你的MySQL服务端口> \
-e ZT_MYSQL_USER=<你的MySQL服务用户名> \
-e ZT_MYSQL_PASSWORD=<你的MySQL服务密码> \
-e ZT_MYSQL_DB=<禅道数据库名> \
-e PHP_MAX_EXECUTION_TIME=300 \
-e PHP_POST_MAX_SIZE=512M \
-e PHP_UPLOAD_MAX_FILESIZE=512M \
easysoft/zentao:18.11
```

