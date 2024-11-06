### k8s安装powerjob

1、mysql

````shell
mkdir -p ~/powerjob-yml

kubectl create ns powerjob
````

````shell
cat > ~/powerjob-yml/powerjob-mysql.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: powerjob-mysql-config
  namespace: powerjob
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
    
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: powerjob-mysql
  namespace: powerjob
spec:
  serviceName: "powerjob-mysql-headless"
  replicas: 1
  selector:
    matchLabels:
      app: powerjob-mysql
  template:
    metadata:
      labels:
        app: powerjob-mysql
    spec:
      containers:
      - name: powerjob-mysql
        #image: mysql:8.0.28
        image: ccr.ccs.tencentyun.com/huanghuanhui/mysql:8.0.28
        imagePullPolicy: IfNotPresent
        ports:
        - name: powerjob-mysql
          containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "Powerjob@2024"
#       resources:
#         limits:
#           cpu: 2
#           memory: 4Gi
#         requests:
#           cpu: 2
#           memory: 4Gi
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
        - name: powerjob-mysql-data-pvc
          mountPath: /var/lib/mysql
        - name: powerjob-mysql-config
          mountPath: /etc/mysql/my.cnf
          subPath: my.cnf
        - mountPath: /etc/localtime
          name: localtime
      volumes:
      - name: powerjob-mysql-config
        configMap:
          name: powerjob-mysql-config
      - name: localtime
        hostPath:
          path: /etc/localtime
  volumeClaimTemplates:
  - metadata:
      name: powerjob-mysql-data-pvc
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: cfs
      resources:
        requests:
          storage: 100Gi

---
apiVersion: v1
kind: Service
metadata:
  name: powerjob-mysql-headless
  namespace: powerjob
  labels:
    app: powerjob-mysql
spec:
  clusterIP: None
  ports:
  - port: 3306
    name: powerjob-mysql
    targetPort: 3306
  selector:
    app: powerjob-mysql

---
apiVersion: v1
kind: Service
metadata:
  name: powerjob-mysql
  namespace: powerjob
  labels:
    app: powerjob-mysql
spec:
  type: NodePort
  ports:
  - port: 3306
    targetPort: 3306
    nodePort: 30336
  selector:
    app: powerjob-mysql
EOF
````

`````shell
kubectl apply -f ~/powerjob-yml/powerjob-mysql.yml
`````

```shell
kubectl exec -it powerjob-mysql-0 -n powerjob -- mysql -pPowerjob@2024 -e "show databases;"

kubectl exec -it powerjob-mysql-0 -n powerjob -- mysql -pPowerjob@2024 -e "select host,user from mysql.user;"

kubectl exec -it powerjob-mysql-0 -n powerjob -- mysql -pPowerjob@2024 -e "alter user 'root'@'%' identified with mysql_native_password by 'Powerjob@2024';"

kubectl exec -it powerjob-mysql-0 -n powerjob -- mysql -pPowerjob@2024 -e "flush privileges;"

CREATE DATABASE IF NOT EXISTS `powerjob-product` DEFAULT CHARSET utf8mb4;
```

2、mongodb

````shell
cat > ~/powerjob-yml/powerjob-mongodb.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: powerjob-mongodb
  namespace: powerjob
spec:
  serviceName: "powerjob-mongodb-headless"
  replicas: 1
  selector:
    matchLabels:
      app: powerjob-mongodb
  template:
    metadata:
      labels:
        app: powerjob-mongodb
    spec:
      containers:
      - name: powerjob-mongodb
        image: ccr.ccs.tencentyun.com/huanghuanhui/mongo:7.0.8
        ports:
        - containerPort: 27017
          name: mongodb
        volumeMounts:
        - name: powerjob-mongodb-data-pvc
          mountPath: /data/db
        - name: localtime
          mountPath: /etc/localtime
      volumes:
      - name: localtime
        hostPath:
          path: /etc/localtime
  volumeClaimTemplates:
  - metadata:
      name: powerjob-mongodb-data-pvc
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: cfs
      resources:
        requests:
          storage: 100Gi

---
apiVersion: v1
kind: Service
metadata:
  name: powerjob-mongodb-headless
  namespace: powerjob
  labels:
    app: powerjob-mongodb
spec:
  clusterIP: None
  ports:
  - port: 27017
    name: powerjob-mongodb
    targetPort: 27017
  selector:
    app: powerjob-mongodb

---
apiVersion: v1
kind: Service
metadata:
  name: powerjob-mongodb
  namespace: powerjob
  labels:
    app: powerjob-mongodb
spec:
  type: NodePort
  ports:
  - port: 27017
    targetPort: 27017
    nodePort: 30277
  selector:
    app: powerjob-mongodb
EOF
````

````shell
kubectl apply -f ~/powerjob-yml/powerjob-mongodb.yml
````

3、powerjob

````shell
cat > ~/powerjob-yml/powerjob.yml << 'EOF' 
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: powerjob-server
  namespace: powerjob
spec:
  serviceName: "powerjob-server-headless"
  replicas: 1
  selector:
    matchLabels:
      app: powerjob-server
  template:
    metadata:
      labels:
        app: powerjob-server
    spec:
      containers:
      - name: powerjob-server
        image: ccr.ccs.tencentyun.com/huanghuanhui/powerjob-server:4.3.9
        ports:
        - containerPort: 7700
          name: http
        - containerPort: 10086
          name: agent
        - containerPort: 10010
          name: admin
        env:
        - name: TZ
          value: "Asia/Shanghai"
        - name: JVMOPTIONS
          value: ""
        - name: PARAMS
          value: "--spring.profiles.active=product --spring.datasource.core.jdbc-url=jdbc:mysql://powerjob-mysql-headless:3306/powerjob-product?useUnicode=true&characterEncoding=UTF-8 --spring.datasource.core.username=root --spring.datasource.core.password=Powerjob@2024 --spring.data.mongodb.uri=mongodb://powerjob-mongodb-headless:27017/powerjob-product"
        volumeMounts:
        - name: powerjob-data-pvc
          mountPath: /root/powerjob/server
        - name: m2-repo
          mountPath: /root/.m2
      volumes:
      - name: m2-repo
        emptyDir: {}
  volumeClaimTemplates:
  - metadata:
      name: powerjob-data-pvc
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: cfs
      resources:
        requests:
          storage: 100Gi

---
apiVersion: v1
kind: Service
metadata:
  name: powerjob-server
  namespace: powerjob
  labels:
    app: powerjob-server
spec:
  type: NodePort
  ports:
  - name: http
    port: 7700
    targetPort: http
    nodePort: 30077
  - name: agent
    port: 10086
    targetPort: agent
    nodePort: 30086
  - name: admin
    port: 10010
    targetPort: admin
    nodePort: 30110
  selector:
    app: powerjob-server
EOF
````

````shell
kubectl apply -f ~/powerjob-yml/powerjob.yml
````

