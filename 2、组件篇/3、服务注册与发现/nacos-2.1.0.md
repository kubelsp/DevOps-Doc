### nacos-2.1.0

```shell
mkdir -p ~/nacos-yml

kubectl create ns nacos
```

```shell
cat > ~/nacos-yml/nacos-mysql.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
  namespace: nacos
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
        #image: mysql:5.7.44
        image: ccr.ccs.tencentyun.com/huanghuanhui/mysql:5.7.44
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            cpu: "2"
            memory: "4Gi"
          requests:
            cpu: "2"
            memory: "4Gi"
        ports:
        - name: mysql
          containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "Admin@2024"
        - name: MYSQL_DATABASE
          value: "nacos"
        - name: MYSQL_USER
          value: "nacos"
        - name: MYSQL_PASSWORD
          value: "nacos@2024"
        volumeMounts:
        - name: nacos-mysql-data-pvc
          mountPath: /var/lib/mysql
        - mountPath: /etc/localtime
          name: localtime
      volumes:
      - name: localtime
        hostPath:
          path: /etc/localtime
  volumeClaimTemplates:
  - metadata:
      name: nacos-mysql-data-pvc
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: nfs-storage
      resources:
        requests:
          storage: 10Gi

---
apiVersion: v1
kind: Service
metadata:
  name: mysql-headless
  namespace: nacos
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
EOF
```

```shell
kubectl apply -f ~/nacos-yml/nacos-mysql.yml
```

```shell
# https://github.com/alibaba/nacos/blob/2.1.0/config/src/main/resources/META-INF/nacos-db.sql（sql地址）

# cd ~/nacos-yml && wget https://github.com/alibaba/nacos/raw/2.1.0/config/src/main/resources/META-INF/nacos-db.sql

cd ~/nacos-yml && wget https://gitee.com/kubelsp/upload/raw/master/nacos/2.1.0/nacos-db.sql

kubectl cp nacos-db.sql mysql-0:/
kubectl exec mysql-0 -- mysql -pAdmin@2024 -e "use nacos;source /nacos-db.sql;"

kubectl exec mysql-0 -- mysql -pAdmin@2024 -e "use nacos;show tables;"
```

```shell
cat > ~/nacos-yml/nacos-v2.1.0.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: nacos-headless
  namespace: nacos
  labels:
    app: nacos
spec:
  clusterIP: None
  ports:
    - port: 8848
      name: server
      targetPort: 8848
    - port: 9848
      name: client-rpc
      targetPort: 9848
    - port: 9849
      name: raft-rpc
      targetPort: 9849
    ## 兼容1.4.x版本的选举端口
    - port: 7848
      name: old-raft-rpc
      targetPort: 7848
    - port: 18848
      name: mcp 
      targetPort: 18848
  selector:
    app: nacos

---
apiVersion: v1
kind: Service
metadata:
  name: nacos
  namespace: nacos
  labels:
    app: nacos
spec:
  type: NodePort
  ports:
    - port: 8848
      name: server
      targetPort: 8848
      nodePort: 31000
    - port: 9848
      name: client-rpc
      targetPort: 9848
      nodePort: 32000
    - port: 9849
      name: raft-rpc
      nodePort: 32001
    ## 兼容1.4.x版本的选举端口
    - port: 7848
      name: old-raft-rpc
      targetPort: 7848
      nodePort: 30000
    - port: 18848
      name: mcp
      targetPort: 18848
      nodePort: 30001
  selector:
    app: nacos

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: nacos-cm
  namespace: nacos
data:
  mysql.host: "mysql-headless.nacos.svc.cluster.local"
  mysql.db.name: "nacos"
  mysql.port: "3306"
  mysql.user: "nacos"
  mysql.password: "nacos@2024"

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nacos
  namespace: nacos
spec:
  serviceName: nacos-headless
  replicas: 3
  template:
    metadata:
      labels:
        app: nacos
      annotations:
        pod.alpha.kubernetes.io/initialized: "true"
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: "app"
                    operator: In
                    values:
                      - nacos-headless
              topologyKey: "kubernetes.io/hostname"
      containers:
        - name: k8snacos
          #image: nacos/nacos-server:v2.1.0
          #image: ccr.ccs.tencentyun.com/huanghuanhui/nacos-server:v2.1.0
          #image: ccr.ccs.tencentyun.com/huanghuanhui/nacos-server:v2.2.0-metrics
          image: ccr.ccs.tencentyun.com/huanghuanhui/nacos-server:v2.1.0-istio-metrics
          imagePullPolicy: IfNotPresent
          resources:
            limits:
              cpu: 2
              memory: 4Gi
            requests:
              cpu: 2
              memory: 4Gi
          ports:
            - containerPort: 8848
              name: client
            - containerPort: 9848
              name: client-rpc
            - containerPort: 9849
              name: raft-rpc
            - containerPort: 7848
              name: old-raft-rpc
            - containerPort: 18848
              name: mcp
          livenessProbe:
            httpGet:
              path: /nacos/actuator/health
              port: 8848
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /nacos/actuator/health
              port: 8848
            initialDelaySeconds: 30
            periodSeconds: 10
          env:
            - name: NACOS_REPLICAS
              value: "3"
            - name: MYSQL_SERVICE_HOST
              valueFrom:
                configMapKeyRef:
                  name: nacos-cm
                  key: mysql.host
            - name: MYSQL_SERVICE_DB_NAME
              valueFrom:
                configMapKeyRef:
                  name: nacos-cm
                  key: mysql.db.name
            - name: MYSQL_SERVICE_PORT
              valueFrom:
                configMapKeyRef:
                  name: nacos-cm
                  key: mysql.port
            - name: MYSQL_SERVICE_USER
              valueFrom:
                configMapKeyRef:
                  name: nacos-cm
                  key: mysql.user
            - name: MYSQL_SERVICE_PASSWORD
              valueFrom:
                configMapKeyRef:
                  name: nacos-cm
                  key: mysql.password
            - name: SPRING_DATASOURCE_PLATFORM
              value: "mysql"
            - name: MODE
              value: "cluster"
            - name: NACOS_SERVER_PORT
              value: "8848"
            - name: PREFER_HOST_MODE
              value: "hostname"
            - name: NACOS_SERVERS
              value: "nacos-0.nacos-headless.nacos.svc.cluster.local:8848 nacos-1.nacos-headless.nacos.svc.cluster.local:8848 nacos-2.nacos-headless.nacos.svc.cluster.local:8848"
  selector:
    matchLabels:
      app: nacos
EOF
```

