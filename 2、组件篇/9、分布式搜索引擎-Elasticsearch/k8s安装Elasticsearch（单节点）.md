k8s 安装 Elasticsearch（单节点）

````shell
cat > es-single-node.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: es-single-node
  namespace: elk
spec:
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  serviceName: es-server
  template:
    metadata:
      labels:
        app: elasticsearch
    spec:
      containers:
      - name: elasticsearch
        env:
        - name: TZ
          value: Asia/Shanghai
        - name: discovery.type
          value: single-node
        - name: ES_JAVA_OPTS
          value: -Xms4g -Xmx4g
        - name: xpack.security.enabled
          value: "false"  # 注意这里的值需要是字符串 "false"
        #image: docker.elastic.co/elasticsearch/elasticsearch:8.15.0
        image: ccr.ccs.tencentyun.com/huanghuanhui/elasticsearch:8.15.0
        imagePullPolicy: IfNotPresent
        ports:
        - name: rest
          containerPort: 9200
          protocol: TCP
        - name: inter-node
          containerPort: 9300
          protocol: TCP
        resources:
          limits:
            cpu: "2"
          requests:
            cpu: 100m
        volumeMounts:
        - name: elastic-data
          mountPath: /usr/share/elasticsearch/data
  volumeClaimTemplates:
  - metadata:
      name: elastic-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: nfs-storage
      resources:
        requests:
          storage: 2Ti
EOF
````


