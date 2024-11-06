### redis-7.2.4

###### 1、（单机）

```shell
mkdir -p ~/redis-yml

kubectl create ns redis
```

```shell
cat > ~/redis-yml/redis-ConfigMap.yml << 'EOF'
kind: ConfigMap
apiVersion: v1
metadata:
  name: redis-cm
  namespace: redis
  labels:
    app: redis
data:
  redis.conf: |-
    dir /data
    port 6379
    bind 0.0.0.0
    appendonly yes
    protected-mode no
    requirepass Admin@2024
    pidfile /data/redis-6379.pid 
    save 900 1
    save 300 10
    save 60 10000
    appendfsync always
EOF
```

> \# 开启 RDB 持久化 
>
> save 900 1   # 在900秒（15分钟）内，如果至少有1个 key 发生变化，则执行一次持久化 
>
> save 300 10  # 在300秒（5分钟）内，如果至少有10个 key 发生变化，则执行一次持久化 
>
> save 60 10000  # 在60秒（1分钟）内，如果至少有10000个 key 发生变化，则执行一次持久化 
>
> 开启 AOF 持久化 
>
> appendfsync always  #每次写入都会立即同步到磁盘

```shell
kubectl apply -f ~/redis-yml/redis-ConfigMap.yml
```

```shell
cat > ~/redis-yml/redis-StatefulSet.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis
  namespace: redis
spec:
  replicas: 1
  serviceName: redis
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      name: redis
      labels:
        app: redis
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: redis
              topologyKey: kubernetes.io/hostname
      containers:
      - name: redis
        #image: redis:7.2.4-alpine
        image: ccr.ccs.tencentyun.com/huanghuanhui/redis:7.2.4-alpine
        imagePullPolicy: IfNotPresent
        env:
        - name: TZ
          value: Asia/Shanghai
        command:
          - "sh"
          - "-c"
          - "redis-server /etc/redis/redis.conf"
        ports:
        - containerPort: 6379
          name: tcp-redis
          protocol: TCP
        resources:
          limits:
            cpu: "2"
            memory: "4Gi"
          requests:
            cpu: "1"
            memory: "2Gi"
        volumeMounts:
          - name: redis-data
            mountPath: /data
          - name: config
            mountPath: /etc/redis/redis.conf
            subPath: redis.conf
      volumes:
        - name: config
          configMap:
            name: redis-cm
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      storageClassName: "nfs-storage"
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 2Ti
EOF
```

```shell
kubectl apply -f ~/redis-yml/redis-StatefulSet.yml
```

```shell
cat > ~/redis-yml/redis-Service.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: redis
spec:
  type: NodePort
  ports:
    - name: redis
      port: 6379
      targetPort: 6379
      protocol: TCP
      nodePort: 30078
  selector:
    app: redis
EOF
```

```shell
kubectl apply -f ~/redis-yml/redis-Service.yml
```

> 访问地址：ip：192.168.1.200（端口30078）
>
> 代码连接地址：redis.redis.svc.cluster.local:6379
>
> 密码：Admin@2024

###### for循环写10000个key做测试

```shell
cat > set_keys.sh << 'EOF'
#!/bin/bash

REDIS_HOST="192.168.1.200"
REDIS_PORT="30078"
REDIS_PASSWORD="Admin@2024"

for i in {1..10000}
do
  KEY="mykey$i"
  VALUE="myvalue$i"

  redis-cli -h $REDIS_HOST -p $REDIS_PORT -a $REDIS_PASSWORD SET $KEY "$VALUE"
done
EOF


chmod +x set_keys.sh

./set_keys.sh
```

###### 2、（分片集群）

helm 安装 bitnami-redis-cluster

> 版本：redis-7.2.4

```shell
helm repo add bitnami https://charts.bitnami.com/bitnami

helm repo update

helm search repo bitnami/redis

cd && helm pull bitnami/redis-cluster --version 9.3.0 --untar
```

