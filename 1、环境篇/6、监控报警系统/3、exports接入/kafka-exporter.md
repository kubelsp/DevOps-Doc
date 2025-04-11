###### kafka-exporter

````shell
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: kafka-exporter # 根据业务需要调整成对应的名称，建议加上 Kafka 实例的信息, 如 ckafka-2vrgx9fd-kafka-exporter
  name: kafak-exporter # 根据业务需要调整成对应的名称，建议加上 Kafka 实例的信息, 如 ckafka-2vrgx9fd-kafka-exporter
  namespace: kafka-demo # 集群的 namespace，exporter 会部署在该 namespace 下
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: kafka-exporter # 根据业务需要调整成对应的名称，建议加上 Kafka 实例的信息, 如 ckafka-2vrgx9fd-kafka-exporter
  template:
    metadata:
      labels:
        k8s-app: kafka-exporter # 根据业务需要调整成对应的名称，建议加上 Kafka 实例的信息, 如 ckafka-2vrgx9fd-kafka-exporter
    spec:
      containers:
      - args:
        - --kafka.server=x.x.x.x:9092 # 对应 Kafka 实例的地址信息
        image: ccr.ccs.tencentyun.com/rig-agent/kafka-exporter:v1.3.0
        imagePullPolicy: IfNotPresent
        name: kafka-exporter
        ports:
        - containerPort: 9121
          name: metric-port  # 这个名称在配置抓取任务的时候需要
        securityContext:
          privileged: false
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      imagePullSecrets:
      - name: qcloudregistrykey
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30

````

