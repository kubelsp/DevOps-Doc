###### k8s手撕yml方式安装rocketmq

> 版本：rocketmq-v5.1.4
>
> 适合开发、测试环境（外部IDE开发工具可直连）

```shell
mkdir ~/rocketmq-yml

kubectl create ns rocketmq
```

```shell
cat > ~/rocketmq-yml/rocketmq-cm.yml << 'EOF'
kind: ConfigMap
apiVersion: v1
metadata:
  name: rocketmq-broker-config
  namespace: rocketmq
data:
  BROKER_MEM: '-Xms2g -Xmx2g -Xmn1g'
  broker-common.conf: |-
    brokerClusterName = DefaultCluster
    brokerName = broker-0
    brokerId = 0
    deleteWhen = 04
    fileReservedTime = 48
    brokerRole = ASYNC_MASTER
    flushDiskType = ASYNC_FLUSH
    brokerIP1=192.168.1.202
    namesrvAddr=192.168.1.202:9876
EOF


# 如果不需要集群外访问使用（注释下面这两行）
# brokerIP1=192.168.1.202
# namesrvAddr=192.168.1.202:9876 
```

```shell
kubectl apply -f ~/rocketmq-yml/rocketmq-cm.yml
```

###### nameserver

```shell
cat > ~/rocketmq-yml/rocketmq-name-service-sts.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: rocketmq-name-service
  namespace: rocketmq
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rocketmq-name-service
      name_service_cr: rocketmq-name-service
  template:
    metadata:
      labels:
        app: rocketmq-name-service
        name_service_cr: rocketmq-name-service
    spec:
      hostNetwork: true #新加配置 # 如果不需要集群外访问使用（注释这行）
      nodeSelector: # 如果不需要集群外访问使用（注释这行）
        kubernetes.io/hostname: "k8s-node2" # 如果不需要集群外访问使用（注释这行）
      volumes:
        - name: host-time
          hostPath:
            path: /etc/localtime
            type: ''
      containers:
        - name: rocketmq-name-service
          image: apache/rocketmq:5.1.4
          imagePullPolicy: IfNotPresent
          command:
            - /bin/sh
          args:
            - mqnamesrv
          ports:
            - name: tcp-9876
              containerPort: 9876
              protocol: TCP
          volumeMounts:
            - name: rocketmq-namesrv-storage
              mountPath: /home/rocketmq/logs
              subPath: logs
            - name: host-time
              readOnly: true
              mountPath: /etc/localtime
          imagePullPolicy: IfNotPresent
  volumeClaimTemplates:
    - kind: PersistentVolumeClaim
      apiVersion: v1
      metadata:
        name: rocketmq-namesrv-storage
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 2Ti
        storageClassName: "nfs-storage"
        volumeMode: Filesystem
  serviceName: ''

---
kind: Service
apiVersion: v1
metadata:
  name: rocketmq-name-server-service
  namespace: rocketmq
spec:
  ports:
    - name: tcp-9876
      protocol: TCP
      port: 9876
      targetPort: 9876
      nodePort: 31081
  selector:
    name_service_cr: rocketmq-name-service
  type: NodePort
EOF
```

```shell
kubectl apply -f ~/rocketmq-yml/rocketmq-name-service-sts.yml
```

###### broker

