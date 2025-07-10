k8s部署kafka （单节点）

````shell
mkdir ~/elk-yml

kubectl create ns elk
````

````shell
cat > kafka.yml << "EOF"
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka
  namespace: elk
spec:
  serviceName: kafka-headless
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: kafka
  template:
    metadata:
      labels:
        app.kubernetes.io/name: kafka
    spec:
      securityContext:
        fsGroup: 1001
        runAsUser: 1001
      containers:
      - name: kafka
        #image: bitnami/kafka:3.8.0
        image: ccr.ccs.tencentyun.com/huanghuanhui/bitnami-kafka:3.8.0
        ports:
        - containerPort: 9092
          name: plaintext
        - containerPort: 9093
          name: controller
        env:
        - name: KAFKA_ENABLE_KRAFT
          value: "yes"
        - name: KAFKA_CFG_PROCESS_ROLES
          value: "broker,controller"
        - name: KAFKA_CFG_CONTROLLER_LISTENER_NAMES
          value: "CONTROLLER"
        - name: KAFKA_CFG_LISTENERS
          value: "PLAINTEXT://:9092,CONTROLLER://:9093"
        - name: KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP
          value: "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT"
        - name: KAFKA_CFG_ADVERTISED_LISTENERS
          value: "PLAINTEXT://kafka-0.kafka-headless.elk.svc.cluster.local:9092"
        - name: KAFKA_BROKER_ID
          value: "0"
        - name: KAFKA_CFG_NODE_ID
          value: "0"
        - name: KAFKA_CFG_CONTROLLER_QUORUM_VOTERS
          value: "0@kafka-0.kafka-headless.elk.svc.cluster.local:9093"
        - name: ALLOW_PLAINTEXT_LISTENER
          value: "yes"
        volumeMounts:
        - name: kafka-data
          mountPath: /bitnami/kafka
  volumeClaimTemplates:
  - metadata:
      name: kafka-data
    spec:
      storageClassName: dev-sc
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 10Gi
          
---
apiVersion: v1
kind: Service
metadata:
  name: kafka-headless
  namespace: elk
  annotations:
    service.alpha.kubernetes.io/tolerate-unready-endpoints: "true"  # 允许StatefulSet未就绪时解析DNS
spec:
  clusterIP: None
  ports:
  - name: plaintext
    port: 9092
    targetPort: 9092
  - name: controller
    port: 9093
    targetPort: 9093
  selector:
    app: kafka

---
apiVersion: v1
kind: Service
metadata:
  name: kafka-external
  namespace: elk
spec:
  type: NodePort
  ports:
  - name: plaintext
    port: 9092
    targetPort: 9092
    nodePort: 30992
  selector:
    app: kafka
EOF
````

