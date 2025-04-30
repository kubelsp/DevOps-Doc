### k8s部署kafka集群

###### kafka（Kafka with KRaft）

```shell
mkdir -p ~/kafka-yml

kubectl create ns kafka
```

```shell
cat > ~/kafka-yml/kafka.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: kafka-headless
  namespace: kafka
  labels:
    app: kafka
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - name: kafka-client
    port: 9092
    targetPort: kafka-client
  - name: controller
    port: 9093
    targetPort: controller   
  selector:
    app: kafka
---
#部署 Service，用于外部访问 Kafka
apiVersion: v1
kind: Service
metadata:
  name: kafka-service
  namespace: kafka
  labels:
    app: kafka
spec:
  type: NodePort
  ports:
  - name: kafka-client
    port: 9092
    targetPort: kafka-client
    nodePort: 30992
  selector:
    app: kafka
---
# 分别在 StatefulSet 中的每个 Pod 中获取相应的序号作为 KAFKA_CFG_NODE_ID（只能是整数），然后再执行启动脚本
apiVersion: v1
kind: ConfigMap
metadata:
  name: ldc-kafka-scripts
  namespace: kafka
data:
  setup.sh: |-
    #!/bin/bash
    export KAFKA_CFG_NODE_ID=${MY_POD_NAME##*-} 
    exec /opt/bitnami/scripts/kafka/entrypoint.sh /opt/bitnami/scripts/kafka/run.sh
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka
  namespace: kafka
  labels:
    app: kafka
spec:
  selector:
    matchLabels:
      app: kafka
  serviceName: kafka-headless
  podManagementPolicy: Parallel
  #replicas: 5 # 部署完成后，将会创建 5 个 Kafka 副本
  replicas: 3 # 部署完成后，将会创建 3 个 Kafka 副本
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: kafka
    spec:
      affinity:
        podAntiAffinity: # 工作负载反亲和
          preferredDuringSchedulingIgnoredDuringExecution: # 尽量满足如下条件
          - weight: 1
            podAffinityTerm:
              labelSelector: # 选择Pod的标签，与工作负载本身反亲和
                matchExpressions:
                  - key: "app"
                    operator: In
                    values:
                      - kafka
              topologyKey: "kubernetes.io/hostname"  # 在节点上起作用
      containers:
      - name: kafka
        #image: bitnami/kafka:3.4.1
        #image: bitnami/kafka:3.7.0
        image: ccr.ccs.tencentyun.com/huanghuanhui/bitnami-kafka:3.7.0
        imagePullPolicy: "IfNotPresent"
        command:
        - /opt/leaderchain/setup.sh
        env:
        - name: KAFKA_HEAP_OPTS # kafka的堆内存配置，默认为1g，这里设置为2-4g
          value: "-Xmx4096m -Xms2048m"
        - name: BITNAMI_DEBUG
          value: "true" # true 详细日志
        # KRaft settings 
        - name: MY_POD_NAME # 用于生成 KAFKA_CFG_NODE_ID
          valueFrom:
            fieldRef:
              fieldPath: metadata.name            
        - name: KAFKA_CFG_PROCESS_ROLES
          value: "controller,broker"
        - name: KAFKA_CFG_CONTROLLER_QUORUM_VOTERS
          #value: "0@kafka-0.kafka-headless:9093,1@kafka-1.kafka-headless:9093,2@kafka-2.kafka-headless:9093,3@kafka-3.kafka-headless:9093,4@kafka-4.kafka-headless:9093"
          value: "0@kafka-0.kafka-headless:9093,1@kafka-1.kafka-headless:9093,2@kafka-2.kafka-headless:9093"
        - name: KAFKA_KRAFT_CLUSTER_ID
          value: "Jc7hwCMorEyPprSI1Iw4sW"  
        # Listeners            
        - name: KAFKA_CFG_LISTENERS
          value: "PLAINTEXT://:9092,CONTROLLER://:9093"
        - name: KAFKA_CFG_ADVERTISED_LISTENERS
          value: "PLAINTEXT://:9092"
        - name: KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP
          value: "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT"
        - name: KAFKA_CFG_CONTROLLER_LISTENER_NAMES
          value: "CONTROLLER"
        - name: KAFKA_CFG_INTER_BROKER_LISTENER_NAME
          value: "PLAINTEXT"
        ports:
        - containerPort: 9092
          name: kafka-client                  
        - containerPort: 9093
          name: controller
          protocol: TCP                     
        volumeMounts:
        - mountPath: /bitnami/kafka
          name: kafka-data
        - mountPath: /opt/leaderchain/setup.sh
          name: scripts
          subPath: setup.sh
          readOnly: true      
      securityContext:
        fsGroup: 1001
        runAsUser: 1001
      volumes:    
      - configMap:
          defaultMode: 493
          name: ldc-kafka-scripts
        name: scripts      
  volumeClaimTemplates:
  - metadata:
      name: kafka-data
    spec:
      storageClassName: nfs-storage
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 2Ti
EOF
```

