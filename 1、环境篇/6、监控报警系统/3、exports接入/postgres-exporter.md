###### postgres-exporter

```shell
apiVersion: v1
kind: Secret
metadata:
    name: postgres-test
type: Opaque
stringData:
    username: postgres
    password: you-guess #对应 PostgreSQL 密码

```

```shell
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres-test # 根据业务需要调整成对应的名称，建议加上 PG 实例的信息
  namespace: postgres-test # 根据业务需要调整成对应的名称，建议加上 PG 实例的信息
  labels:
    app: postgres
    app.kubernetes.io/name: postgresql
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
      app.kubernetes.io/name: postgresql
  template:
    metadata:
      labels:
        app: postgres
        app.kubernetes.io/name: postgresql
    spec:
      containers:
      - name: postgres-exporter
        image: ccr.ccs.tencentyun.com/rig-agent/postgres-exporter:v0.8.0
        args:
          - "--web.listen-address=:9187" # export 开启的端口
          - "--log.level=debug" # 日志级别
        env:
          - name: DATA_SOURCE_USER
            valueFrom:
              secretKeyRef:
                name: postgres-test # 对应上一步中的 Secret 的名称
                key: username  # 对应上一步中的 Secret Key
          - name: DATA_SOURCE_PASS 
            valueFrom:
              secretKeyRef:
                name: postgres-test # 对应上一步中的 Secret 的名称
                key: password  # 对应上一步中的 Secret Key
          - name: DATA_SOURCE_URI
            value: "x.x.x.x:5432/postgres?sslmode=disable"  # 对应的连接信息
        ports:
        - name: http-metrics
          containerPort: 9187

```

