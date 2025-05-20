### k8s部署kafka集群

###### kafka（Kafka with KRaft）

```shell
mkdir -p ~/kafka-helm

kubectl create ns kafka
```

```shell
helm repo add bitnami "https://helm-charts.itboon.top/bitnami" --force-update

helm repo update

helm search repo bitnami/kafka -l

helm pull bitnami/kafka --version 32.1.2 --untar
```

```shell
cat > ~/kafka-helm/kafka/values-prod.yaml << 'EOF'
global:
  security:
    allowInsecureImages: true
image:
  registry: ccr.ccs.tencentyun.com
  repository: huanghuanhui/bitnami-kafka
  tag: 4.0.0
listeners:
  client:
    protocol: PLAINTEXT #关闭访问认证
  controller:
    protocol: PLAINTEXT #关闭访问认证
  interbroker:
    protocol: PLAINTEXT #关闭访问认证
  external:
    protocol: PLAINTEXT #关闭访问认证
controller:
  replicaCount: 3 #副本数
  controllerOnly: false #controller+broker共用模式
  heapOpts: -Xmx4096m -Xms2048m #KAFKA JVM
  resources:
    limits:
      cpu: 4 
      memory: 8Gi
    requests:
      cpu: 500m
      memory: 512Mi
  persistence:
    storageClass: "nfs-storage" #存储卷类型
    size: 10Gi #每个pod的存储大小
externalAccess:
  enabled: true #开启外部访问
  controller:
    service:
      type: NodePort #使用NodePort方式
      nodePorts:
        - 30092 #对外端口
        - 30093 #对外端口
        - 30094 #对外端口
      useHostIPs: true #使用宿主机IP
EOF
```

```shell
helm upgrade --install --namespace kafka kafka -f ./values-prod.yaml .
```

> 代码连接地址：kafka-headless.kafka:9092

###### kafka-ui

```shell
cat > ~/kafka-helm/kafka/kafka-ui.yml << 'EOF'
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
kubectl apply -f ~/kafka-helm/kafka/kafka-ui.yml
```

```shell
cat > ~/kafka-helm/kafka/kafka-ui-Ingress.yml << 'EOF'
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