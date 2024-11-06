```shell
mkdir -p ~/zookeeper-yml

kubectl create ns zookeeper
```

```shell
cat > ~/zookeeper-yml/zookeeper.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: zookeeper
  namespace: zookeeper
spec:
  serviceName: "zookeeper-headless"
  replicas: 1
  selector:
    matchLabels:
      app: zookeeper
  template:
    metadata:
      labels:
        app: zookeeper
    spec:
      containers:
      - name: zookeeper
        #image: zookeeper:3.9.2
        image: ccr.ccs.tencentyun.com/huanghuanhui/zookeeper:3.9.2
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 2181
          name: client
        - containerPort: 2888
          name: follower
        - containerPort: 3888
          name: leader
        volumeMounts:
        - name: datadir
          mountPath: /data
  volumeClaimTemplates:
  - metadata:
      name: datadir
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: nfs-storage
      resources:
        requests:
          storage: 10Gi
EOF
```

```shell
kubectl exec -it zookeeper-0 -- zkCli.sh -server 127.0.0.1:2181
```

```shell
kubectl exec -it zookeeper-0 -- zkServer.sh status
```



