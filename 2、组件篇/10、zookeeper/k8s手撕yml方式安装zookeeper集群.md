```shell
mkdir -p ~/zookeeper-yml

kubectl create ns zookeeper
```

```shell
cat > ~/zookeeper-yml/zookeeper.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: zookeeper-config
  namespace: zookeeper
data:
  zoo.cfg: |
    tickTime=2000
    initLimit=5
    syncLimit=2
    dataDir=/data
    clientPort=2181
    autopurge.snapRetainCount=3
    autopurge.purgeInterval=1
    server.1=zookeeper-0.zookeeper-headless.zookeeper.svc.cluster.local:2888:3888
    server.2=zookeeper-1.zookeeper-headless.zookeeper.svc.cluster.local:2888:3888
    server.3=zookeeper-2.zookeeper-headless.zookeeper.svc.cluster.local:2888:3888

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: zookeeper
  namespace: zookeeper
spec:
  serviceName: "zookeeper-headless"
  replicas: 3
  selector:
    matchLabels:
      app: zookeeper
  template:
    metadata:
      labels:
        app: zookeeper
    spec:
      initContainers:
      - name: set-myid
        image: ccr.ccs.tencentyun.com/huanghuanhui/busybox:1.36
        command:
        - "sh"
        - "-c"
        - echo $(( $(hostname -s | awk -F '-' '{print $NF}') + 1 )) > /data/myid
        volumeMounts:
        - name: datadir
          mountPath: /data
      containers:
      - name: zookeeper
        #image: zookeeper:3.9.2
        image: ccr.ccs.tencentyun.com/huanghuanhui/zookeeper:3.9.2
        imagePullPolicy: IfNotPresent
        env:
        - name: ALLOW_ANONYMOUS_LOGIN
          value: "yes"
        - name: ZOO_SERVERS
          value: >-
            zookeeper-0.zookeeper-headless-svc.zookeeper.svc.cluster.local:2888:3888
            zookeeper-1.zookeeper-headless-svc.zookeeper.svc.cluster.local:2888:3888
            zookeeper-2.zookeeper-headless-svc.zookeeper.svc.cluster.local:2888:3888
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
        - name: config-volume
          mountPath: /conf/zoo.cfg
          subPath: zoo.cfg
      volumes:
      - name: config-volume
        configMap:
          name: zookeeper-config
      - name: datadir
        emptyDir: {}
  volumeClaimTemplates:
  - metadata:
      name: datadir
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
  name: zookeeper
  namespace: zookeeper
spec:
  ports:
  - port: 2181
    name: client
    nodePort: 30021
  - port: 2888
    name: follower
    nodePort: 30028
  - port: 3888
    name: leader
    nodePort: 30038
  selector:
    app: zookeeper
  type: NodePort

---
apiVersion: v1
kind: Service
metadata:
  name: zookeeper-headless
  namespace: zookeeper
spec:
  ports:
  - port: 2181
    name: client
  - port: 2888
    name: follower
  - port: 3888
    name: leader
  clusterIP: None
  selector:
    app: zookeeper
EOF
```

```shell
kubectl exec -it zookeeper-0 -- zkCli.sh -server 127.0.0.1:2181
```

```shell
kubectl exec -it zookeeper-0 -- zkServer.sh status
```

```shell
kubectl exec -it zookeeper-1 -- zkServer.sh status
```

```shell
kubectl exec -it zookeeper-2 -- zkServer.sh status
```

