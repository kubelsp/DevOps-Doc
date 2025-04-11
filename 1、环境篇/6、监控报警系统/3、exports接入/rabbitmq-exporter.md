###### rabbitmq-exporter

````shell
  apiVersion: monitoring.coreos.com/v1
  kind: PodMonitor
  metadata:
    name: rabbitmq-exporter  # 填写一个唯一名称
    namespace: cm-prometheus  # 按量实例: 集群的 namespace; 包年包月实例(已停止售卖): namespace 固定，不要修改
  spec:
    podMetricsEndpoints:
    - interval: 30s
      port: metric-port    # 填写 pod yaml 中 Prometheus Exporter 对应的 Port 的 Name
      path: /metrics  # 填写 Prometheus Exporter 对应的 Path 的值，不填默认/metrics
      relabelings:
      - action: replace
        sourceLabels: 
        - instance
        regex: (.*)
        targetLabel: instance
        replacement: 'crs-xxxxxx' # 调整成对应的 RabbitMQ 实例 ID
      - action: replace
        sourceLabels: 
        - instance
        regex: (.*)
        targetLabel: ip
        replacement: '1.x.x.x' # 调整成对应的 RabbitMQ 实例 IP
    namespaceSelector:   # 选择要监控 pod 所在的 namespace
      matchNames:
      - rabbitmq-demo
    selector:  # 填写要监控 pod 的 Label 值，以定位目标 pod
      matchLabels:
        k8s-app: rabbitmq-exporter

````

