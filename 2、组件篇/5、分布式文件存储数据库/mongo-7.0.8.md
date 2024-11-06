### mongo-7.0.5

1、（单机）

```shell
mkdir -p ~/mongodb-yml

kubectl create ns mongodb
```

```shell
cat > ~/mongodb-yml/mongodb-StatefulSet.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
  namespace: mongodb
spec:
  replicas: 1
  serviceName: mongodb-headless
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: mongodb
              topologyKey: kubernetes.io/hostname
      containers:
      - name: mongodb
        #image: mongo:7.0.8
        image: ccr.ccs.tencentyun.com/huanghuanhui/mongo:7.0.8
        imagePullPolicy: IfNotPresent
        env:
          - name: MONGO_INITDB_ROOT_USERNAME
            value: root
          - name: MONGO_INITDB_ROOT_PASSWORD
            value: 'Admin@2024'
        ports:
          - containerPort: 27017
        volumeMounts:
          - name: mongo-data
            mountPath: /data/db
          - mountPath: /etc/localtime
            name: localtime
      volumes:
        - name: mongo-data
          persistentVolumeClaim:
            claimName: mongodb-pvc
        - name: localtime
          hostPath:
            path: /etc/localtime
  volumeClaimTemplates:
  - metadata:
      name: mongo-data
    spec:
      storageClassName: "nfs-storage"
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 2Ti
EOF
```

```shell
kubectl apply -f ~/mongodb-yml/mongodb-StatefulSet.yml
```

```shell
cat > ~/mongodb-yml/mongodb-Service.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: mongodb-headless
  namespace: mongodb
  labels:
    app: mongodb
spec:
  clusterIP: None
  ports:
    - port: 27017
      name: mongodb
      targetPort: 27017
  selector:
    app: mongodb
    
---
apiVersion: v1
kind: Service
metadata:
  name: mongodb-service
  namespace: mongodb
spec:
  type: NodePort
  ports:
    - name: mongodb
      port: 27017
      targetPort: 27017
      protocol: TCP
      nodePort: 30017
  selector:
    app: mongodb
EOF
```

```shell
kubectl apply -f ~/mongodb-yml/mongodb-Service.yml
```

> 代码连接地址：mongodb-headless.mongodb.svc.cluster.local:27017
>
> Navicat 连接地址：ip：192.168.1.200、端口：30017
>
> 用户密码：root、Admin@2024（默认数据库admin）

2、（分片集群）

helm 安装 bitnami-mongodb-sharded-7.4.0

> 版本：mongodb-7.0.5

```shell
helm repo add bitnami https://charts.bitnami.com/bitnami

helm repo update

helm search repo bitnami/mongodb-sharded

cd && helm pull bitnami/mongodb-sharded --version 7.4.0 --untar
```

最小分片

```shell
cat > ~/mongodb-sharded/values-prod.yml << EOF
global:
  storageClass: "nfs-storage"
auth:
  rootPassword: "Admin@2024"

service:
  ports:
    mongodb: 27017
  type: NodePort
  nodePorts:
    mongodb: 30018
    
metrics:
  enabled: true
EOF
```

推荐分片

```shell
cat > ~/mongodb-sharded/values-prod.yml << EOF
global:
  storageClass: "nfs-storage"
auth:
  rootPassword: "Admin@2024"

##### 配置多副本 #######
shards: 4 # 分片数

shardsvr:
  dataNode:
    replicaCount: 2 # 分片数副本数
  persistence:
    enabled: true
    size: 100Gi

configsvr: # 配置服务器
  replicaCount: 3
  persistence:
    enabled: true
    size: 10Gi

mongos: # 路由
  replicaCount: 3


##### 配置多副本 #######

service:
  ports:
    mongodb: 27017
  type: NodePort
  nodePorts:
    mongodb: 30018
    
metrics:
  enabled: true
  image:
    pullPolicy: IfNotPresent
EOF
```

```shell
kubectl create ns mongodb-sharded

helm upgrade --install --namespace mongodb-sharded mongodb-sharded -f ./values-prod.yml .
```

```shell
kubectl logs -f mongodb-sharded-shard0-data-0 -c mongodb
```

```shell
kubectl get secret --namespace mongodb-sharded mongodb-sharded -o jsonpath="{.data.mongodb-root-password}" | base64 -d
```

```shell
kubectl exec -it mongodb-sharded-shard0-data-0 -- mongosh --host mongodb-sharded --port 27017 --authenticationDatabase admin -u root -p Admin@2024

kubectl exec -it mongodb-sharded-shard0-data-0 -- mongosh --host 192.168.1.200 --port 30018 --authenticationDatabase admin -u root -p Admin@2024
```

> 代码连接地址：mongodb-sharded-headless.mongodb-sharded..svc.cluster.local:27017
>
> Navicat 连接地址：ip：192.168.1.200、端口：30018
>
> 用户密码：root、Admin@2024（默认数据库admin）

