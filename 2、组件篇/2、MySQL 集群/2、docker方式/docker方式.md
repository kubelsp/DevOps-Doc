###### docker方式

> 适合开发、测试环境
>
> 版本：mysql-8.0.28

```shell
mkdir -p ~/mysql-data
```

###### 优化配置

```shell
cat > ~/mysql-data/my.cnf << 'EOF'
    [mysqld]
    pid-file        = /var/run/mysqld/mysqld.pid
    socket          = /var/run/mysqld/mysqld.sock
    datadir         = /var/lib/mysql
    secure-file-priv= NULL

    # Custom config should go here
    !includedir /etc/mysql/conf.d/

    # 优化配置
    # 设置最大连接数为 2500
    max_connections = 2500
    # 设置字符集为 UTF-8
    character-set-server=utf8mb4
    collation-server=utf8mb4_general_ci
    # 设置 InnoDB 引擎的缓冲区大小(InnoDB 缓冲池设置为内存的50%-75%)
    innodb_buffer_pool_size=4G
EOF
```

```shell
docker run -d \
--name mysql \
--restart always \
--privileged=true \
-p 3306:3306 \
-v ~/mysql-data/my.cnf:/etc/mysql/my.cnf \
-v ~/mysql-data/mysql:/var/lib/mysql \
-e MYSQL_ROOT_PASSWORD=Admin@2024 \
-v /etc/localtime:/etc/localtime \
ccr.ccs.tencentyun.com/huanghuanhui/mysql:8.0.28
```

```shell
docker exec -it mysql mysql -pAdmin@2024 -e "show databases;"
```

```shell
docker exec -it mysql mysql -pAdmin@2024 -e "select host,user from mysql.user;"
```

```shell
docker exec -it mysql mysql -pAdmin@2024 -e "alter user 'root'@'%' identified with mysql_native_password by 'Admin@2024';"
```

```shell
docker exec -it mysql mysql -pAdmin@2024 -e "flush privileges;"
```

