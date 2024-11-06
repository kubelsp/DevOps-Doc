### k8s部署单机nacos2.3.2版本开启鉴权功能

### nacos-2.3.2

```shell
mkdir -p ~/nacos-yml

kubectl create ns nacos
```

````shell
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
#       resources:
#         limits:
#           cpu: "2"
#           memory: "4Gi"
#         requests:
#           cpu: "2"
#           memory: "4Gi"
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
````

```shell
kubectl apply -f ~/nacos-yml/nacos-mysql.yml
```

````shell
# https://github.com/alibaba/nacos/blob/2.3.2/config/src/main/resources/META-INF/mysql-schema.sql（sql地址）

# cd ~/nacos-yml && wget https://github.com/alibaba/nacos/raw/2.3.2/config/src/main/resources/META-INF/mysql-schema.sql

cd ~/nacos-yml && wget https://gitee.com/kubelsp/upload/raw/master/nacos/2.3.2/mysql-schema.sql

kubectl cp mysql-schema.sql mysql-0:/
kubectl exec mysql-0 -- mysql -pAdmin@2024 -e "use nacos;source /mysql-schema.sql;"

kubectl exec mysql-0 -- mysql -pAdmin@2024 -e "use nacos;show tables;"
````

``````shell
cat > ~/nacos-yml/nacos-v2.3.2.yml << 'EOF'
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
kind: Deployment
metadata:
  name: nacos
  namespace: nacos
  labels:
    app: nacos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nacos
  template:
    metadata:
      labels:
        app: nacos
    spec:
      containers:
      - name: nacos
        #image: nacos/nacos-server:v2.3.2
        image: ccr.ccs.tencentyun.com/huanghuanhui/nacos-server:v2.3.2
        imagePullPolicy: IfNotPresent
#       resources:
#         limits:
#           cpu: "2"
#           memory: "4Gi"
#         requests:
#           cpu: "1"
#           memory: "2Gi"
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
        - name: SPRING_DATASOURCE_PLATFORM
          value: "mysql"
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
        - name: MODE
          value: "standalone"
        - name: NACOS_SERVER_PORT
          value: "8848"
        - name: PREFER_HOST_MODE
          value: "hostname"
        - name: NACOS_AUTH_ENABLE #开启鉴权
          value: "true"
        - name: NACOS_AUTH_CACHE_ENABLE #开启鉴权
          value: "true"
        - name: NACOS_AUTH_TOKEN  #默认的token生产环境需要更改，32位的Base64编码
          value: "SecretKey012345678901234567890123456789012345678901234567890123456789"
        - name: NACOS_AUTH_IDENTITY_KEY  #鉴权key
          value: "nacos"
        - name: NACOS_AUTH_IDENTITY_VALUE #鉴权值
          value: "nacos"
          
---
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
EOF
``````


