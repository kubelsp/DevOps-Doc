### k8s部署dolphinscheduler（helm）

### 一、自定义镜像

`````shell
mkdir -p ~/dolphinscheduler-Dockerfile/{dolphinscheduler-alert-server,dolphinscheduler-api,dolphinscheduler-master,dolphinscheduler-tools,dolphinscheduler-worker}
`````

`````shell
wget https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.16/mysql-connector-java-8.0.16.jar
`````

###### 1、dolphinscheduler-alert-server

```shell
docker pull apache/dolphinscheduler-alert-server:3.1.7

docker tag apache/dolphinscheduler-alert-server:3.1.7 jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-alert-server:3.1.7

docker push jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-alert-server:3.1.7
```

````shell
cat > Dockerfile << 'EOF'
FROM jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-alert-server:3.1.7

COPY mysql-connector-java-8.0.16.jar /opt/dolphinscheduler/libs
EOF
````

````shell
docker build -t jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-alert-server:3.1.7-mysql-driver .
````

###### 2、dolphinscheduler-api

````shell
docker pull apache/dolphinscheduler-api:3.1.7

docker tag apache/dolphinscheduler-api:3.1.7 jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-api:3.1.7

docker push jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-api:3.1.7
````

````shell
cat > Dockerfile << 'EOF'
FROM jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-api:3.1.7

COPY mysql-connector-java-8.0.16.jar /opt/dolphinscheduler/libs
EOF
````

````shell
docker build -t  jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-api:3.1.7-mysql-driver .
````

###### 3、dolphinscheduler-master

````shell
docker pull apache/dolphinscheduler-master:3.1.7

docker tag apache/dolphinscheduler-master:3.1.7 jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-master:3.1.7

docker push jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-master:3.1.7
````

````shell
cat > Dockerfile << 'EOF'
FROM jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-master:3.1.7

COPY mysql-connector-java-8.0.16.jar /opt/dolphinscheduler/libs
EOF
````

````shell
docker build -t jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-master:3.1.7-mysql-driver .
````

###### 4、dolphinscheduler-tools

````shell
docker pull apache/dolphinscheduler-tools:3.1.7

docker tag apache/dolphinscheduler-tools:3.1.7 jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-tools:3.1.7

docker push jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-tools:3.1.7
````

````shell
cat > Dockerfile << 'EOF'
FROM jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-tools:3.1.7

COPY mysql-connector-java-8.0.16.jar /opt/dolphinscheduler/libs
EOF
````

````shell
docker build -t jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-tools:3.1.7-mysql-driver .
````

###### 5、dolphinscheduler-worker

````shell
docker pull apache/dolphinscheduler-worker:3.1.7

docker tag apache/dolphinscheduler-worker:3.1.7 jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-worker:3.1.7

docker push jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-worker:3.1.7
````

````shell
cat > setup_mysql_config.exp << 'eof'
expect &> /dev/null <<EOF
spawn mysql_config_editor set --login-path al_dev --host=10.90.0.8 --port=9030 --user=bigdata_flinkcdc --password
expect {
                "Enter password" { send "dKdbI698Gf5@o812b\n";exp_continue }
                "Press y" { send "y\n";exp_continue }
}
EOF

expect &> /dev/null <<EOF
spawn mysql_config_editor set --login-path datax_meta --host=10.80.0.183 --port=30789 --user=bigdata_flinkcdc --password
expect {
                "Enter password" { send "dKdbI698Gf5@o812b\n";exp_continue }
                "Press y" { send "y\n";exp_continue }
}
EOF
eof
````

`````shell
cat > Dockerfile << 'EOF'
FROM jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-worker:3.1.7

COPY mysql-connector-java-8.0.16.jar /opt/dolphinscheduler/libs

RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 python3-pip mysql-client-8.0 jq expect && \
    ln -s /usr/bin/python3 /usr/bin/python && \
    pip3 install  numpy==1.24.3 -i https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip3 install requests==2.27.1 -i https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip3 install pymysql==1.0.2 -i https://pypi.tuna.tsinghua.edu.cn/simple && \
    pip3 install kafka-python==2.0.2 -i https://pypi.tuna.tsinghua.edu.cn/simple && \
    rm -rf /var/lib/apt/lists/*
COPY setup_mysql_config.exp /usr/local/bin/setup_mysql_config.exp
RUN echo "/usr/local/bin/setup_mysql_config.exp" >> /root/.bashrc
EOF
`````

````shell
docker build -t jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial/dolphinscheduler-worker:3.1.7-mysql-driver .
````

````shell
cat > ~/dolphinscheduler-helm/values-prod.yaml << 'EOF'
image:
  registry: "jingshuo-registry.cn-hangzhou.cr.aliyuncs.com/jingsocial"
  tag: "3.1.7-mysql-driver"
  pullPolicy: "IfNotPresent"
  pullSecret: "dolphinscheduler-registry-secret"

postgresql:
  enabled: false

