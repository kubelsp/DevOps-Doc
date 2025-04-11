###### redis-exporter

````shell
apiVersion: v1
kind: Secret
metadata:
    name: redis-secret-test
    namespace: redis-test
type: Opaque
stringData:
    password: you-guess  #对应 Redis 密码

````

````shell
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: redis-exporter # 根据业务需要调整成对应的名称，建议加上 Redis 实例的信息，如crs-66e112fp-redis-exporter
  name: redis-exporter # 根据业务需要调整成对应的名称，建议加上 Redis 实例的信息，如crs-66e112fp-redis-exporter
  namespace: redis-test # 选择一个适合的 namespace 来部署 exporter，如果没有需要新建一个 namespace
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: redis-exporter # 根据业务需要调整成对应的名称，建议加上 Redis 实例的信息，如crs-66e112fp-redis-exporter
  template:
    metadata:
      labels:
        k8s-app: redis-exporter # 根据业务需要调整成对应的名称，建议加上 Redis 实例的信息，如crs-66e112fp-redis-exporter
    spec:
      containers:
      - env:
        - name: REDIS_ADDR
          value: ip:port # 对应 Redis 的 ip:port
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: redis-secret-test
              key: password
        image: ccr.ccs.tencentyun.com/rig-agent/redis-exporter:v1.32.0
        imagePullPolicy: IfNotPresent
        name: redis-exporter
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

````shell
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: prod-es
  namespace: elastic-system
spec:
  version: 8.17.4
  http:
    tls:
      selfSignedCertificate:
        disabled: true
  nodeSets:
  - name: masters
    count: 3
    config:
      node.roles: ["master"]
      node.store.allow_mmap: true
      cluster.remote.connect: false
      xpack.ml.enabled: false
    podTemplate:
      spec:
        initContainers:
        - name: sysctl
          securityContext:
            privileged: true
            runAsUser: 0
          command: ["sh", "-c", "sysctl -w vm.max_map_count=262144"]
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 2Gi
              cpu: 500m
            limits:
              memory: 2Gi
              cpu: 1000m
          env:
          - name: ES_JAVA_OPTS
            value: "-Xms1g -Xmx1g"
        affinity:
          podAntiAffinity:
            preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    elasticsearch.k8s.elastic.co/cluster-name: prod-es
                topologyKey: kubernetes.io/hostname
        nodeSelector:
          node-role: es-master
        tolerations:
        - key: "node-role"
          operator: "Equal"
          value: "es-master"
          effect: "NoSchedule"

  - name: hot-data
    count: 3
    config:
      node.roles: ["data_hot", "ingest", "ml", "transform"]
      node.store.allow_mmap: true
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 500Gi
        storageClassName: fast-storage
    podTemplate:
      spec:
        initContainers:
        - name: sysctl
          securityContext:
            privileged: true
            runAsUser: 0
          command: ["sh", "-c", "sysctl -w vm.max_map_count=262144"]
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 8Gi
              cpu: 2
            limits:
              memory: 8Gi
              cpu: 4
          env:
          - name: ES_JAVA_OPTS
            value: "-Xms4g -Xmx4g"
        affinity:
          podAntiAffinity:
            preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    elasticsearch.k8s.elastic.co/cluster-name: prod-es
                topologyKey: kubernetes.io/hostname
        nodeSelector:
          node-role: es-hot
        tolerations:
        - key: "node-role"
          operator: "Equal"
          value: "es-hot"
          effect: "NoSchedule"

  - name: warm-data
    count: 3
    config:
      node.roles: ["data_warm", "ingest", "ml", "transform"]
      node.store.allow_mmap: true
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 1Ti
        storageClassName: normal-storage
    podTemplate:
      spec:
        initContainers:
        - name: sysctl
          securityContext:
            privileged: true
            runAsUser: 0
          command: ["sh", "-c", "sysctl -w vm.max_map_count=262144"]
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 4Gi
              cpu: 1
            limits:
              memory: 4Gi
              cpu: 2
          env:
          - name: ES_JAVA_OPTS
            value: "-Xms2g -Xmx2g"
        affinity:
          podAntiAffinity:
            preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    elasticsearch.k8s.elastic.co/cluster-name: prod-es
                topologyKey: kubernetes.io/hostname
        nodeSelector:
          node-role: es-warm
        tolerations:
        - key: "node-role"
          operator: "Equal"
          value: "es-warm"
          effect: "NoSchedule"

  - name: cold-data
    count: 3
    config:
      node.roles: ["data_cold", "ingest", "ml", "transform"]
      node.store.allow_mmap: true
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 2Ti
        storageClassName: slow-storage
    podTemplate:
      spec:
        initContainers:
        - name: sysctl
          securityContext:
            privileged: true
            runAsUser: 0
          command: ["sh", "-c", "sysctl -w vm.max_map_count=262144"]
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 2Gi
              cpu: 500m
            limits:
              memory: 2Gi
              cpu: 1
          env:
          - name: ES_JAVA_OPTS
            value: "-Xms1g -Xmx1g"
        affinity:
          podAntiAffinity:
            preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    elasticsearch.k8s.elastic.co/cluster-name: prod-es
                topologyKey: kubernetes.io/hostname
        nodeSelector:
          node-role: es-cold
        tolerations:
        - key: "node-role"
          operator: "Equal"
          value: "es-cold"
          effect: "NoSchedule"
````

**⚡ 补充细节说明**

| http.tls.selfSignedCertificate.disabled: true | 关掉自签证书，用明文 HTTP                    |
| --------------------------------------------- | -------------------------------------------- |
| node.store.allow_mmap: true                   | 打开 mmap（需要配合 vm.max_map_count）       |
| affinity + nodeSelector                       | 保证每个节点调度到不同机器、防止单点         |
| volumeClaimTemplates                          | 给每个节点挂自己的磁盘                       |
| heap size                                     | 自动设置为内存一半，手动指定                 |
| storageClassName                              | 按不同冷热选不同级别存储（fast/normal/slow） |
| tolerations                                   | 允许调度到指定角色的节点                     |