````shell
mkdir -p ~/etcd-yml

kubectl create ns etcd
````

``````shell
cat > ~/etcd-yml/etcd.yml << 'EOF'
---
apiVersion: v1
kind: Service
metadata:
  name: etcd
  namespace: etcd
spec:
  type: ClusterIP
  clusterIP: None
  selector:
    app: etcd
  publishNotReadyAddresses: true
  ports:
  - name: etcd-client
    port: 2379
  - name: etcd-server
    port: 2380
  - name: etcd-metrics
    port: 8080
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: etcd
  namespace: etcd
spec:
  serviceName: etcd
  replicas: 3
  podManagementPolicy: Parallel
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: etcd
  template:
    metadata:
      labels:
        app: etcd
      annotations:
        serviceName: etcd
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - etcd
            topologyKey: "kubernetes.io/hostname"
      containers:
      - name: etcd
        image: quay.io/coreos/etcd:v3.5.15
        imagePullPolicy: IfNotPresent
        ports:
        - name: etcd-client
          containerPort: 2379
        - name: etcd-server
          containerPort: 2380
        - name: etcd-metrics
          containerPort: 8080
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 5
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 30
        livenessProbe:
          httpGet:
            path: /livez
            port: 8080
          initialDelaySeconds: 15
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        env:
        - name: K8S_NAMESPACE
          valueFrom:
            fieldRef:
             fieldPath: metadata.namespace
        - name: HOSTNAME
          valueFrom:
            fieldRef:
             fieldPath: metadata.name
        - name: SERVICE_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.annotations['serviceName']
        - name: ETCDCTL_ENDPOINTS
          value: $(HOSTNAME).$(SERVICE_NAME):2379
        - name: URI_SCHEME
          value: "http"
        command:
        - /usr/local/bin/etcd
        args:
        - --name=$(HOSTNAME)
        - --data-dir=/data
        - --wal-dir=/data/wal
        - --listen-peer-urls=$(URI_SCHEME)://0.0.0.0:2380
        - --listen-client-urls=$(URI_SCHEME)://0.0.0.0:2379
        - --advertise-client-urls=$(URI_SCHEME)://$(HOSTNAME).$(SERVICE_NAME):2379
        - --initial-cluster-state=new
        - --initial-cluster-token=etcd-$(K8S_NAMESPACE)
        - --initial-cluster=etcd-0=$(URI_SCHEME)://etcd-0.$(SERVICE_NAME):2380,etcd-1=$(URI_SCHEME)://etcd-1.$(SERVICE_NAME):2380,etcd-2=$(URI_SCHEME)://etcd-2.$(SERVICE_NAME):2380
        - --initial-advertise-peer-urls=$(URI_SCHEME)://$(HOSTNAME).$(SERVICE_NAME):2380
        - --listen-metrics-urls=http://0.0.0.0:8080
        volumeMounts:
        - name: etcd-data
          mountPath: /data
      volumes:
  volumeClaimTemplates:
  - metadata:
      name: etcd-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: nfs-storage
      resources:
        requests:
          storage: 100Gi
EOF
``````

````shell
kubectl apply -f ~/etcd-yml/etcd.yml
````

````shell
$ kubectl -n etcd exec -it etcd-0 -- etcdctl member list -wtable
+------------------+---------+--------+-------------------------+-------------------------+------------+
|        ID        | STATUS  |  NAME  |       PEER ADDRS        |      CLIENT ADDRS       | IS LEARNER |
+------------------+---------+--------+-------------------------+-------------------------+------------+
| 91ac39ca9e4a9f13 | started | etcd-1 | http://etcd-1.etcd:2380 | http://etcd-1.etcd:2379 |      false |
| 937595d35e7537ba | started | etcd-2 | http://etcd-2.etcd:2380 | http://etcd-2.etcd:2379 |      false |
| dcf132440dd8705d | started | etcd-0 | http://etcd-0.etcd:2380 | http://etcd-0.etcd:2379 |      false |
+------------------+---------+--------+-------------------------+-------------------------+------------+
````