```shell
kubectl apply -f ~/kafka-yml/kafka.yml
```

> 代码连接地址：kafka-headless.kafka:9092

###### kafka-ui

```shell
cat > ~/kafka-yml/kafka-ui.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-ui
  namespace: kafka
  labels:
    app: kafka-ui
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kafka-ui
  template:
    metadata:
      labels:
        app: kafka-ui
    spec:
      containers:
      - name: kafka-ui
        #image: provectuslabs/kafka-ui:v0.7.2
        image: ccr.ccs.tencentyun.com/huanghuanhui/kafka-ui:v0.7.2
        imagePullPolicy: IfNotPresent
        env:
        - name: KAFKA_CLUSTERS_0_NAME
          value: 'kafka-elk'
        - name: KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS
          value: 'kafka-headless.kafka:9092'
        - name: DYNAMIC_CONFIG_ENABLED
          value: "true"
        - name: AUTH_TYPE # https://docs.kafka-ui.provectus.io/configuration/authentication/basic-authentication
          value: "LOGIN_FORM"
        - name: SPRING_SECURITY_USER_NAME
          value: "admin"    
        - name: SPRING_SECURITY_USER_PASSWORD
          value: "Admin@2025"
        ports:
        - name: web
          containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: kafka-ui
  namespace: kafka
spec:
  selector:
    app: kafka-ui
  type: NodePort
  ports:
  - name: web
    port: 8080
    targetPort: 8080
    nodePort: 30088
EOF
```

```shell
kubectl apply -f ~/kafka-yml/kafka-ui.yml
```

```shell
cat > ~/kafka-yml/kafka-ui-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kafka-ui-ingress
  namespace: kafka
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: kafka-ui.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kafka-ui
            port:
              number: 8080
  tls:
  - hosts:
    - kafka-ui.openhhh.com
    secretName: kafka-ui-ingress-tls
EOF
```

```shell
kubectl create secret -n kafka \
tls kafka-ui-ingress-tls \
--key=/root/ssl/openhhh.com.key \
--cert=/root/ssl/openhhh.com.pem
```

```shell
kubectl apply -f ~/kafka-yml/kafka-ui-Ingress.yml
```

> 访问地址：https://kafka-ui.openhhh.com
>
> 账号密码：admin、Admin@2025

#### **查看所有 Topic**

`````shell
kafka-topics.sh --bootstrap-server localhost:9092 --list
kafka-topics.sh --bootstrap-server localhost:9092 --describe --topic <topic-name>
`````

#### **查看 Broker 列表**

````shell
kafka-broker-api-versions.sh --bootstrap-server localhost:9092
````

**🔍 经验参考（中等规模日志系统）**

| **业务量**      | **Broker Pod 数** | **每 Pod 配置**   |
| --------------- | ----------------- | ----------------- |
| 每天 1 亿条日志 | 5 个 Kafka Pod    | 2 vCPU / 8Gi 内存 |
| 每天 3～5 亿条  | 7～9 个           | 4 vCPU / 16Gi     |

**🎯 总结：**



​	对你这个 “每天 1 亿条日志” 的 Kafka 集群，建议如下配置：

| **项目**     | **配置**                       |
| ------------ | ------------------------------ |
| Broker 数量  | 5 个 StatefulSet Pod           |
| CPU per Pod  | requests: 1, limits: 2～4 vCPU |
| 内存 per Pod | requests: 4Gi, limits: 8～12Gi |
| Kafka Heap   | -Xms2G -Xmx2G                  |
| 存储 per Pod | 500Gi～1Ti，SSD 类型 PVC       |