```shell
cat > ~/rocketmq-yml/rocketmq-broker-sts.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: rocketmq-broker-0-master
  namespace: rocketmq
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rocketmq-broker
      broker_cr: rocketmq-broker
  template:
    metadata:
      labels:
        app: rocketmq-broker
        broker_cr: rocketmq-broker
    spec:
      hostNetwork: true #新加配置 # 如果不需要集群外访问使用（注释这行）
      nodeSelector: # 如果不需要集群外访问使用（注释这行）
        kubernetes.io/hostname: "k8s-node2" # 如果不需要集群外访问使用（注释这行）
      volumes:
        - name: rocketmq-broker-config
          configMap:
            name: rocketmq-broker-config
            items:
              - key: broker-common.conf
                path: broker-common.conf
            defaultMode: 420
        - name: host-time
          hostPath:
            path: /etc/localtime
            type: ''
      containers:
        - name: rocketmq-broker
          image: apache/rocketmq:5.1.4
          imagePullPolicy: IfNotPresent
          command:
            - /bin/sh
          args:
            - mqbroker
            - "-c"
            - /home/rocketmq/conf/broker-common.conf
          ports:
            - name: tcp-vip-10909
              containerPort: 10909
              protocol: TCP
            - name: tcp-main-10911
              containerPort: 10911
              protocol: TCP
            - name: tcp-ha-10912
              containerPort: 10912
              protocol: TCP
          env:
            - name: NAMESRV_ADDR
              value: 'rocketmq-name-server-service.rocketmq:9876'
            - name: BROKER_MEM
              valueFrom:
                configMapKeyRef:
                  name: rocketmq-broker-config
                  key: BROKER_MEM
          volumeMounts:
            - name: host-time
              readOnly: true
              mountPath: /etc/localtime
            - name: rocketmq-broker-storage
              mountPath: /home/rocketmq/logs
              subPath: logs/broker-0-master
            - name: rocketmq-broker-storage
              mountPath: /home/rocketmq/store
              subPath: store/broker-0-master
            - name: rocketmq-broker-config
              mountPath: /home/rocketmq/conf/broker-common.conf
              subPath: broker-common.conf
          imagePullPolicy: IfNotPresent
  volumeClaimTemplates:
    - kind: PersistentVolumeClaim
      apiVersion: v1
      metadata:
        name: rocketmq-broker-storage
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 2Ti
        storageClassName: "nfs-storage"
        volumeMode: Filesystem
  serviceName: ''

---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: rocketmq-broker
  name: rocketmq-broker-server-service
  namespace: rocketmq
spec:
  type: NodePort
  ports:
  - port: 10911
    targetPort: 10911
    name: broker-port
    nodePort: 30911
  selector:
    app: rocketmq-broker
EOF
```

```shell
kubectl apply -f ~/rocketmq-yml/rocketmq-broker-sts.yml
```

``` shell
cat > ~/rocketmq-yml/rocketmq-dashboard.yml << 'EOF'
kind: Deployment
apiVersion: apps/v1
metadata:
  name: rocketmq-dashboard
  namespace: rocketmq
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rocketmq-dashboard
  template:
    metadata:
      labels:
        app: rocketmq-dashboard
    spec:
      containers:
        - name: rocketmq-dashboard
          image: apacherocketmq/rocketmq-console:2.0.0
          imagePullPolicy: IfNotPresent
          ports:
            - name: http-8080
              containerPort: 8080
              protocol: TCP
          env:
            - name: JAVA_OPTS
              value: >-
                -Drocketmq.namesrv.addr=rocketmq-name-server-service.rocketmq:9876
                -Dcom.rocketmq.sendMessageWithVIPChannel=false
          resources:
            limits:
              cpu: 500m
              memory: 2Gi
            requests:
              cpu: 50m
              memory: 512Mi
          imagePullPolicy: IfNotPresent

---
kind: Service
apiVersion: v1
metadata:
  name: rocketmq-dashboard-service
  namespace: rocketmq
spec:
  ports:
    - name: http-8080
      protocol: TCP
      port: 8080
      targetPort: 8080
      nodePort: 31080
  selector:
    app: rocketmq-dashboard
  type: NodePort
EOF
```

```shell
kubectl apply -f ~/rocketmq-yml/rocketmq-dashboard.yml
```

```shell
cat > ~/rocketmq-yml/rocketmq-dashboard-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rocketmq-dashboard-ingress
  namespace: rocketmq
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: rocketmq-dashboard-local.huanghuanhui.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rocketmq-dashboard-service
            port:
              number: 8080
  tls:
  - hosts:
    - rocketmq-dashboard-loacl.huanghuanhui.cloud
    secretName: rocketmq-console-ingress-tls
EOF
```

```shell
kubectl create secret -n rocketmq \
tls rocketmq-console-ingress-tls \
--key=/root/ssl/huanghuanhui.cloud.key \
--cert=/root/ssl/huanghuanhui.cloud.crt
```

```shell
kubectl apply -f ~/rocketmq-yml/rocketmq-dashboard-Ingress.yml
```

> dashboard 访问地址：https://rocketmq-dashboard-local.huanghuanhui.cloud/
>
> 代码连接地址1：192.168.1.200:31081（本地IDE开发工具）
>
> 代码连接地址2：rocketmq-name-server-service.rocketmq:9876（集群内部连接地址）
