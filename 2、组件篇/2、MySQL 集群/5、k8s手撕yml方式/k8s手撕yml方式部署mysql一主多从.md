###### k8s手撕yml方式部署mysql一主多从

> 适合开发、测试环境
>
> 版本：mysql-8.0.28

```shell
mkdir -p ~/mysql-yml

kubectl create ns mysql

kubectl create secret generic mysqlsecret --from-literal=MYSQL_ROOT_PASSWORD=Admin@2024
```

###### k8s-mysql-master

```shell
cat > ~/mysql-yml/mysql-master.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-master-config
  namespace: mysql
data:
  my.cnf: |
    [mysqld]
    pid-file        = /var/run/mysqld/mysqld.pid
    socket          = /var/run/mysqld/mysqld.sock
    datadir         = /var/lib/mysql
    server-id       = 1
    secure-file-priv= NULL

    # Custom config should go here
    !includedir /etc/mysql/conf.d/

    # 优化配置
    # 设置最大连接数为 2500
    max_connections = 2500
    # 允许最多 100,000 个预处理语句同时存在（取值范围：0 - 1048576，默认16382）
    max_prepared_stmt_count = 100000
    # 设置字符集为 UTF-8
    character-set-server=utf8mb4
    collation-server=utf8mb4_general_ci
    # 设置 InnoDB 引擎的缓冲区大小(InnoDB 缓冲池设置为内存的50%-75%)
    innodb_buffer_pool_size=4G

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-master
  namespace: mysql
spec:
  serviceName: mysql-master-headless
  replicas: 1
  selector:
    matchLabels:
      app: mysql-master
  template:
    metadata:
      labels:
        app: mysql-master
    spec:
      containers:
      - name: mysql-master
        #image: mysql:8.0.28
        image: ccr.ccs.tencentyun.com/huanghuanhui/mysql:8.0.28
        imagePullPolicy: IfNotPresent
        ports:
        - name: mysql-master
          containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysqlsecret
              key: MYSQL_ROOT_PASSWORD
        resources:
          limits:
            cpu: 2
            memory: 4Gi
          requests:
            cpu: 2
            memory: 4Gi
        livenessProbe:
          exec:
            command: ["mysqladmin", "ping", "-uroot", "-p${MYSQL_ROOT_PASSWORD}"]
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          exec:
            command: ["mysqladmin", "ping", "-uroot", "-p${MYSQL_ROOT_PASSWORD}"]
          initialDelaySeconds: 5
          periodSeconds: 2
          timeoutSeconds: 1
        volumeMounts:
        - name: mysql-master-data-pvc
          mountPath: /var/lib/mysql
        - name: mysql-master-config
          mountPath: /etc/mysql/my.cnf
          subPath: my.cnf
        - mountPath: /etc/localtime
          name: localtime
      volumes:
      - name: mysql-master-config
        configMap:
          name: mysql-master-config
      - name: localtime
        hostPath:
          path: /etc/localtime
  volumeClaimTemplates:
  - metadata:
      name: mysql-master-data-pvc
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: nfs-storage
      resources:
        requests:
          storage: 2Ti

---
apiVersion: v1
kind: Service
metadata:
  name: mysql-master-headless
  namespace: mysql
  labels:
    app: mysql-master
spec:
  clusterIP: None
  ports:
  - port: 3306
    name: mysql-master
    targetPort: 3306
  selector:
    app: mysql-master

---
apiVersion: v1
kind: Service
metadata:
  name: mysql-master
  namespace: mysql
  labels:
    app: mysql-master
spec:
  type: NodePort
  ports:
  - port: 3306
    targetPort: 3306
    nodePort: 30336
  selector:
    app: mysql-master
EOF
```

```shell
kubectl apply -f ~/mysql-yml/mysql-master.yml
```

> 代码连接地址：mysql-headless.mysql.svc.cluster.local:3306
>
> 访问地址：ip（192.168.1.200） + 端口（30336）
>
> 用户密码：root、Admin@2024

###### k8s-mysql-slave1