mysql:
  enabled: true
  auth:
    username: "ds"
    password: "ds"
    database: "dolphinscheduler"
    params: "characterEncoding=utf8"
  primary:
    persistence:
      enabled: true
      size: "300Gi"
      storageClass: "dev-nas"
      
zookeeper:
  enabled: true
  service:
    port: 2181
  fourlwCommandsWhitelist: "srvr,ruok,wchs,cons"
  persistence:
    enabled: true
    size: "20Gi"
    storageClass: "dev-nas"
EOF
````

````shell
kubectl -n dolphinscheduler create secret docker-registry dolphinscheduler-registry-secret \
  --docker-server=jingshuo-registry.cn-hangzhou.cr.aliyuncs.com \
  --docker-username=docker@1190795635417643 \
  --docker-password=vBFXuOTKqp1KmCtwGs
````

````shell
sed -i 's/docker.io/registry.cn-hangzhou.aliyuncs.com/g' ~/dolphinscheduler-helm/charts/zookeeper/values.yaml

sed -i 's|bitnami/zookeeper|jingsocial/zookeeper|g' ~/dolphinscheduler-helm/charts/zookeeper/values.yaml

sed -i 's/busybox:1.30/registry.cn-hangzhou.aliyuncs.com\/jingsocial\/busybox:1.30/g' ~/dolphinscheduler-helm/templates/_helpers.tpl
````

```shell
helm upgrade --install -n dolphinscheduler dolphinscheduler -f ./values-prod.yaml .
```

````shell
mysqldump -h "rm-uf6bx4378q6u408q490110.mysql.rds.aliyuncs.com" -P "3306" -u "dolphin_dev" -p"8L@gPzMhAxwT" -R "dolphin_dev" --set-gtid-purged=OFF >2024-07-10-old-dolphin_dev.sql

mysql -h 10.80.0.183 -P 30789 -uds -pds dolphinscheduler < 2024-07-10-old-dolphin_dev.sql
````

>http://10.80.0.183:32256/dolphinscheduler/ui/login
>
>admin
>dolphinscheduler123

````shell
cat > dolphinscheduler-worker-pvc.yml << 'EOF'
apiVersion: v1
kind:  PersistentVolumeClaim
metadata:
  name: dolphinscheduler-worker-pvc
  namespace: dolphinscheduler
spec:
  storageClassName: "dev-nas"
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 100Gi
EOF
````

````shell
    volumeMounts:
    - mountPath: /app
      name: data-dolphinscheduler-worker
      subPath: app
````

````shell
  volumes:
  - name: data-dolphinscheduler-worker
    persistentVolumeClaim:
      claimName: dolphinscheduler-worker-pvc
````

````shell
cat > transform_execute.sh << 'EOF'
#!/bin/bash

# 接收传进来的 json
json=$2
# 原 sql 文件地址
input_file="/app/run/sql/$1.sql"
# 新的 sql 文件地址
output_file="/app/run/new-sql/$1.sql"
# 将 env 解析出来
serviceEnv=$(echo "${json}" | jq -r '.env')
# 检查原文件是否存在，不存在直接退出
if [ ! -f "${input_file}" ]; then
    echo "ERROR 原文件 ${input_file} 不存在，请仔细检查！"
    exit 1;
fi
# 将原文件拷贝到新地址
install -D "${input_file}" "${output_file}"
# 将 json 使用 jq 工具解析
keys_values=$(echo "${json}" | jq -r 'to_entries[] | .key as $k | .value as $v | "\($k)=\($v)"')
# 走循环将 sql 文件中的变量替换
while IFS='=' read -r key value; do
    sed -i "s/\${${key}}/${value}/g" "${output_file}"
done <<< "${keys_values}"
# 最后执行替换后的 sql 文件
mysql --login-path=al_${serviceEnv} -e "source ${output_file}"
EOF
````

````shell
10.90.0.10
scp@2024
````

````shell
mysql_config_editor set --login-path al_dev --host=10.90.0.8 --port=9030 --user=bigdata_flinkcdc --password

dKdbI698Gf5@o812b

mysql --login-path=al_dev


#!/usr/bin/expect
expect &> /dev/null <<EOF
spawn mysql_config_editor set --login-path al_dev --host=10.90.0.8 --port=9030 --user=bigdata_flinkcdc --password
expect {
		"Enter password" { send "dKdbI698Gf5@o812b\n";exp_continue }
		"Press y" { send "y\n";exp_continue }
}
EOF
````

````shell
# CREATE USER 'bigdata_flinkcdc'@'%' IDENTIFIED BY 'dKdbI698Gf5@o812b';

# GRANT SELECT,DELETE,INSERT,UPDATE,ALTER ON big_data_department.* TO 'bigdata_flinkcdc'@'%';

mysql_config_editor set --login-path datax_meta --host=10.80.0.183 --port=30789 --user=bigdata_flinkcdc --password

dKdbI698Gf5@o812b

mysql --login-path=datax_meta
````

````shell
 mysql_config_editor print --all
````

