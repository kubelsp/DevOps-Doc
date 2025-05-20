rabbitmq

```shell
kubectl label nodes k8s-node-rabbitmq-01 rabbitmq=rabbitmq
kubectl label nodes k8s-node-rabbitmq-02 rabbitmq=rabbitmq
kubectl label nodes k8s-node-rabbitmq-03 rabbitmq=rabbitmq
```

```shell
kubectl taint nodes k8s-node-rabbitmq-01 rabbitmq=rabbitmq:NoSchedule
kubectl taint nodes k8s-node-rabbitmq-02 rabbitmq=rabbitmq:NoSchedule
kubectl taint nodes k8s-node-rabbitmq-03 rabbitmq=rabbitmq:NoSchedule
```

```shell
mkdir -p ~/rabbitmq-yml
```

```shell
cd ~/rabbitmq-yml && wget https://github.com/rabbitmq/cluster-operator/releases/download/v2.13.0/cluster-operator.yml
```

```shell
    spec:
      tolerations:
      - effect: NoSchedule
        key: rabbitmq
        operator: Equal
        value: rabbitmq
      nodeSelector:
        rabbitmq: rabbitmq
      containers:
```

```shell
rabbitmqoperator/cluster-operator:2.13.0

registry.cn-hangzhou.aliyuncs.com/jingsocial/rabbitmqoperator:cluster-operator-2.13.0
```

````shell
kubectl apply -f ~/rabbitmq-yml/cluster-operator.yml
````

```shell
cat > ~/rabbitmq-yml/rabbitmq.yml << 'EOF'
apiVersion: rabbitmq.com/v1beta1
kind: RabbitmqCluster
metadata:
  name: rabbitmq
  namespace: rabbitmq-system
spec:
  replicas: 3
  tolerations:
  - effect: NoSchedule
    key: rabbitmq
    operator: Equal
    value: rabbitmq
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        preference:
          matchExpressions:
          - key: rabbitmq
            operator: In
            values:
            - rabbitmq
  image: registry.cn-hangzhou.aliyuncs.com/jingsocial/rabbitmq:3.11.24-management-x-delayed-message
  resources:
    requests:
      cpu: 500m
      memory: 1Gi
    limits:
      cpu: 4
      memory: 16Gi
  persistence:
      storage: 200Gi
      storageClassName: nfs-storage
  service:
    type: NodePort
  rabbitmq:
    additionalConfig: |
      default_user=rabbitmq
      default_pass=CoCc5DW7lzCzJmkr
    additionalPlugins:
      - rabbitmq_delayed_message_exchange
    envConfig: |
      RABBITMQ_PLUGINS_DIR=/opt/rabbitmq/plugins:/opt/rabbitmq/community-plugins:/opt/bitnami/rabbitmq/plugins
EOF
```

```shell
kubectl apply -f ~/rabbitmq-yml/rabbitmq.yml
```

```shell
https://github.com/rabbitmq/cluster-operator/blob/main/docs/examples/community-plugins/rabbitmq.yaml
```

> 1、web访问地址：http://192.168.1.213:30336
>
> 2、代码连接地址：rabbitmq-nodes.rabbitmq-system.svc.cluster.local:5672
>
> 用户密码：rabbitmq、CoCc5DW7lzCzJmkr
