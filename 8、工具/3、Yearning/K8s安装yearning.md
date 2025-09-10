## K8s安装yearning

```shell
cat > ~/yearning-yml/yearning-mysql.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: yearning-mysql
  namespace: yearning
  labels:
    app: mysql 
spec:
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
        image: mysql:5.7.40
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 3306
        volumeMounts:
        - name: mysql-data
          mountPath: /var/lib/mysql
        - mountPath: /etc/localtime
          name: localtime
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "Admin@2023"
        - name: MYSQL_DATABASE
          value: "Yearning"
        - name: MYSQL_USER
          value: "yearning"
        - name: MYSQL_PASSWORD
          value: "yearning@2023"
      volumes:
      - name: mysql-data
        persistentVolumeClaim:
          claimName: yearning-mysql-pvc
      - name: localtime
        hostPath:
          path: /etc/localtime

---
apiVersion: v1
kind:  PersistentVolumeClaim
metadata:
  name: yearning-mysql-pvc
  namespace: yearning
spec:
  storageClassName: nfs-prod
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 100Gi

---
apiVersion: v1
kind: Service
metadata:
  name: yearning-mysql
  namespace: yearning
  labels:
    app: mysql
spec:
  type: NodePort
  ports:
  - port: 3306
    targetPort: 3306
    nodePort: 30036
  selector:
    app: mysql
EOF
```



#### Secret

```shell
echo -n '172.16.251.0' | base64   MTcyLjE2LjI1MS4w
echo -n 'yearning' | base64      eWVhcm5pbmc=
echo -n 'yearning@2023' | base64   eWVhcm5pbmdAMjAyMw==
echo -n 'Yearning' | base64    WWVhcm5pbmc=
echo -n 'abcdefghijklmnop' | base64    YWJjZGVmZ2hpamtsbW5vcA==
```

```shell
cat > secret.yml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: db-conf
  namespace: yearning
type: Opaque
stringData:
  addr: '172.16.251.0'
  user: 'yearning'
  pass: 'yearning@2023'
  data: 'Yearning'
  sk: 'dbcjqheupqjsuwsm'
EOF
```

```shell
cat > secret.yml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: db-conf
  namespace: yearning
type: Opaque
data:
  addr: MTcyLjE2LjI1MS4w
  user: eWVhcm5pbmc=
  pass: eWVhcm5pbmdAMjAyMw==
  data: WWVhcm5pbmc=
  sk: VzMyMTMxMjNWaGNtNWpibWM9
EOF
```

Yearning_admin

#### Service

```shell
cat > svc.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  labels:
    app: yearning
  name: yearning
  namespace: yearning
spec:
  ports:
    - port: 80  # svc内部端口，通过clusterIP访问
      protocol: TCP
      targetPort: 8000  # 镜像内服务的端口
  selector: # 标签选择器，与deployment中的标签保持一致
    app: yearning
  type: NodePort  # Service类型
EOF
```

#### Ingress

```shell
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: yearning
  namespace: yearning
spec:
  rules:
    - host: yearning.io
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: yearning
                port:
                  number: 80
```

#### Deployment

```shell
cat > deployment.yml << 'EOF'
apiVersion: apps/v1 # API版泵
kind: Deployment  # 资源类型
metadata: # 元数据
  labels: # 标签
    app: yearning
  name: yearning  # deployment的名字
  namespace: yearning  # 所属命名空间
spec: 
  replicas: 1 # 副本数
  selector: # 选择器，选择针对谁做
    matchLabels:
      app: yearning
  template: # 镜像的模板
    metadata: # 元数据
      labels: # 标签
        app: yearning
    spec:
      containers: # 容器信息
        - image: yeelabs/yearning:v3.1.4  # 容器镜像
          name: yearning # 容器的名字
          imagePullPolicy: IfNotPresent # 镜像的下载策略
          env:  # 容器中的变量
            - name: MYSQL_ADDR
              valueFrom:
                secretKeyRef: # 存储的变量信息
                  name: db-conf
                  key: addr
            - name: MYSQL_USER
              valueFrom:
                secretKeyRef:
                  name: db-conf
                  key: user
            - name: MYSQL_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: db-conf
                  key: pass
            - name: MYSQL_DB
              valueFrom:
                secretKeyRef:
                  name: db-conf
                  key: data
            - name: SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: db-conf
                  key: sk
          ports:    # 定义容器中的端口信息
            - containerPort: 8000
              name: web
              protocol: TCP
          readinessProbe:   # 就绪检查
            httpGet:
              path: /
              port: web
              scheme: HTTP
            initialDelaySeconds: 25
            periodSeconds: 2
          livenessProbe:    # 存活检查
            httpGet:
              path: /
              port: web
              scheme: HTTP
            initialDelaySeconds: 30
            periodSeconds: 2
          resources:    # 资源限制
            requests:
              cpu: 200m
              memory: 1Gi
            limits:
              cpu: 250m
              memory: 2Gi
EOF
```

```sql
DROP TABLE IF EXISTS core_accounts;
```

```sql
CREATE TABLE core_accounts (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(255) NOT NULL,
  password VARCHAR(255) NOT NULL,
  department VARCHAR(255),
  real_name VARCHAR(255),
  email VARCHAR(255),
  is_recorder INT DEFAULT 0,
  query_password VARCHAR(255)
);
```

```shell
INSERT INTO `core_accounts` (`username`,`password`,`department`,`real_name`,`email`,`is_recorder`,`query_password`) VALUES ('admin','pbkdf2_sha256$120000$QWf3T7M2d0Iz$zij2XpBg0bqCmWEvIA8Smc6DZbYhVLwvxaqGwPGhIPc=','DBA','超级管理员','',0,'');
```

```sql
select * from core_accounts;
```



```shell
wget https://github.com/cookieY/Yearning/releases/download/v3.1.4/Yearning-v3.1.4-linux-amd64.zip
```



```shell
重启pod
```



==

```shell
docker run -d \
  --name yearning-mysql \
  --restart always \
  --privileged=true \
  -p 3336:3306 \
  -v ~/yearning-mysql-data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=Admin@2023 \
  mysql:5.7.40
```

```shell
#  查看数据库
show databases;

# 创建数据库
CREATE DATABASE `Yearning` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

# 删除数据库
drop database Yearning
```

```shell
docker run -d -it \
  --restart always \
  --privileged=true \
    --name yearning \
           -p 30132:8000 -e IS_DOCKER=is_docker \
           -e SECRET_KEY=dbcjqheupqjsuwsm \
           -e MYSQL_USER=root \
           -e MYSQL_ADDR=10.80.20.16:3336 \
           -e MYSQL_PASSWORD=Admin@2023 \
           -e MYSQL_DB=Yearning \
           chaiyd/yearning:v2.3.5
```

```shell
dengrengui
Dengrengui@2023
```

