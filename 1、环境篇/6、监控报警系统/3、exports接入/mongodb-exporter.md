###### mongodb-exporter

````shell
apiVersion: v1
kind: Secret
metadata:
    name: mongodb-secret-test
    namespace: mongodb-test
type: Opaque
stringData:
    datasource: "mongodb://{user}:{passwd}@{host1}:{port1},{host2}:{port2},{host3}:{port3}/admin"  # 对应连接URI

````

````shell
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: mongodb-exporter # 根据业务需要调整成对应的名称，建议加上 MongoDB 实例的信息
  name: mongodb-exporter # 根据业务需要调整成对应的名称，建议加上 MongoDB 实例的信息
  namespace: mongodb-test
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: mongodb-exporter # 根据业务需要调整成对应的名称，建议加上 MongoDB 实例的信息
  template:
    metadata:
      labels:
        k8s-app: mongodb-exporter # 根据业务需要调整成对应的名称，建议加上 MongoDB 实例的信息
    spec:
      containers:
        - args:
            - --collect.database       # 启用采集 Database metrics
            - --collect.collection     # 启用采集 Collection metrics
            - --collect.topmetrics     # 启用采集 table top metrics
            - --collect.indexusage     # 启用采集 per index usage stats
            - --collect.connpoolstats  # 启动采集 MongoDB connpoolstats
          env:
            - name: MONGODB_URI
              valueFrom:
                secretKeyRef:
                  name: mongodb-secret-test
                  key: datasource
          image: ccr.ccs.tencentyun.com/rig-agent/mongodb-exporter:0.10.0
          imagePullPolicy: IfNotPresent
          name: mongodb-exporter
          ports:
            - containerPort: 9216
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
      securityContext: { }
      terminationGracePeriodSeconds: 30

````