```shell
kubectl apply -f ~/nacos-yml/nacos-v2.1.0.yml
```

```shell
cat > ~/nacos-yml/nacos-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nacos-ingress
  namespace: nacos
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: nacos.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nacos-headless
            port:
              number: 8848

  tls:
  - hosts:
    - nacos.openhhh.com
    secretName: nacos-ingress-tls
EOF
```

```shell
kubectl create secret -n nacos \
tls nacos-ingress-tls \
--key=/root/ssl/openhhh.com.key \
--cert=/root/ssl/openhhh.com.pem
```

```shell
kubectl apply -f ~/nacos-yml/nacos-Ingress.yml
```

```shell
kubectl exec -it nacos-0 bash

# 进容器里面执行
curl -X POST 'http://nacos-headless.nacos.svc.cluster.local:8848/nacos/v1/ns/instance?serviceName=nacos.naming.serviceName&ip=20.18.7.10&port=8080'

# 容器外执行
curl -X POST 'http://192.168.1.200:31000/nacos/v1/ns/instance?serviceName=nacos.naming.serviceName&ip=20.18.7.10&port=8080'
```

> 代码连接地址：nacos-headless.nacos.svc.cluster.local:8848
>
> 访问地址ip：http://192.168.1.200:31000/nacos/#/login
>
> 访问地址域名：https://nacos.openhhh.com/nacos/#/login
>
> 默认用户密码：nacos、nacos
>
> 用户密码：nacos、nacos@2024


````shell
docker pull nacos/nacos-server:v2.1.0

docker tag nacos/nacos-server:v2.1.0 ccr.ccs.tencentyun.com/huanghuanhui/nacos-server:v2.1.0

docker push ccr.ccs.tencentyun.com/huanghuanhui/nacos-server:v2.1.0
````

````shell
cat > Dockerfile << 'EOF'
# 使用 nacos 官方镜像作为基础镜像
FROM nacos/nacos-server:v2.1.0

# 在容器内执行命令，将指定内容追加到 application.properties 文件中
RUN echo "nacos.istio.mcp.server.enabled=true" >> /home/nacos/conf/application.properties && \
    echo "management.endpoints.web.exposure.include=*" >> /home/nacos/conf/application.properties
EOF

docker build -t ccr.ccs.tencentyun.com/huanghuanhui/nacos-server:v2.1.0-istio-metrics .

docker push ccr.ccs.tencentyun.com/huanghuanhui/nacos-server:v2.1.0-istio-metrics
````

```shell
cat > Dockerfile << 'EOF'
# 使用 nacos 官方镜像作为基础镜像
FROM nacos/nacos-server:v2.1.0

# 在容器内执行命令，将指定内容追加到 application.properties 文件中
RUN echo "management.endpoints.web.exposure.include=*" >> /home/nacos/conf/application.properties
EOF

docker build -t ccr.ccs.tencentyun.com/huanghuanhui/nacos-server:v2.1.0-metrics .

docker push ccr.ccs.tencentyun.com/huanghuanhui/nacos-server:v2.1.0-metrics
```