```shell
cat > ~/mysql-yml/mysql-slave1.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-slave1-config
  namespace: mysql
data:
  my.cnf: |
    [mysqld]
    pid-file        = /var/run/mysqld/mysqld.pid
    socket          = /var/run/mysqld/mysqld.sock
    datadir         = /var/lib/mysql
    server-id       = 2
    secure-file-priv= NULL

    # Custom config should go here
    !includedir /etc/mysql/conf.d/

    # 优化配置
    # 设置最大连接数为 2500
    max_connections = 2500
    # 允许最多 100,000 个预处理语句同时存在（取值范围：0 - 1048576，默认16382）
    max_prepared_stmt_count = 100000
    # 设置字符集为 UTF-8
    character-set-server=utf8mb4
    collation-server=utf8mb4_general_ci
    # 设置 InnoDB 引擎的缓冲区大小(InnoDB 缓冲池设置为内存的50%-75%)
    innodb_buffer_pool_size=4G

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-slave1
  namespace: mysql
spec:
  serviceName: mysql-slave1-headless
  replicas: 1
  selector:
    matchLabels:
      app: mysql-slave1
  template:
    metadata:
      labels:
        app: mysql-slave1
    spec:
      containers:
      - name: mysql-slave1
        image: mysql:8.0.28
        imagePullPolicy: IfNotPresent
        ports:
        - name: mysql-slave1
          containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysqlsecret
              key: MYSQL_ROOT_PASSWORD
        resources:
          limits:
            cpu: 2
            memory: 4Gi
          requests:
            cpu: 2
            memory: 4Gi
        livenessProbe:
          exec:
            command: ["mysqladmin", "ping", "-uroot", "-p${MYSQL_ROOT_PASSWORD}"]
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          exec:
            command: ["mysqladmin", "ping", "-uroot", "-p${MYSQL_ROOT_PASSWORD}"]
          initialDelaySeconds: 5
          periodSeconds: 2
          timeoutSeconds: 1
        volumeMounts:
        - name: mysql-slave1-data-pvc
          mountPath: /var/lib/mysql
        - name: mysql-slave1-config
          mountPath: /etc/mysql/my.cnf
          subPath: my.cnf
        - mountPath: /etc/localtime
          name: localtime
      volumes:
      - name: mysql-slave1-config
        configMap:
          name: mysql-slave1-config
      - name: localtime
        hostPath:
          path: /etc/localtime
  volumeClaimTemplates:
  - metadata:
      name: mysql-slave1-data-pvc
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: nfs-storage
      resources:
        requests:
          storage: 2Ti

---
apiVersion: v1
kind: Service
metadata:
  name: mysql-slave1-headless
  namespace: mysql
  labels:
    app: mysql-slave1
spec:
  clusterIP: None
  ports:
  - port: 3306
    name: mysql-slave1
    targetPort: 3306
  selector:
    app: mysql-slave1

---
apiVersion: v1
kind: Service
metadata:
  name: mysql-slave1
  namespace: mysql
  labels:
    app: mysql-slave1
spec:
  type: NodePort
  ports:
  - port: 3306
    targetPort: 3306
    nodePort: 30337
  selector:
    app: mysql-slave1
EOF
```

```shell
kubectl apply -f ~/mysql-yml/mysql-slave1.yml
```

> 代码连接地址：mysql-headless.mysql.svc.cluster.local:3306
>
> 访问地址：ip（192.168.1.200） + 端口（30336）
>
> 用户密码：root、Admin@2024

###### k8s-mysql-slave2

```shell
cat > ~/mysql-yml/mysql-slave2.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-slave2-config
  namespace: mysql
data:
  my.cnf: |
    [mysqld]
    pid-file        = /var/run/mysqld/mysqld.pid
    socket          = /var/run/mysqld/mysqld.sock
    datadir         = /var/lib/mysql
    server-id       = 2
    secure-file-priv= NULL

    # Custom config should go here
    !includedir /etc/mysql/conf.d/

    # 优化配置
    # 设置最大连接数为 2500
    max_connections = 2500
    # 允许最多 100,000 个预处理语句同时存在（取值范围：0 - 1048576，默认16382）
    max_prepared_stmt_count = 100000
    # 设置字符集为 UTF-8
    character-set-server=utf8mb4
    collation-server=utf8mb4_general_ci
    # 设置 InnoDB 引擎的缓冲区大小(InnoDB 缓冲池设置为内存的50%-75%)
    innodb_buffer_pool_size=4G

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-slave2
  namespace: mysql
spec:
  serviceName: mysql-slave2-headless
  replicas: 1
  selector:
    matchLabels:
      app: mysql-slave2
  template:
    metadata:
      labels:
        app: mysql-slave2
    spec:
      containers:
      - name: mysql-slave2
        image: mysql:8.0.28
        imagePullPolicy: IfNotPresent
        ports:
        - name: mysql-slave2
          containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          valueFrom:
            secretKeyRef:
              name: mysqlsecret
              key: MYSQL_ROOT_PASSWORD
        resources:
          limits:
            cpu: 2
            memory: 4Gi
          requests:
            cpu: 2
            memory: 4Gi
        livenessProbe:
          exec:
            command: ["mysqladmin", "ping", "-uroot", "-p${MYSQL_ROOT_PASSWORD}"]
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          exec:
            command: ["mysqladmin", "ping", "-uroot", "-p${MYSQL_ROOT_PASSWORD}"]
          initialDelaySeconds: 5
          periodSeconds: 2
          timeoutSeconds: 1
        volumeMounts:
        - name: mysql-slave2-data-pvc
          mountPath: /var/lib/mysql
        - name: mysql-slave2-config
          mountPath: /etc/mysql/my.cnf
          subPath: my.cnf
        - mountPath: /etc/localtime
          name: localtime
      volumes:
      - name: mysql-slave2-config
        configMap:
          name: mysql-slave2-config
      - name: localtime
        hostPath:
          path: /etc/localtime
  volumeClaimTemplates:
  - metadata:
      name: mysql-slave2-data-pvc
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: nfs-storage
      resources:
        requests:
          storage: 2Ti

---
apiVersion: v1
kind: Service
metadata:
  name: mysql-slave2-headless
  namespace: mysql
  labels:
    app: mysql-slave2
spec:
  clusterIP: None
  ports:
  - port: 3306
    name: mysql-slave2
    targetPort: 3306
  selector:
    app: mysql-slave2

---
apiVersion: v1
kind: Service
metadata:
  name: mysql-slave2
  namespace: mysql
  labels:
    app: mysql-slave2
spec:
  type: NodePort
  ports:
  - port: 3306
    targetPort: 3306
    nodePort: 30338
  selector:
    app: mysql-slave2
EOF
```

