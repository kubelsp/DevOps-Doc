###### k8s-mysql-master

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
kubectl apply -f ~/mysql-yml/mysql-master-exporter.yml
```

###### k8s-mysql-slave1

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
kubectl apply -f ~/mysql-yml/mysql-slave1-exporter.yml
```

###### k8s-mysql-slave2

```shell
cat > ~/mysql-yml/mysql-slave2-exporter.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mysql-slave2-exporter
  namespace: mysql
  labels:
    app: mysql-slave2-exporter
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mysql-slave2-exporter
  template:
    metadata:
      labels:
        app: mysql-slave2-exporter
    spec:
      containers:
      - name: mysql-slave2-exporter
        image: prom/mysqld-exporter:latest
        imagePullPolicy: IfNotPresent
        env:
        - name: DATA_SOURCE_NAME
          value: root:Admin@2024@(mysql-slave2-headless.mysql.svc.cluster.local:3306)/
        ports:
        - containerPort: 9104
        
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: mysql-slave2-exporter
  name: mysql-slave2-exporter
  namespace: mysql
spec:
  type: ClusterIP
  ports:
  - name: metrics
    port: 9104
    protocol: TCP
    targetPort: 9104
  selector:
   app: mysql-slave2-exporter
EOF
```

```shell
kubectl apply -f ~/mysql-yml/mysql-slave2-exporter.yml
```


```shell
      - job_name: 'k8s-mysql-master'
        static_configs:
          - targets: ['mysql-master-exporter.mysql.svc.cluster.local:9104']

      - job_name: 'k8s-mysql-slave1'
        static_configs:
          - targets: ['mysql-slave1-exporter.mysql.svc.cluster.local:9104']

      - job_name: 'k8s-mysql-slave2'
        static_configs:
          - targets: ['mysql-slave2-exporter.mysql.svc.cluster.local:9104']
```

```shell
14057

7362
```

