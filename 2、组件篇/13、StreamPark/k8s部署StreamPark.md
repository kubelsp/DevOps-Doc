###### k8s部署StreamPark

````shell
mkdir -p ~/k8s-streampark-yml/2.1.5-sql

kubectl create ns streampark
````

````shell
cat > ~/k8s-streampark-yml/Dockerfile << 'EOF'
FROM ccr.ccs.tencentyun.com/huanghuanhui/docker:27.1.1

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tencent.com/g' /etc/apk/repositories && \
    apk update && apk add openjdk8 bash && \
    echo 'export JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk' >> /etc/profile && \

    mkdir -p ~/apache-streampark_2.12-2.1.5 && \
    mkdir -p ~/streampark_workspace && \
    mkdir -p ~/.kube && \

    wget https://mirrors.cloud.tencent.com/apache/streampark/2.1.5/apache-streampark_2.12-2.1.5-incubating-bin.tar.gz && \
    tar xf apache-streampark_2.12-2.1.5-incubating-bin.tar.gz -C ~/apache-streampark_2.12-2.1.5 --strip-components=1 && \

    wget -O ~/apache-streampark_2.12-2.1.5/lib/mysql-connector-java-8.0.28.jar \
https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.28/mysql-connector-java-8.0.28.jar

RUN echo "\
sed -i '/^datasource:/,/^streampark:/ s/^  dialect:.*/  dialect: mysql/' ~/apache-streampark_2.12-2.1.5/conf/config.yaml && \
sed -i '/^datasource:/,/^streampark:/ s/^  username:.*/  username: root/' ~/apache-streampark_2.12-2.1.5/conf/config.yaml && \
sed -i '/^datasource:/,/^streampark:/ s/^  password:.*/  password: Admin@2025/' ~/apache-streampark_2.12-2.1.5/conf/config.yaml && \
sed -i '/^datasource:/,/^streampark:/ s|^  url:.*|  url: jdbc:mysql://streampark-mysql-headless:3306/streampark?useUnicode=true\&characterEncoding=UTF-8\&useJDBCCompliantTimezoneShift=true\&useLegacyDatetimeCode=false\&serverTimezone=GMT%2B8|' ~/apache-streampark_2.12-2.1.5/conf/config.yaml && \
sed -i '/  url:/a\  driver-class-name: com.mysql.cj.jdbc.Driver' ~/apache-streampark_2.12-2.1.5/conf/config.yaml && \
sed -i '/  h2-data-dir:/d' ~/apache-streampark_2.12-2.1.5/conf/config.yaml" > 0.sh
EOF
````

````shell
sed -i '/^datasource:/,/^streampark:/ {
    s/^  dialect:.*/  dialect: mysql/
    s/^  username:.*/  username: root/
    s/^  password:.*/  password: Admin@2025/
    s|^  url:.*|  url: jdbc:mysql://streampark-mysql-headless:3306/streampark?useUnicode=true\&characterEncoding=UTF-8\&useJDBCCompliantTimezoneShift=true\&useLegacyDatetimeCode=false\&serverTimezone=GMT%2B8|
    /  url:/a\  driver-class-name: com.mysql.cj.jdbc.Driver
    /  h2-data-dir:/d
}' config.yaml
````

````shell
cat > ~/k8s-streampark-yml/build.sh << 'EOF'
docker build -t ccr.ccs.tencentyun.com/huanghuanhui/streampark:dev .

docker push ccr.ccs.tencentyun.com/huanghuanhui/streampark:dev
EOF
````

```shell
docker run -it --rm  ccr.ccs.tencentyun.com/huanghuanhui/streampark:dev  sh
```

````shell
cat > streampark-mysql.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: streampark-mysql-config
  namespace: streampark
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
  name: streampark-mysql
  namespace: streampark
spec:
  serviceName: streampark-mysql-headless
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
        image: registry.cn-hangzhou.aliyuncs.com/jingsocial/mysql:8.0.28
        imagePullPolicy: IfNotPresent
        ports:
        - name: mysql
          containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "Admin@2024"
#        resources:
#          limits:
#            cpu: 2
#            memory: 4Gi
#          requests:
#            cpu: 2
#            memory: 4Gi
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
        - name: streampark-mysql-config
          mountPath: /etc/mysql/my.cnf
          subPath: my.cnf
        - mountPath: /etc/localtime
          name: localtime
      volumes:
      - name: streampark-mysql-config
        configMap:
          name: streampark-mysql-config
      - name: localtime
        hostPath:
          path: /etc/localtime
  volumeClaimTemplates:
  - metadata:
      name: mysql-data-pvc
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
  name: streampark-mysql-headless
  namespace: streampark
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
  name: streampark-mysql
  namespace: streampark
  labels:
    app: mysql
spec:
  type: NodePort
  ports:
  - port: 3306
    targetPort: 3306
    nodePort: 30339
  selector:
    app: mysql
EOF
````

````shell
mkdir -p ~/streampark-yml/2.1.5-sql

# sql
mysql-schema.sql
mysql-data.sql

wget https://github.com/apache/streampark/raw/refs/tags/v2.1.5/streampark-console/streampark-console-service/src/main/assembly/script/schema/mysql-schema.sql

wget https://github.com/apache/streampark/raw/refs/tags/v2.1.5/streampark-console/streampark-console-service/src/main/assembly/script/data/mysql-data.sql
````

````shell
cat > streampark.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: streampark
  namespace: streampark
spec:
  replicas: 1
  selector:
    matchLabels:
      app: streampark
  template:
    metadata:
      labels:
        app: streampark
    spec:
      containers:
      - name: streampark-docker
        image: registry.cn-hangzhou.aliyuncs.com/jingsocial/streampark:dev
        imagePullPolicy: Always
        ports:
        - name: http
          containerPort: 10000
        command:
        - /bin/sh
        - -c
        - |
          export JAVA_HOME=/usr/lib/jvm/java-1.8-openjdk
          /app/run/streampark_2.12-2.1.5/bin/startup.sh
          sleep 9999d
        livenessProbe:
          tcpSocket:
            port: 10000
          initialDelaySeconds: 30
          periodSeconds: 30
        readinessProbe:
          tcpSocket:
            port: 10000
          initialDelaySeconds: 30
          periodSeconds: 30
        volumeMounts:
        - name: docker-socket
          mountPath: /var/run
        - name: kubeconfig
          mountPath: /root/.kube/config
          subPath: config
        - name: flink-data
          mountPath: /data
      - name: dockerd
        image: registry.cn-hangzhou.aliyuncs.com/jingsocial/docker:27.1.1-dind
        imagePullPolicy: IfNotPresent
        securityContext:
          privileged: true
        volumeMounts:
        - name: docker-socket
          mountPath: /var/run
      volumes:
      - name: docker-socket
        emptyDir: {}
      - name: kubeconfig
        configMap:
          name: kubeconfig
      - name: flink-data
        persistentVolumeClaim:
          claimName: flink-data        
---
apiVersion: v1
kind:  PersistentVolumeClaim
metadata:
  name: flink-data
  namespace: streampark
spec:
  storageClassName: "dev-sc"
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 2Ti
---
apiVersion: v1
kind: Service
metadata:
  name: streampark
  namespace: streampark
  labels:
    app: streampark
spec:
  type: NodePort
  ports:
  - port: 10000
    targetPort: 10000
    nodePort: 31110
  selector:
    app: streampark
EOF
````

````shell
kubectl create configmap kubeconfig --from-file=config -n streampark
````

```shell
kubectl apply -f ~/streampark-yml/streampark.yml
```



