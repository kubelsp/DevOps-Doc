k8s 安装 Elasticsearch（单节点）

https://www.docker.elastic.co/r/elasticsearch/elasticsearch

https://www.docker.elastic.co/r/kibana/kibana

````shell
mkdir ~/elk-yml

kubectl create ns elk
````

````shell
cat > es.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: elasticsearch
  namespace: elk
spec:
  replicas: 1
  selector:
    matchLabels:
      app: elasticsearch
  serviceName: elasticsearch-headless
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
        #image: docker.elastic.co/elasticsearch/elasticsearch:9.0.3
        image: ccr.ccs.tencentyun.com/huanghuanhui/elasticsearch:9.0.3
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
            cpu: 2
            memory: 8Gi
          requests:
            cpu: 1
            memory: 2Gi
        volumeMounts:
        - name: elasticsearch-data
          mountPath: /usr/share/elasticsearch/data
  volumeClaimTemplates:
  - metadata:
      name: elasticsearch-data
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: nfs-storage
      resources:
        requests:
          storage: 2Ti
---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch-headless
  namespace: elk
  labels:
    app: elasticsearch
spec:
  clusterIP: None 
  ports:
  - name: http
    port: 9200
    targetPort: 9200
  - name: transport
    port: 9300
    targetPort: 9300
  selector:
    app: elasticsearch

---
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch
  namespace: elk
  labels:
    app: elasticsearch
spec:
  type: NodePort
  ports:
  - name: http
    port: 9200
    targetPort: 9200
  - name: transport
    port: 9300
    targetPort: 9300
  selector:
    app: elasticsearch
EOF
````

```shell
cat > kibana.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kibana
  namespace: elk
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kibana
  serviceName: kibana-headless
  template:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
      - name: kibana
        env:
        - name: ELASTICSEARCH_HOSTS
          value: http://elasticsearch-headless:9200
        - name: I18N.LOCALE
          value: zh-CN
        #image: docker.elastic.co/elasticsearch/kibana:9.0.3
        image: ccr.ccs.tencentyun.com/huanghuanhui/kibana:9.0.3
        imagePullPolicy: IfNotPresent
        ports:
        - name: kibana
          containerPort: 5601
          protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  name: kibana-headless
  namespace: elk
  labels:
    app: kibana
spec:
  clusterIP: None 
  ports:
  - name: kibana
    port: 5601
    targetPort: 5601
  selector:
    app: kibana

---
apiVersion: v1
kind: Service
metadata:
  name: kibana
  namespace: elk
  labels:
    app: kibana
spec:
  type: NodePort
  ports:
  - name: kibana
    port: 5601
    targetPort: 5601
  selector:
    app: kibana
EOF
```