###### master上操作

```shell
kubectl exec -it mysql-master-0 -- mysql -pAdmin@2024 -e "create user 'slave'@'%' identified with mysql_native_password by 'Slave@2024';"

kubectl exec -it mysql-master-0 -- mysql -pAdmin@2024 -e "grant replication slave on *.* to 'slave'@'%';"

kubectl exec -it mysql-master-0 -- mysql -pAdmin@2024 -e "use mysql;flush privileges;"

kubectl exec -it mysql-master-0 -- mysql -pAdmin@2024 -e "show master status;"
```

```shell
[root@k8s-master ~/mysql-yml]# kubectl exec -it mysql-master-0 -- mysql -pAdmin@2024 -e "show master status;"
mysql: [Warning] Using a password on the command line interface can be insecure.
+---------------+----------+--------------+------------------+-------------------+
| File          | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
+---------------+----------+--------------+------------------+-------------------+
| binlog.000002 |      834 |              |                  |                   |
+---------------+----------+--------------+------------------+-------------------+
```

###### slave1上操作

```shell
kubectl exec -it mysql-slave1-0 -- mysql -pAdmin@2024 -e "change master to master_host='mysql-master-headless.mysql.svc.cluster.local',master_user='slave',master_password='Slave@2024',master_port=3306,master_log_file='binlog.000002',master_log_pos=834;"
```

```shell
kubectl exec -it mysql-slave1-0 -- mysql -pAdmin@2024 -e "show slave status\G"

kubectl exec -it mysql-slave1-0 -- mysql -pAdmin@2024 -e "start slave;"

# kubectl exec -it mysql-slave1-0 -- mysql --password=Admin@2024 -e "stop slave; start slave;"

kubectl exec -it mysql-slave1-0 -- mysql -pAdmin@2024 -e "show slave status\G" |grep 'Yes'
#            Slave_SQL_Running: Yes
#            Slave_SQL_Running: Yes
```

###### slave2上操作

```shell
kubectl exec -it mysql-slave2-0 -- mysql -pAdmin@2024 -e "change master to master_host='mysql-master-headless.mysql.svc.cluster.local',master_user='slave',master_password='Slave@2024',master_port=3306,master_log_file='binlog.000002',master_log_pos=834;"
```

```shell
kubectl exec -it mysql-slave2-0 -- mysql -pAdmin@2024 -e "show slave status\G"

kubectl exec -it mysql-slave2-0 -- mysql -pAdmin@2024 -e "start slave;"

# kubectl exec -it mysql-slave1-0 -- mysql --password=Admin@2024 -e "stop slave; start slave;"

kubectl exec -it mysql-slave2-0 -- mysql -pAdmin@2024 -e "show slave status\G" |grep 'Yes'
#            Slave_SQL_Running: Yes
#            Slave_SQL_Running: Yes
```

```shell
[root@k8s-master ~/mysql-yml]# po
NAME             READY   STATUS    RESTARTS   AGE
mysql-master-0   1/1     Running   0          27m
mysql-slave1-0   1/1     Running   0          27m
mysql-slave2-0   1/1     Running   0          27m
[root@k8s-master ~/mysql-yml]# svc
NAME                    TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
mysql-master            NodePort    10.107.128.166   <none>        3306:30336/TCP   27m
mysql-master-headless   ClusterIP   None             <none>        3306/TCP         27m
mysql-slave1            NodePort    10.96.169.150    <none>        3306:30337/TCP   27m
mysql-slave1-headless   ClusterIP   None             <none>        3306/TCP         27m
mysql-slave2            NodePort    10.104.90.201    <none>        3306:30338/TCP   27m
mysql-slave2-headless   ClusterIP   None             <none>        3306/TCP         27m
```

![image-20240203235000318](C:\Users\huanghuanhui\AppData\Roaming\Typora\typora-user-images\image-20240203235000318.png)

![image-20240203235003956](C:\Users\huanghuanhui\AppData\Roaming\Typora\typora-user-images\image-20240203235003956.png)
