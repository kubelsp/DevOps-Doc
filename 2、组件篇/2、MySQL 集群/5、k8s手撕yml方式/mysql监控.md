```shell
cat > ~/mysql-yml/mysql-master-exporter.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-master-exporter
  namespace: mysql
  labels:
    app: mysql-master-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql-master-exporter
  template:
    metadata:
      labels:
        app: mysql-master-exporter
    spec:
      containers:
      - name: mysql-master-exporter
        image: prom/mysqld-exporter:latest
        imagePullPolicy: IfNotPresent
        env:
        - name: DATA_SOURCE_NAME
          value: root:Admin@2024@(mysql-master-headless.mysql.svc.cluster.local:3306)/
        ports:
        - containerPort: 9104
        
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: mysql-master-exporter
  name: mysql-master-exporter
  namespace: mysql
spec:
  type: ClusterIP
  ports:
  - name: metrics
    port: 9104
    protocol: TCP
    targetPort: 9104
  selector:
   app: mysql-master-exporter
EOF
```



```shell
cat > ~/mysql-yml/mysql-slave1-exporter.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-slave1-exporter
  namespace: mysql
  labels:
    app: mysql-slave1-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql-slave1-exporter
  template:
    metadata:
      labels:
        app: mysql-slave1-exporter
    spec:
      containers:
      - name: mysql-slave1-exporter
        image: prom/mysqld-exporter:latest
        imagePullPolicy: IfNotPresent
        env:
        - name: DATA_SOURCE_NAME
          value: root:Admin@2024@(mysql-slave1-headless.mysql.svc.cluster.local:3306)/
        ports:
        - containerPort: 9104
        
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: mysql-slave1-exporter
  name: mysql-slave1-exporter
  namespace: mysql
spec:
  type: ClusterIP
  ports:
  - name: metrics
    port: 9104
    protocol: TCP
    targetPort: 9104
  selector:
   app: mysql-slave1-exporter
EOF
```



```shell
cat > ~/mysql-yml/mysql-exporter << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-exporter
  namespace: mysql
  labels:
    app: mysql-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql-exporter
  template:
    metadata:
      labels:
        app: mysql-exporter
    spec:
      containers:
      - name: mysql-exporter
        image: prom/mysqld-exporter:latest
        imagePullPolicy: IfNotPresent
        env:
        - name: DATA_SOURCE_NAME
          value: root:huanghuanhui@2023@(sh-cynosdbmysql-grp-388lhjps.sql.tencentcdb.com:26524)/
        ports:
        - containerPort: 9104

---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: mysql-exporter
  name: mysql-exporter
  namespace: mysql
spec:
  type: ClusterIP
  ports:
  - name: metrics
    port: 9104
    protocol: TCP
    targetPort: 9104
  selector:
   app: mysql-exporter
EOF
```

```shell
      - job_name: 'mysql-master-0'
        static_configs:
          - targets: ['mysql-master-exporter.mysql.svc.cluster.local:9104']

      - job_name: 'mysql-slave1-0'
        static_configs:
          - targets: ['mysql-slave1-exporter.mysql.svc.cluster.local:9104']

      - job_name: '腾讯云托管库'
        static_configs:
          - targets: ['mysql-exporter.mysql.svc.cluster.local:9104']
```

```shell
14057

7362
```