```shell
cat > ~/redis-cluster/values-prod.yml << EOF
global:
  storageClass: "nfs-storage"
  redis:
    password: "Admin@2024"
    
redis:
  livenessProbe:
    enabled: true
    initialDelaySeconds: 60
    periodSeconds: 5
    timeoutSeconds: 5
    successThreshold: 1
    failureThreshold: 5
  readinessProbe:
    enabled: true
    initialDelaySeconds: 60
    periodSeconds: 5
    timeoutSeconds: 1
    successThreshold: 1
    failureThreshold: 5

persistence:
  enabled: true
  size: 100Gi
  
service:
  ports:
    redis: 6379
  type: NodePort
  nodePorts:
    redis: 30079

metrics:
  enabled: true
EOF
```

```shell
kubectl create ns redis-cluster

helm upgrade --install --namespace redis-cluster redis-cluster -f ./values-prod.yml .
```

```shell
kubectl logs -f redis-cluster-0 -c redis-cluster
```

```shell
kubectl get secret --namespace "redis-cluster" redis-cluster -o jsonpath="{.data.redis-password}" | base64 -d
```

```shell
kubectl exec -it redis-cluster-0 -- redis-cli -c -h redis-cluster -a Admin@2024

kubectl exec -it redis-cluster-0 -- redis-cli -c  -h 192.168.1.200 -p 30079 -a Admin@2024
```

```shell
kubectl expose pod redis-cluster-0 --type=NodePort --name=redis-cluster-0
kubectl expose pod redis-cluster-1 --type=NodePort --name=redis-cluster-1
kubectl expose pod redis-cluster-2 --type=NodePort --name=redis-cluster-2
kubectl expose pod redis-cluster-3 --type=NodePort --name=redis-cluster-3
kubectl expose pod redis-cluster-4 --type=NodePort --name=redis-cluster-4
kubectl expose pod redis-cluster-5 --type=NodePort --name=redis-cluster-5
```

```shell
# 查看集群状态
> cluster info
> cluster nodes
```

> 代码连接地址：redis-cluster-headless.redis-cluster.svc.cluster.local:6379
>
> 密码：Admin@2024

RedisInsight（可视化工具）

```shell
cat > ~/redis-cluster/RedisInsight-Deployment.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata: 
  name: redisinsight
  namespace: redis-cluster
spec:
  replicas: 1
  selector: 
    matchLabels:
      app: redisinsight
  template: 
    metadata: 
      labels: 
        app: redisinsight
    spec:
      containers:
      - name: redisinsight
        image: redislabs/redisinsight:1.14.0
        imagePullPolicy: IfNotPresent
        ports: 
        - containerPort: 8001
        volumeMounts: 
        - name: db
          mountPath:  /db
        - mountPath: /etc/localtime
          name: localtime
      volumes:
      - name: db
        persistentVolumeClaim:
          claimName: redisinsight-db
      - name: localtime
        hostPath:
          path: /etc/localtime
---
apiVersion: v1
kind:  PersistentVolumeClaim
metadata:
  name: redisinsight-db
  namespace: redis-cluster
spec:
  storageClassName: "nfs-storage"
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 2Ti

---
apiVersion: v1
kind: Service
metadata:
  name: redisinsight-service
  namespace: redis-cluster
spec:
  type: NodePort
  ports:
  - port: 8001
    targetPort: 8001
    nodePort: 31888
  selector:
    app: redisinsight
EOF
```

```shell
kubectl apply -f ~/redis-cluster/RedisInsight-Deployment.yml
```

> ip访问：192.168.1.200:31888

```shell
cat > ~/redis-cluster/RedisInsight-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: redisinsight-ingress
  namespace: redis-cluster
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: redisinsight.huanghuanhui.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: redisinsight-service
            port:
              number: 8001

  tls:
  - hosts:
    - redisinsight.huanghuanhui.cloud
    secretName: redisinsight-ingress-tls
EOF
```

```shell
kubectl create secret -n redis-cluster \
tls redisinsight-ingress-tls \
--key=/root/ssl/huanghuanhui.cloud.key \
--cert=/root/ssl/huanghuanhui.cloud.crt
```

```shell
kubectl apply -f ~/redis-cluster/RedisInsight-Ingress.yml
```

> 访问地址：redisinsight.huanghuanhui.cloud

