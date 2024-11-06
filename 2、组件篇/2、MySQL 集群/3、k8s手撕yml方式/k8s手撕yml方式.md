###### k8s手撕yml方式

> 适合开发、测试环境
>
> 版本：mysql-8.0.28

```shell
mkdir -p ~/mysql-yml

kubectl create ns mysql
```

###### 优化配置

```shell
cat > ~/mysql-yml/mysql-cm.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
  namespace: mysql
data:
  my.cnf: |
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
    # 允许最多 100,000 个预处理语句同时存在（取值范围：0 - 1048576，默认16382）
    max_prepared_stmt_count = 100000
    # 设置字符集为 UTF-8
    character-set-server=utf8mb4
    collation-server=utf8mb4_general_ci
    # 设置 InnoDB 引擎的缓冲区大小(InnoDB 缓冲池设置为内存的50%-75%)
    innodb_buffer_pool_size=4G
EOF
```

```shell
kubectl apply -f ~/mysql-yml/mysql-cm.yml
```

```shell
cat > ~/mysql-yml/mysql.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  namespace: mysql
spec:
  serviceName: mysql-headless
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        #image: mysql:8.0.28
        image: ccr.ccs.tencentyun.com/huanghuanhui/mysql:8.0.28
        imagePullPolicy: IfNotPresent
        ports:
        - name: mysql
          containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "Admin@2024"
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
        - name: mysql-data-pvc
          mountPath: /var/lib/mysql
        - name: mysql-config
          mountPath: /etc/mysql/my.cnf
          subPath: my.cnf
        - mountPath: /etc/localtime
          name: localtime
      volumes:
      - name: mysql-config
        configMap:
          name: mysql-config
      - name: localtime
        hostPath:
          path: /etc/localtime
  volumeClaimTemplates:
  - metadata:
      name: mysql-data-pvc
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
  name: mysql-headless
  namespace: mysql
  labels:
    app: mysql
spec:
  clusterIP: None
  ports:
  - port: 3306
    name: mysql
    targetPort: 3306
  selector:
    app: mysql

---
apiVersion: v1
kind: Service
metadata:
  name: mysql
  namespace: mysql
  labels:
    app: mysql
spec:
  type: NodePort
  ports:
  - port: 3306
    targetPort: 3306
    nodePort: 30336
  selector:
    app: mysql
EOF
```

```shell
kubectl apply -f ~/mysql-yml/mysql.yml
```

```shell
kubectl exec -it mysql-0 -n mysql -- mysql -pAdmin@2024 -e "show databases;"
```

```shell
mysql -h 192.168.1.10 -u root -P 30336 -pAdmin@2024 -e "show databases;"
```

```shell
kubectl exec -it mysql-0 -n mysql -- mysql -pAdmin@2024 -e "select host,user from mysql.user;"
```

```shell
kubectl exec -it mysql-0 -n mysql -- mysql -pAdmin@2024 -e "alter user 'root'@'%' identified with mysql_native_password by 'Admin@2024';"
```

```shell
kubectl exec -it mysql-0 -n mysql -- mysql -pAdmin@2024 -e "flush privileges;"
```

> 代码连接地址：mysql-headless.mysql.svc.cluster.local:3306
>
> 访问地址：ip（192.168.1.10） + 端口（30336）
>
> 用户密码：root、Admin@2024
