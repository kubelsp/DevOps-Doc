### k8s 手撕yml方式安装 prometheus + grafana + alertmanager



> k8s版本：k8s-1.32.3
>
> prometheus版本：v3.2.1
>
> grafana版本：v11.6.0
>
> alertmanager版本：v0.28.1
>
> https://github.com/prometheus/prometheus/releases/latest
>
>https://hub.docker.com/r/prom/prometheus
>
> https://github.com/grafana/grafana/releases/latest
>
>https://hub.docker.com/r/grafana/grafana
>
> https://github.com/prometheus/alertmanager/releases/latest
>
>https://hub.docker.com/r/prom/alertmanager

1、k8s 手撕方式安装 prometheus

```shell
mkdir ~/prometheus-yml

kubectl create ns monitoring
```

```shell
cat > ~/prometheus-yml/prometheus-rbac.yml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
rules:
- apiGroups: [""]
  resources:
  - nodes
  - nodes/metrics
  - services
  - endpoints
  - pods
  verbs: ["get", "list", "watch"]
- apiGroups: [""]
  resources:
  - configmaps
  verbs: ["get"]
- apiGroups:
  - networking.k8s.io
  resources:
  - ingresses
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
EOF
```

```shell
kubectl apply -f ~/prometheus-yml/prometheus-rbac.yml
```

```shell
cat > ~/prometheus-yml/prometheus-ConfigMap.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    scrape_configs:
      - job_name: prometheus
        static_configs:
          - targets: ['localhost:9090']
EOF
```

```shell
kubectl apply -f ~/prometheus-yml/prometheus-ConfigMap.yml
```

> 这里暂时只配置了对 prometheus 本身的监控
>
> 如果以后有新的资源需要被监控，只需要将 ConfigMap 对象更新即可

```shell
cat > ~/prometheus-yml/prometheus-ConfigMap.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s

    # 告警规则文件
    rule_files:
    - /etc/prometheus/rules.yml
    - /etc/prometheus/rules/*.rules.yml

    # 对接alertmanager
    alerting:
      alertmanagers:
        - static_configs:
          - targets: ["alertmanager-service.monitoring.svc.cluster.local:9093"]

    scrape_configs:

      # 0、监控 prometheus
      - job_name: prometheus
        static_configs:
          - targets: ['localhost:9090']

      # 1、consul 自动注册发现
      - job_name: 'consul-prometheus'
        consul_sd_configs:
          - server: 'consul-server-http.monitoring.svc.cluster.local:8500'
        relabel_configs:
          - source_labels: [__meta_consul_service_id]
            regex: (.+)
            target_label: 'node_name'
            replacement: '$1'
          - source_labels: [__meta_consul_service]
            regex: '.*(node-exporter|hosts).*'
            action: keep

      # 2、监控 k8s节点
      - job_name: 'k8s-nodes'
        kubernetes_sd_configs:
        - role: node
        relabel_configs:
        - source_labels: [__address__]
          regex: '(.*):10250'
          replacement: '${1}:9100'
          target_label: __address__
          action: replace
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)

      # 3、监控 k8s-etcd
      - job_name: 'k8s-etcd'
        metrics_path: metrics
        scheme: http
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
        - role: endpoints
        relabel_configs:
        - source_labels: [__meta_kubernetes_service_name]
          regex: etcd-k8s
          action: keep
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)
          
      # 4、监控 kube-apiserver
      - job_name: 'kube-apiserver'
        kubernetes_sd_configs:
        - role: endpoints
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
          action: keep
          regex: default;kubernetes;https

      # 5、监控 kube-controller-manager
      - job_name: 'kube-controller-manager'
        kubernetes_sd_configs:
        - role: endpoints
        scheme: https
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name]
          action: keep
          regex: kube-system;kube-controller-manager

      # 6、监控 kube-scheduler
      - job_name: 'kube-scheduler'
        kubernetes_sd_configs:
        - role: endpoints
        scheme: https
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name]
          action: keep
          regex: kube-system;kube-scheduler

      # 7、监控 kubelet
      - job_name: 'kubelet'
        kubernetes_sd_configs:
        - role: node
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
          replacement: $1

      # 8、监控 kube-proxy
      - job_name: 'kube-proxy'
        metrics_path: metrics
        scheme: http
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: false
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
        - role: endpoints
        relabel_configs:
        - source_labels: [__meta_kubernetes_service_name]
          regex: kube-proxy
          action: keep
        - action: labelmap
          regex: __meta_kubernetes_pod_label_(.+)

      # 9、监控 coredns
      - job_name: 'coredns'
        static_configs:
          - targets: ['kube-dns.kube-system.svc.cluster.local:9153']

      # 10、监控容器
      - job_name: 'kubernetes-cadvisor'
        kubernetes_sd_configs:
        - role: node
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        relabel_configs:
        - action: labelmap
          regex: __meta_kubernetes_node_label_(.+)
          replacement: $1
        - source_labels: [__meta_kubernetes_node_name]
          regex: (.+)
          replacement: /metrics/cadvisor
          target_label: __metrics_path__
          
      # 11、监控 kube-state-metrics
      - job_name: "kube-state-metrics"
        kubernetes_sd_configs:
        - role: endpoints
        relabel_configs:
        - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_endpoints_name]
          regex: kube-system;kube-state-metrics
          action: keep

      # 12、监控 ingress-nginx
      - job_name: "ingress-nginx"
        kubernetes_sd_configs:
        - role: endpoints
        relabel_configs:
        - source_labels:
          - __meta_kubernetes_namespace
          - __meta_kubernetes_service_name
          - __meta_kubernetes_endpoint_port_name
          regex: ingress-nginx;ingress-nginx-controller-metrics;metrics
          action: keep
        scheme: http
EOF
```

````shell
      # prometheus 联邦
      - job_name: 'federate'
        scrape_interval: 15s

        honor_labels: true
        metrics_path: '/federate'

        params:
          'match[]':
            - '{job="prometheus"}'                  # 拉取 job=prometheus 的所有指标
            - '{__name__=~"job:.*"}'                # 拉取所有以 "job:" 开头的聚合指标
            - '{__name__=~"node.*"}'                # 拉取所有以 "node" 开头的指标
            - '{__name__=~"kube_.*"}'                
            - '{__name__=~"container_.*"}'

        static_configs:
          - targets: ['49.232.253.17:31999']
            labels:
              cluster: 'k8s-01'  # 添加集群标识标签

          - targets: ['49.232.254.17:31999']
            labels:
              cluster: 'k8s-02'  # 添加集群标识标签

          - targets: ['49.232.255.17:31999']
            labels:
              cluster: 'k8s-03'  # 添加集群标识标签

          - targets: ['49.232.256.17:31999']
            labels:
              cluster: 'k8s-04'  # 添加集群标识标签
````

```shell
kubectl apply -f ~/prometheus-yml/prometheus-ConfigMap.yml

prometheus_podIP=`kubectl get pods -n monitoring -o custom-columns='NAME:metadata.name,podIP:status.podIPs[*].ip' |grep prometheus |awk '{print $2}'`

curl -X POST "http://$prometheus_podIP:9090/-/reload"
```

```shell
# 因为告警规则是以ConfigMap挂载Prometheus上，为了可以后期可以方便加规则，这里先创建一个空的告警规则ConfigMap（目的：先让Prometheus正常启动）
kubectl create -n monitoring configmap prometheus-rules --from-literal=empty=empty
```

```shell
cat > ~/prometheus-yml/prometheus-Deployment.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
  labels:
    app: prometheus
spec:
  replicas: 1
  selector:
    matchLabels:
     app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        #image: prom/prometheus:v3.2.1
        image: ccr.ccs.tencentyun.com/huanghuanhui/prometheus:v3.2.1
        imagePullPolicy: IfNotPresent
        args:
        - "--config.file=/etc/prometheus/prometheus.yml"
        - "--storage.tsdb.path=/prometheus"
        - "--storage.tsdb.retention.time=30d"
        - "--web.enable-admin-api"
        - "--web.enable-lifecycle"
        ports:
        - containerPort: 9090
          name: http
        volumeMounts:
        - mountPath: "/prometheus"
          subPath: prometheus
          name: prometheus-data
        - mountPath: "/etc/prometheus"
          name: config
        - mountPath: "/etc/prometheus/rules"
          name: rules
        - name: localtime
          mountPath: /etc/localtime
        resources:
          limits:
            cpu: "2"
            memory: "8Gi"
          requests:
            cpu: "1"
            memory: "2Gi"
        livenessProbe:
          httpGet:
            path: /-/healthy
            port: 9090
          initialDelaySeconds: 10
          periodSeconds: 30
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /-/ready
            port: 9090
          initialDelaySeconds: 5
          periodSeconds: 10
      volumes:
      - name: prometheus-data
        persistentVolumeClaim:
          claimName: prometheus-pvc
      - name: config
        configMap:
          name: prometheus-config
      - name: rules
        configMap:
          name: prometheus-rules
      - name: localtime
        hostPath:
          path: /etc/localtime
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-pvc
  namespace: monitoring
spec:
  storageClassName: nfs-storage
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 2Ti
EOF
```

```shell
kubectl apply -f ~/prometheus-yml/prometheus-Deployment.yml
```

```shell
cat > ~/prometheus-yml/prometheus-Service.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: prometheus-service
  namespace: monitoring
  labels:
    app: prometheus
  annotations:
    prometheus.io/port: "9090"
    prometheus.io/scrape: "true"
spec:
  selector:
    app: prometheus
  type: NodePort
  ports:
  - name: web
    port: 9090
    targetPort: http
    nodePort: 31999
EOF
```

```shell
kubectl apply -f ~/prometheus-yml/prometheus-Service.yml
```

```shell
cat > ~/prometheus-yml/prometheus-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-ingress
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: prod-issuer 
    acme.cert-manager.io/http01-edit-in-place: "true" 
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: prometheus.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-service
            port:
              number: 9090

  tls:
  - hosts:
    - prometheus.openhhh.com
    secretName: prometheus-ingress-tls
EOF
```

```shell
#kubectl create secret -n monitoring \
#tls prometheus-ingress-tls \
#--key=/root/ssl/openhhh.com.key \
#--cert=/root/ssl/openhhh.com.pem
```

```shell
kubectl apply -f ~/prometheus-yml/prometheus-Ingress.yml
```

> 访问地址：https://prometheus.openhhh.com

`告警规则`

> hosts.rules
>
> kubeadm.rules
>
> node.rules
>
> pod.rules
>
> svc.rules
>
> pvc.rules
>
> 更多告警规则查看：https://samber.github.io/awesome-prometheus-alerts/

```shell
mkdir -p ~/prometheus-yml/rules-yml
```

hosts.rules

```shell
cat > ~/prometheus-yml/rules-yml/hosts.rules.yml << 'EOF'
groups:
- name: hosts.rules
  rules:
  ## Custom By huanghuanhui
  - alert: HostDown
    expr: up == 0
    for: 1m
    labels:
      cluster: RTG
      severity: P1
    annotations:
      Summary: '主机{{ $labels.instance }}  ${{ $labels.job }} down'
      description: "主机: 【{{ $labels.instance }}】has been down for more than 1 minute"
      
  - alert: NodeMemoryUsage
    expr: (node_memory_MemTotal_bytes - (node_memory_MemFree_bytes + node_memory_Buffers_bytes + node_memory_Cached_bytes)) / node_memory_MemTotal_bytes * 100 > 80
    for: 1m
    labels:
      cluster: RTG
      severity: P1
    annotations:
      summary: "{{$labels.instance}}: High Memory usage detected"
      description: "{{$labels.instance}}: Memory usage is above 80% (current value is: {{ $value }})"

  - alert: HostCpuLoadAvage
    expr:  node_load5 /count by (instance, job) (node_cpu_seconds_total{mode="idle"}) >= 0.95
    for: 1m
    annotations:
      Summary: "主机{{ $labels.instance }} cpu 5分钟负载比率大于1 (当前值：{{ $value }})"
      description: "主机: 【{{ $labels.instance }}】 cpu_load5值大于核心数。 (当前比率值：{{ $value }})"
    labels:
      cluster: RTG
      severity: 'P3'

  - alert: HostCpuUsage
    expr: (1-((sum(increase(node_cpu_seconds_total{mode="idle"}[5m])) by (instance))/ (sum(increase(node_cpu_seconds_total[5m])) by (instance))))*100 > 80
    for: 1m
    annotations:
      Summary: "主机{{ $labels.instance }} CPU 5分钟使用率大于80% (当前值：{{ $value }})"
      description: "主机: 【{{ $labels.instance }}】 5五分钟内CPU使用率超过80% (当前值：{{ $value }})"
    labels:
      cluster: RTG
      severity: 'P1'

  - alert: HostMemoryUsage
    expr: (1-((node_memory_Buffers_bytes + node_memory_Cached_bytes + node_memory_MemFree_bytes)/node_memory_MemTotal_bytes))*100 > 80
    for: 1m
    annotations:
      Summary: "主机{{ $labels.instance }} 内存使用率大于80% (当前值：{{ $value }})"
      description: "主机: 【{{ $labels.instance }}】 内存使用率超过80% (当前使用率：{{ $value }}%)"
    labels:
      cluster: RTG
      severity: 'P3'

  - alert: HostIOWait
    expr: ((sum(increase(node_cpu_seconds_total{mode="iowait"}[5m])) by (instance))/(sum(increase(node_cpu_seconds_total[5m])) by (instance)))*100 > 10
    for: 1m
    annotations:
      Summary: "主机{{ $labels.instance }} iowait大于10% (当前值：{{ $value }})"
      description: "主机: 【{{ $labels.instance }}】 5五分钟内磁盘IO过高 (当前负载值：{{ $value }})"
    labels:
      cluster: RTG
      severity: 'P3'

  - alert: HostFileSystemUsage
    expr: (1-(node_filesystem_free_bytes{fstype=~"ext4|xfs",mountpoint!~".*tmp|.*boot" }/node_filesystem_size_bytes{fstype=~"ext4|xfs",mountpoint!~".*tmp|.*boot" }))*100 > 80
    for: 1m
    annotations:
      Summary: "主机{{ $labels.instance }} {{ $labels.mountpoint }} 磁盘空间使用大于80%  (当前值：{{ $value }})"
      description: "主机: 【{{ $labels.instance }}】 {{ $labels.mountpoint }}分区使用率超过80%, 当前值使用率：{{ $value }}%"
    labels:
      cluster: RTG
      severity: 'P3'

  - alert: HostSwapIsFillingUp
    expr: (1 - (node_memory_SwapFree_bytes / node_memory_SwapTotal_bytes)) * 100 > 80
    for: 2m
    labels:
      cluster: RTG
      severity: 'P4'
    annotations:
      Summary: "主机: 【{{ $labels.instance }}】 swap分区使用超过 (>80%), 当前值使用率: {{ $value }}%"
      description: "主机: 【{{ $labels.instance }}】 swap分区使用超过 (>80%), 当前值使用率: {{ $value }}%"

  - alert: HostNetworkConnection-ESTABLISHED
    expr:  sum(node_netstat_Tcp_CurrEstab) by (instance) > 2000
    for: 5m
    labels:
      cluster: RTG
      severity: 'P4'
    annotations:
      Summary: "主机{{ $labels.instance }} ESTABLISHED连接数过高 (当前值：{{ $value }})"
      description: "主机: 【{{ $labels.instance }}】 ESTABLISHED连接数超过2000, 当前ESTABLISHED连接数: {{ $value }}"

  - alert: HostNetworkConnection-TIME_WAIT
    expr:  sum(node_sockstat_TCP_tw) by (instance) > 1000
    for: 5m
    labels:
      cluster: RTG
      severity: 'P3'
    annotations:
      Summary: "主机{{ $labels.instance }} TIME_WAIT连接数过高 (当前值：{{ $value }})"
      description: "主机: 【{{ $labels.instance }}】 TIME_WAIT连接数超过1000, 当前TIME_WAIT连接数: {{ $value }}"

  - alert: HostUnusualNetworkThroughputIn
    expr:  sum by (instance, device) (rate(node_network_receive_bytes_total{device=~"eth.*"}[2m])) / 1024 / 1024 > 300
    for: 5m
    labels:
      cluster: RTG
      severity: 'P3'
    annotations:
      Summary: "主机{{ $labels.instance }} 入口流量超过 (> 300 MB/s)  (当前值：{{ $value }})"
      description: "主机: 【{{ $labels.instance }}】, 网卡: {{ $labels.device }} 入口流量超过 (> 300 MB/s), 当前值: {{ $value }}"

  - alert: HostUnusualNetworkThroughputOut
    expr: sum by (instance, device) (rate(node_network_transmit_bytes_total{device=~"eth.*"}[2m])) / 1024 / 1024 > 300
    for: 5m
    labels:
      cluster: RTG
      severity: 'P4'
    annotations:
      Summary: "主机{{ $labels.instance }} 出口流量超过 (> 300 MB/s)  (当前值：{{ $value }})"
      description: "主机: 【{{ $labels.instance }}】, 网卡: {{ $labels.device }} 出口流量超过 (> 300 MB/s), 当前值: {{ $value }}"

  - alert: HostUnusualDiskReadRate
    expr: sum by (instance, device) (rate(node_disk_read_bytes_total[2m])) / 1024 / 1024 > 50
    for: 5m
    labels:
      cluster: RTG
      severity: 'P4'
    annotations:
      Summary: "主机{{ $labels.instance }} 磁盘读取速率超过(50 MB/s)  (当前值：{{ $value }})"
      description: "主机: 【{{ $labels.instance }}】, 磁盘: {{ $labels.device }} 读取速度超过(50 MB/s), 当前值: {{ $value }}"

  - alert: HostUnusualDiskWriteRate
    expr: sum by (instance, device) (rate(node_disk_written_bytes_total[2m])) / 1024 / 1024 > 50
    for: 2m
    labels:
      cluster: RTG
      severity: 'P4'
    annotations:
      Summary: "主机{{ $labels.instance }} 磁盘读写入率超过(50 MB/s)  (当前值：{{ $value }})"
      description: "主机: 【{{ $labels.instance }}】, 磁盘: {{ $labels.device }} 写入速度超过(50 MB/s), 当前值: {{ $value }}"

  - alert: HostOutOfInodes
    expr: node_filesystem_files_free{fstype=~"ext4|xfs",mountpoint!~".*tmp|.*boot" } / node_filesystem_files{fstype=~"ext4|xfs",mountpoint!~".*tmp|.*boot" } * 100 < 10
    for: 2m
    labels:
      cluster: RTG
      severity: 'P3'
    annotations:
      Summary: "主机{{ $labels.instance }} {{ $labels.mountpoint }}分区主机Inode值小于5% (当前值：{{ $value }}) "
      description: "主机: 【{{ $labels.instance }}】 {{ $labels.mountpoint }}分区inode节点不足 (可用值小于{{ $value }}%)"

  - alert: HostUnusualDiskReadLatency
    expr: rate(node_disk_read_time_seconds_total[2m]) / rate(node_disk_reads_completed_total[2m])  * 1000 > 100 and rate(node_disk_reads_completed_total[2m]) > 0
    for: 5m
    labels:
      cluster: RTG
      severity: 'P4'
    annotations:
      Summary: "主机{{ $labels.instance }} 主机磁盘Read延迟大于100ms (当前值：{{ $value }}ms)"
      description: "主机: 【{{ $labels.instance }}】, 磁盘: {{ $labels.device }} Read延迟过高 (read operations > 100ms), 当前延迟值: {{ $value }}ms"

  - alert: HostUnusualDiskWriteLatency
    expr: rate(node_disk_write_time_seconds_total[2m]) / rate(node_disk_writes_completed_total[2m]) * 1000 > 100 and rate(node_disk_writes_completed_total[2m]) > 0
    for: 5m
    labels:
      cluster: RTG
      severity: 'P4'
    annotations:
      Summary: "主机{{ $labels.instance }} 主机磁盘write延迟大于100ms (当前值：{{ $value }}ms)"
      description: "主机: 【{{ $labels.instance }}】, 磁盘: {{ $labels.device }} Write延迟过高 (write operations > 100ms), 当前延迟值: {{ $value }}ms"

  - alert: NodeFilesystemFilesFillingUp
    annotations:
      description: '预计4小时后 分区:{{ $labels.device }}  主机:{{ $labels.instance }} 可用innode仅剩余 {{ printf "%.2f" $value }}%.'
      runbook_url: https://runbooks.prometheus-operator.dev/runbooks/node/nodefilesystemfilesfillingup
      Summary: '主机{{ $labels.instance }} 预计4小时后可用innode数会低于15% (当前值：{{ $value }})'
    labels:
      cluster: RTG
      severity: p3
    expr: |
      (
        node_filesystem_files_free{job="node-exporter|vm-node-exporter",fstype!=""} / node_filesystem_files{job="node-exporter|vm-node-exporter",fstype!=""} * 100 < 15
      and
        predict_linear(node_filesystem_files_free{job="node-exporter|vm-node-exporter",fstype!=""}[6h], 4*60*60) < 0
      and
        node_filesystem_readonly{job="node-exporter|vm-node-exporter",fstype!=""} == 0
      )
    for: 1h

  - alert: NodeFileDescriptorLimit
    annotations:
      description: '主机:{{ $labels.instance }} 文件描述符使用率超过70% {{ printf "%.2f" $value }}%.'
      runbook_url: https://runbooks.prometheus-operator.dev/runbooks/node/nodefiledescriptorlimit
      Summary: '主机: {{ $labels.instance }}文件描述符即将被耗尽. (当前值：{{ $value }})'
    expr: |
      (
        node_filefd_allocated{job="node-exporter|vm-node-exporter"} * 100 / node_filefd_maximum{job="node-exporter|vm-node-exporter"} > 70
      )
    for: 15m
    labels:
      severity: p3
      action: monitor
      cluster: RTG

  - alert: NodeClockSkewDetected
    annotations:
      description: '主机: {{ $labels.instance }} 时钟延时超过 300s.'
      runbook_url: https://runbooks.prometheus-operator.dev/runbooks/node/nodeclockskewdetected
      Summary: '主机: {{ $labels.instance }}时钟延时超过 300s.(当前值：{{ $value }})'
    expr: |
      (
        node_timex_offset_seconds > 0.05
      and
        deriv(node_timex_offset_seconds[5m]) >= 0
      )
      or
      (
        node_timex_offset_seconds < -0.05
      and
        deriv(node_timex_offset_seconds[5m]) <= 0
      )
    for: 10m
    labels:
      severity: p3
      cluster: RTG

  - alert: NodeFilesystemFilesFillingUp
    annotations:
      description: '预计4小时后 分区:{{ $labels.device }}  主机:{{ $labels.instance }} 可用innode仅剩余 {{ printf "%.2f" $value }}%.'
      runbook_url: https://runbooks.prometheus-operator.dev/runbooks/node/nodefilesystemfilesfillingup
      Summary: '主机{{ $labels.instance }} 预计4小时后可用innode数会低于15% (当前值：{{ $value }})'
    expr: |
      (
        node_filesystem_files_free{job="node-exporter|vm-node-exporter",fstype!=""} / node_filesystem_files{job="node-exporter|vm-node-exporter",fstype!=""} * 100 < 15
      and
        predict_linear(node_filesystem_files_free{job="node-exporter|vm-node-exporter",fstype!=""}[6h], 4*60*60) < 0
      and
        node_filesystem_readonly{job="node-exporter|vm-node-exporter",fstype!=""} == 0
      )
    for: 1h
    labels:
      severity: p3
      cluster: RTG


  - alert: NodeFilesystemSpaceFillingUp
    annotations:
      description: '主机: {{ $labels.instance }} 分区: {{ $labels.device }} 预计在4小时候只有 {{ printf "%.2f" $value }}%.'
      runbook_url: https://runbooks.prometheus-operator.dev/runbooks/node/nodefilesystemspacefillingup
      Summary: "主机: {{ $labels.instance }}预计4小时候磁盘空闲会低于15% (当前值：{{ $value }})"
    expr: |
      (
        node_filesystem_avail_bytes{job="node-exporter|vm-node-exporter",fstype!=""} / node_filesystem_size_bytes{job="node-exporter|vm-node-exporter",fstype!=""} * 100 < 15
      and
        predict_linear(node_filesystem_avail_bytes{job="node-exporter|vm-node-exporter",fstype!=""}[6h], 4*60*60) < 0
      and
        node_filesystem_readonly{job="node-exporter|vm-node-exporter",fstype!=""} == 0
      )
    for: 1h
    labels:
      severity: p3
      cluster: RTG
  - alert: NodeNetworkReceiveErrs
    annotations:
      description: '{{ $labels.instance }} interface {{ $labels.device }} has encountered
        {{ printf "%.0f" $value }} receive errors in the last two minutes.'
      runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-nodenetworkreceiveerrs
      Summary: "主机{{ $labels.instance }} 网卡{{ $labels.device }} Node网络接受错误  (当前值：{{ $value }})"
    expr: |
      increase(node_network_receive_errs_total[2m]) > 10
    for: 2h
    labels:
      severity: p3
      cluster: RTG
  - alert: NodeNetworkTransmitErrs
    annotations:
      description: '{{ $labels.instance }} interface {{ $labels.device }} has encountered
        {{ printf "%.0f" $value }} transmit errors in the last two minutes.'
      runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-nodenetworktransmiterrs
      Summary: "主机{{ $labels.instance }} 网卡{{ $labels.device }} Node网络传输错误  (当前值：{{ $value }})"
    expr: |
      increase(node_network_transmit_errs_total[2m]) > 10
    for: 1h
    labels:
      severity: p3
      cluster: RTG
  - alert: NodeHighNumberConntrackEntriesUsed
    annotations:
      description: '{{ $value | humanizePercentage }} of conntrack entries are used.'
      runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-nodehighnumberconntrackentriesused
      Summary: 主机{{ $labels.instance }} Conntrack条目使用率大于75% (当前值：{{ $value }})
    expr: |
      (node_nf_conntrack_entries / node_nf_conntrack_entries_limit) > 0.75
    labels:
      severity: p2
      cluster: RTG

  - alert: NodeTextFileCollectorScrapeError
    annotations:
      description: Node Exporter text file collector failed to scrape.
      runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-nodetextfilecollectorscrapeerror
      Summary: 主机{{ $labels.instance }} 打开或读取文件时出错,(当前值：{{ $value }})
    expr: |
      node_textfile_scrape_error{job="node-exporter|vm-node-exporter"} == 1
    labels:
      severity: p2
      cluster: RTG
  - alert: NodeClockNotSynchronising
    annotations:
      message: Clock on {{ $labels.instance }} is not synchronising. Ensure NTP
        is configured on this host.
      runbook_url: https://github.com/kubernetes-monitoring/kubernetes-mixin/tree/master/runbook.md#alert-name-nodeclocknotsynchronising
      Summary: 主机{{ $labels.instance }} 时间不同步(当前值：{{ $value }})
    expr: |
      min_over_time(node_timex_sync_status[5m]) == 0
    for: 10m
    labels:
      severity: p4
      cluster: RTG
EOF
```

kubeadm.rules

```shell
cat > ~/prometheus-yml/rules-yml/kubeadm.rules.yml << 'EOF'
groups:
- name: kubeadm.rules
  rules:

  # Kubelet 健康状态检查
  - alert: KubeletDown
    expr: up{job="kubelet"} == 0
    for: 1m
    annotations:
      summary: "Kubelet 不可用"
      description: "Kubelet {{ $labels.instance }} 不可用."


  # Node 不可用警报：
  - alert: NodeDown
    expr: up{job="k8s-nodes"} == 0
    for: 1m
    annotations:
      summary: "Node 不可用"
      description: "Node {{ $labels.node }} 不可用."


  # Kube Proxy 健康状态检查
  - alert: KubeProxyDown
    expr: up{job="kube-proxy"} == 0
    for: 1m
    annotations:
      summary: "Kube Proxy 不可用"
      description: "Kube Proxy {{ $labels.instance }} 不可用."


  # Kube Scheduler 健康状态检查
  - alert: KubeSchedulerDown
    expr: up{job="kube-scheduler"} == 0
    for: 1m
    annotations:
      summary: "Kube Scheduler 不可用"
      description: "Kube Scheduler 不可用."


  # Kube Controller Manager 健康状态检查
  - alert: KubeControllerManagerDown
    expr: up{job="kube-controller-manager"} == 0
    for: 1m
    annotations:
      summary: "Kube Controller Manager 不可用"
      description: "Kube Controller Manager 不可用."


  # Kube State Metrics 健康状态检查
  - alert: KubeStateMetricsDown
    expr: up{job="kube-state-metrics"} == 0
    for: 1m
    annotations:
      summary: "Kube State Metrics 不可用"
      description: "Kube State Metrics 不可用."


    # KubernetesNodeNotReady
  - alert: KubernetesNodeNotReady
    expr: sum(kube_node_status_condition{condition="Ready",status="true"}) by (node) == 0
    for: 10m
    labels:
      severity: critical
    annotations:
      summary: Kubernetes node is not ready
      description: A node in the cluster is not ready, which may cause issues with cluster functionality.
EOF
```

pod.rules

```shell
cat > ~/prometheus-yml/rules-yml/pod.rules.yml << 'EOF'
groups:
- name: pod.rules
  rules:

  - alert: PodDown
    expr: kube_pod_container_status_running != 1  
    for: 2s
    labels:
      severity: warning
      cluster: k8s
    annotations:
      summary: 'Container: {{ $labels.container }} down'
      description: 'Namespace: {{ $labels.namespace }}, Pod: {{ $labels.pod }} is not running'


  - alert: PodReady
    expr: kube_pod_container_status_ready != 1  
    for: 5m   # Ready持续5分钟，说明启动有问题
    labels:
      severity: warning
      cluster: k8s
    annotations:
      summary: 'Container: {{ $labels.container }} ready'
      description: 'Namespace: {{ $labels.namespace }}, Pod: {{ $labels.pod }} always ready for 5 minitue'


  - alert: PodRestart
    expr: changes(kube_pod_container_status_restarts_total[30m]) > 0 # 最近30分钟pod重启
    for: 2s
    labels:
      severity: warning
      cluster: k8s
    annotations:
      summary: 'Container: {{ $labels.container }} restart'
      description: 'namespace: {{ $labels.namespace }}, pod: {{ $labels.pod }} restart {{ $value }} times'


  - alert: PodFailed
    expr: sum (kube_pod_status_phase{phase="Failed"}) by (pod,namespace) > 0
    for: 5s
    labels:
      severity: error 
    annotations:
      summary: "命名空间: {{ $labels.namespace }} | Pod名称: {{ $labels.pod }} Pod状态Failed (当前值: {{ $value }})"


  - alert: PodPending
    expr: sum (kube_pod_status_phase{phase="Pending"}) by (pod,namespace) > 0
    for: 1m
    labels:
      severity: error
    annotations:
      summary: "命名空间: {{ $labels.namespace }} | Pod名称: {{ $labels.pod }} Pod状态Pending (当前值: {{ $value }})"


  - alert: PodErrImagePull
    expr: sum by(namespace,pod) (kube_pod_container_status_waiting_reason{reason="ErrImagePull"}) == 1
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "命名空间: {{ $labels.namespace }} | Pod名称: {{ $labels.pod }}  Pod状态ErrImagePull (当前值: {{ $value }})"


  - alert: PodImagePullBackOff
    expr: sum by(namespace,pod) (kube_pod_container_status_waiting_reason{reason="ImagePullBackOff"}) == 1
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "命名空间: {{ $labels.namespace }} | Pod名称: {{ $labels.pod }}  Pod状态ImagePullBackOff (当前值: {{ $value }})"


  - alert: PodCrashLoopBackOff
    expr: sum by(namespace,pod) (kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"}) == 1
    for: 1m
    labels:
      severity: warning
    annotations:
      summary: "命名空间: {{ $labels.namespace }} | Pod名称: {{ $labels.pod }}  Pod状态CrashLoopBackOff (当前值: {{ $value }})"


  - alert: PodCPUUsage
    expr: sum by(pod, namespace) (rate(container_cpu_usage_seconds_total{image!=""}[5m]) * 100) > 5
    for: 5m
    labels:
      severity: warning 
    annotations:
      summary: "命名空间: {{ $labels.namespace }} | Pod名称: {{ $labels.pod }} CPU使用大于80% (当前值: {{ $value }})"


  - alert: PodMemoryUsage
    expr: sum(container_memory_rss{image!=""}) by(pod, namespace) / sum(container_spec_memory_limit_bytes{image!=""}) by(pod, namespace) * 100 != +inf > 80
    for: 5m
    labels:
      severity: error 
    annotations:
      summary: "命名空间: {{ $labels.namespace }} | Pod名称: {{ $labels.pod }} 内存使用大于80% (当前值: {{ $value }})"


  - alert: PodStatusChange  # Pod 状态异常变更警报
    expr: changes(kube_pod_status_phase[5m]) > 5
    for: 5m
    annotations:
      summary: "Pod 状态异常变更"
      description: "Pod {{ $labels.pod }} 的状态异常变更次数超过 5 次."


  - alert: ContainerCrash  # Pod 容器崩溃警报
    expr: increase(container_cpu_cfs_throttled_seconds_total{container!="",pod!=""}[5m]) > 0
    for: 5m
    annotations:
      summary: "Pod 容器崩溃"
      description: "Pod {{ $labels.pod }} 中的容器发生崩溃."
EOF
```

svc.rules

```shell
cat > ~/prometheus-yml/rules-yml/svc.rules.yml << 'EOF'
groups:
- name: svc.rules
  rules:

  - alert: ServiceDown
    expr: avg_over_time(up[5m]) * 100 < 50
    annotations:
      description: The service {{ $labels.job }} instance {{ $labels.instance }} is not responding for more than 50% of the time for 5 minutes.
      summary: The service {{ $labels.job }} is not responding
EOF
```

pvc.rules

```shell
cat > ~/prometheus-yml/rules-yml/pvc.rules.yml << 'EOF'
groups:
- name: pvc.rules
  rules:

  - alert: PersistentVolumeClaimLost
    expr: sum by(namespace, persistentvolumeclaim) (kube_persistentvolumeclaim_status_phase{phase="Lost"}) == 1
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "PersistentVolumeClaim {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} is lost\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"


  - alert: PersistentVolumeClaimPendig
    expr: sum by(namespace, persistentvolumeclaim) (kube_persistentvolumeclaim_status_phase{phase="Pendig"}) == 1
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "PersistentVolumeClaim {{ $labels.namespace }}/{{ $labels.persistentvolumeclaim }} is pendig\n  VALUE = {{ $value }}\n  LABELS = {{ $labels }}"


  - alert: HighPersistentVolumeUsage  # PersistentVolume 使用率过高警报
    expr: kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes * 100 > 90
    for: 5m
    annotations:
      summary: "PersistentVolume 使用率过高"
      description: "PersistentVolume {{ $labels.persistentvolume }} 的使用率超过 90%."


  - alert: HighPVUsageForPod   # Pod 挂载的 PersistentVolume 使用率过高警报
    expr: kubelet_volume_stats_used_bytes / kubelet_volume_stats_capacity_bytes * 100 > 90
    for: 5m
    annotations:
      summary: "Pod 挂载的 PersistentVolume 使用率过高"
      description: "Pod {{ $labels.pod }} 挂载的 PersistentVolume 使用率超过 90%."
EOF
```

```shell
# 更新前面创建空的prometheus-rules的ConfigMap
kubectl -n monitoring create configmap prometheus-rules \
--from-file=hosts.rules.yml \
--from-file=kubeadm.rules.yml \
--from-file=pod.rules.yml \
--from-file=svc.rules.yml \
--from-file=pvc.rules.yml \
-o yaml --dry-run=client | kubectl apply -f -
```

```shell
prometheus_podIP=`kubectl get pods -n monitoring -o custom-columns='NAME:metadata.name,podIP:status.podIPs[*].ip' |grep prometheus |awk '{print $2}'`

curl -X POST "http://$prometheus_podIP:9090/-/reload"
```

0、对`k8s-node`的监控

```shell
cat > ~/prometheus-yml/k8s-node-exporter.yml << 'EOF'
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: k8s-node-exporter
  namespace: monitoring
  labels:
    app: k8s-node-exporter
spec:
  selector:
    matchLabels:
      app: k8s-node-exporter
  template:
    metadata:
      labels:
        app: k8s-node-exporter
    spec:
      hostPID: true
      hostIPC: true
      hostNetwork: true
      nodeSelector:
        kubernetes.io/os: linux
      containers:
      - name: k8s-node-exporter
        #image: prom/node-exporter:v1.9.0
        image: ccr.ccs.tencentyun.com/huanghuanhui/node-exporter:v1.9.0
        args:
        - --web.listen-address=$(HOSTIP):9100
        - --path.procfs=/host/proc
        - --path.sysfs=/host/sys
        - --path.rootfs=/host/root
        - --collector.filesystem.ignored-mount-points=^/(dev|proc|sys|var/lib/docker/.+)($|/)
        - --collector.filesystem.ignored-fs-types=^(autofs|binfmt_misc|cgroup|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|mqueue|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|sysfs|tracefs)$
        ports:
        - containerPort: 9100
        env:
        - name: HOSTIP
          valueFrom:
            fieldRef:
              fieldPath: status.hostIP
        resources:
          requests:
            cpu: 150m
            memory: 180Mi
          limits:
            cpu: 150m
            memory: 180Mi
        securityContext:
          runAsNonRoot: true
          runAsUser: 65534
        volumeMounts:
        - name: proc
          mountPath: /host/proc
        - name: sys
          mountPath: /host/sys
        - name: root
          mountPath: /host/root
          mountPropagation: HostToContainer
          readOnly: true
        - name: localtime
          mountPath: /etc/localtime
      tolerations:
      - operator: "Exists"
      volumes:
      - name: proc
        hostPath:
          path: /proc
      - name: dev
        hostPath:
          path: /dev
      - name: sys
        hostPath:
          path: /sys
      - name: root
        hostPath:
          path: /
      - name: localtime
        hostPath:
          path: /etc/localtime
EOF
```

```shell
kubectl apply -f ~/prometheus-yml/k8s-node-exporter.yml
```

```shell
docker run -d \
--name node-exporter \
--restart=always \
--net="host" \
--pid="host" \
-v "/proc:/host/proc:ro" \
-v "/sys:/host/sys:ro" \
-v "/:/rootfs:ro" \
-e TZ=Asia/Shanghai \
-v /etc/localtime:/etc/localtime \
ccr.ccs.tencentyun.com/huanghuanhui/node-exporter:v1.9.0 \
--path.procfs=/host/proc \
--path.rootfs=/rootfs \
--path.sysfs=/host/sys \
--collector.filesystem.ignored-mount-points='^/(sys|proc|dev|host|etc)($$|/)'
```

> 模版：8919、12159

`方式1：`手动配置 node-exporter

```shell
# prometheus-ConfigMap.yml
      - job_name: 192.168.1.100
        static_configs:
          - targets: ['192.168.1.100:9100']
```

`方式2：`基于 consul 自动发现 node-exporter

```shell
mkdir -p ~/prometheus-yml/consul-yml
```

```shell
cat > ~/prometheus-yml/consul-yml/consul.yaml << 'EOF'
---
apiVersion: v1
kind: Service
metadata:
  name: consul-server
  namespace: monitoring
  labels:
    name: consul-server
spec:
  selector:
    name: consul-server
  ports:
    - name: http
      port: 8500
      targetPort: 8500
    - name: https
      port: 8443
      targetPort: 8443
    - name: rpc
      port: 8400
      targetPort: 8400
    - name: serf-lan-tcp
      protocol: "TCP"
      port: 8301
      targetPort: 8301
    - name: serf-lan-udp
      protocol: "UDP"
      port: 8301
      targetPort: 8301
    - name: serf-wan-tcp
      protocol: "TCP"
      port: 8302
      targetPort: 8302
    - name: serf-wan-udp
      protocol: "UDP"
      port: 8302
      targetPort: 8302
    - name: server
      port: 8300
      targetPort: 8300
    - name: consul-dns
      port: 8600
      targetPort: 8600
---
apiVersion: v1
kind: Service
metadata:
  name: consul-server-http
  namespace: monitoring
spec:
  selector:
    name: consul-server
  type: NodePort
  ports:
    - protocol: TCP
      port: 8500
      targetPort: 8500
      nodePort: 32685
      name: consul-server-tcp
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: consul-server
  namespace: monitoring
  labels:
    name: consul-server
spec:
  serviceName: consul-server
  selector:
    matchLabels:
      name: consul-server
  replicas: 3
  template:
    metadata:
      labels:
        name: consul-server
      annotations:
        prometheus.io/scrape: "true"  # prometueus自动发现标签
        prometheus.io/path: "v1/agent/metrics" # consul的metrics路径
        prometheus.io/port: "8500"
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchExpressions:
                  - key: "name"
                    operator: In
                    values:
                      - consul-server
              topologyKey: "kubernetes.io/hostname"
      terminationGracePeriodSeconds: 10
      containers:
      - name: consul
        #image: consul:1.15.4
        image: ccr.ccs.tencentyun.com/huanghuanhui/consul:1.15.4
        imagePullPolicy: IfNotPresent
        args:
          - "agent"
          - "-server"
          - "-bootstrap-expect=3"
          - "-ui"
          - "-data-dir=/consul/data"
          - "-bind=0.0.0.0"
          - "-client=0.0.0.0"
          - "-advertise=$(POD_IP)"
          - "-retry-join=consul-server-0.consul-server.$(NAMESPACE).svc.cluster.local"
          - "-retry-join=consul-server-1.consul-server.$(NAMESPACE).svc.cluster.local"
          - "-retry-join=consul-server-2.consul-server.$(NAMESPACE).svc.cluster.local"
          - "-domain=cluster.local"
          - "-disable-host-node-id"
        volumeMounts:
        - name: consul-nfs-client-pvc
          mountPath: /consul/data
        - name: localtime
          mountPath: /etc/localtime
        env:
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        ports:
        - containerPort: 8500
          name: http
        - containerPort: 8400
          name: rpc
        - containerPort: 8443
          name: https-port
        - containerPort: 8301
          name: serf-lan
        - containerPort: 8302
          name: serf-wan
        - containerPort: 8600
          name: consul-dns
        - containerPort: 8300  
          name: server
      volumes:
      - name: localtime
        hostPath:
          path: /etc/localtime
  volumeClaimTemplates:
  - metadata:
      name: consul-nfs-client-pvc
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: nfs-storage
      resources:
        requests:
          storage: 20Gi
EOF
```

```shell
kubectl apply -f ~/prometheus-yml/consul-yml/consul.yaml
```

```shell
cat > ~/prometheus-yml/consul-yml/consul-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: consul-ingress
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: prod-issuer 
    acme.cert-manager.io/http01-edit-in-place: "true" 
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: prometheus-consul.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: consul-server
            port:
              number: 8500

  tls:
  - hosts:
    - prometheus-consul.openhhh.com
    secretName: consul-ingress-tls
EOF
```

```shell
#kubectl create secret -n monitoring \
#tls consul-ingress-tls \
#--key=/root/ssl/openhhh.com.key \
#--cert=/root/ssl/openhhh.com.pem
```

```shell
kubectl apply -f ~/prometheus-yml/consul-yml/consul-Ingress.yml
```

> 访问地址：https://prometheus-consul.openhhh.com

```shell
# prometheus-ConfigMap.yml
      - job_name: 'consul-prometheus'
        consul_sd_configs:
          - server: 'consul-server-http.monitoring.svc.cluster.local:8500'
        relabel_configs:
          - source_labels: [__meta_consul_service_id]
            regex: (.+)
            target_label: 'node_name'
            replacement: '$1'
          - source_labels: [__meta_consul_service]
            regex: '.*(node-exporter|hosts).*'
            action: keep
```

```shell
# 服务注册（ip）
curl -X PUT -d '{"id": "1.15.172.119-node-exporter","name": "1.15.172.119-node-exporter","address": "1.15.172.119","port": 9100,"checks": [{"http": "http://1.15.172.119:9100/","interval": "5s"}]}' http://192.168.1.10:32685/v1/agent/service/register

curl -X PUT -d '{"id": "192.168.1.200-node-exporter","name": "192.168.1.200-node-exporter","address": "192.168.1.200","port": 9100,"checks": [{"http": "http://192.168.1.200:9100/","interval": "5s"}]}' http://192.168.1.10:32685/v1/agent/service/register


# 服务注册（域名）
curl -X PUT -d '{"id": "1.15.172.119-node-exporter","name": "1.15.172.119-node-exporter","address": "1.15.172.119","port": 9100,"checks": [{"http": "http://1.15.172.119:9100/","interval": "5s"}]}' https://prometheus-consul.openhhh.com/v1/agent/service/register

curl -X PUT -d '{"id": "192.168.1.200-node-exporter","name": "192.168.1.200-node-exporter","address": "192.168.1.200","port": 9100,"checks": [{"http": "http://192.168.1.200:9100/","interval": "5s"}]}' https://prometheus-consul.openhhh.com/v1/agent/service/register
```

> `id`或者`name`要包含`node-exporter|hosts`标签才能自动发现

```shell
# 下线服务（ip）
curl -X PUT http://192.168.1.10:32685/v1/agent/service/deregister/1.15.172.119-node-exporter

curl -X PUT http://192.168.1.10:32685/v1/agent/service/deregister/192.168.1.200-node-exporter

# 下线服务（域名）
curl -X PUT https://prometheus-consul.openhhh.com/v1/agent/service/deregister/1.15.172.119-node-exporter

curl -X PUT https://prometheus-consul.openhhh.com/v1/agent/service/deregister/192.168.1.200-node-exporter
```

`consul 批量注册脚本`

```shell
mkdir -p ~/prometheus-yml/consul-yml/node-exporter-json

cat > ~/prometheus-yml/consul-yml/node-exporter-json/node-exporter-1.15.172.119.json << 'EOF'
{
    "id": "1.15.172.119-node-exporter",
    "name": "1.15.172.119-node-exporter",
    "address": "1.15.172.119",
    "port": 9100,
    "tags": ["node-exporter"],
    "checks": [{
        "http": "http://1.15.172.119:9100/metrics",
        "interval": "5s"
    }]
}
EOF


cat > ~/prometheus-yml/consul-yml/node-exporter-json/node-exporter-192.168.1.201.json << 'EOF'
{
    "id": "192.168.1.201-node-exporter",
    "name": "192.168.1.201-node-exporter",
    "address": "192.168.1.201",
    "port": 9100,
    "tags": ["node-exporter"],
    "checks": [{
        "http": "http://192.168.1.201:9100/metrics",
        "interval": "5s"
    }]
}
EOF


cat > ~/prometheus-yml/consul-yml/node-exporter-json/node-exporter-192.168.1.202.json << 'EOF'
{
    "id": "192.168.1.202-node-exporter",
    "name": "192.168.1.202-node-exporter",
    "address": "192.168.1.202",
    "port": 9100,
    "tags": ["node-exporter"],
    "checks": [{
        "http": "http://192.168.1.202:9100/metrics",
        "interval": "5s"
    }]
}
EOF


cat > ~/prometheus-yml/consul-yml/node-exporter-json/node-exporter-192.168.1.203.json << 'EOF'
{
    "id": "192.168.1.203-node-exporter",
    "name": "192.168.1.203-node-exporter",
    "address": "192.168.1.203",
    "port": 9100,
    "tags": ["node-exporter"],
    "checks": [{
        "http": "http://192.168.1.203:9100/metrics",
        "interval": "5s"
    }]
}
EOF


cat > ~/prometheus-yml/consul-yml/node-exporter-json/node-exporter-192.168.1.204.json << 'EOF'
{
    "id": "192.168.1.204-node-exporter",
    "name": "192.168.1.204-node-exporter",
    "address": "192.168.1.204",
    "port": 9100,
    "tags": ["node-exporter"],
    "checks": [{
        "http": "http://192.168.1.204:9100/metrics",
        "interval": "5s"
    }]
}
EOF


cat > ~/prometheus-yml/consul-yml/node-exporter-json/node-exporter-192.168.1.200.json << 'EOF'
{
    "id": "192.168.1.200-node-exporter",
    "name": "192.168.1.200-node-exporter",
    "address": "192.168.1.200",
    "port": 9100,
    "tags": ["node-exporter"],
    "checks": [{
        "http": "http://192.168.1.200:9100/metrics",
        "interval": "5s"
    }]
}
EOF


# 添加更多 JSON 文件，每个文件包含一个服务的信息
```

```shell
# 批量注册脚本
cat > ~/prometheus-yml/consul-yml/node-exporter-json/register-service.sh << 'EOF'
#!/bin/bash

CONSUL_API="https://prometheus-consul.openhhh.com/v1/agent/service/register"

declare -a SERVICES=(
    "node-exporter-1.15.172.119.json"
    "node-exporter-192.168.1.201.json"
    "node-exporter-192.168.1.202.json"
    "node-exporter-192.168.1.203.json"
    "node-exporter-192.168.1.204.json"
    "node-exporter-192.168.1.200.json"
    # 添加更多 JSON 文件，每个文件包含一个服务的信息
)

for SERVICE_FILE in "${SERVICES[@]}"; do
    curl -X PUT --data @"$SERVICE_FILE" "$CONSUL_API"
done
EOF
```

```shell
# 批量下线脚本
cat > ~/prometheus-yml/consul-yml/node-exporter-json/deregister-service.sh << 'EOF'
#!/bin/bash

CONSUL_API="https://prometheus-consul.openhhh.com/v1/agent/service/deregister"

declare -a SERVICES=(
    "node-exporter-1.15.172.119.json"
    "node-exporter-192.168.1.201.json"
    "node-exporter-192.168.1.202.json"
    "node-exporter-192.168.1.203.json"
    "node-exporter-192.168.1.204.json"
    "node-exporter-192.168.1.200.json"
    # 添加更多 JSON 文件，每个文件包含一个服务的信息
)

for SERVICE_FILE in "${SERVICES[@]}"; do
    SERVICE_ID=$(jq -r .id "$SERVICE_FILE")
    curl -X PUT "$CONSUL_API/$SERVICE_ID"
done
EOF
```

```shell
mkdir -p ~/prometheus-yml/kube-yml
```

1、对`kube-controller-manager`的监控   

```shell
sed -i 's/bind-address=127.0.0.1/bind-address=0.0.0.0/g' /etc/kubernetes/manifests/kube-controller-manager.yaml
```

```shell
cat > ~/prometheus-yml/kube-yml/prometheus-kube-controller-manager-Service.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  namespace: kube-system
  name: kube-controller-manager
  labels:
    app.kubernetes.io/name: kube-controller-manager
spec:
  selector:
    component: kube-controller-manager
  ports:
  - name: https-metrics
    port: 10257
    targetPort: 10257
EOF
```

```shell
kubectl apply -f ~/prometheus-yml/kube-yml/prometheus-kube-controller-manager-Service.yml
```

2、对`kube-scheduler`的监控

```shell
sed -i 's/bind-address=127.0.0.1/bind-address=0.0.0.0/g' /etc/kubernetes/manifests/kube-scheduler.yaml
```

```shell
cat > ~/prometheus-yml/kube-yml/prometheus-kube-scheduler-Service.yml << EOF
apiVersion: v1
kind: Service
metadata:
  namespace: kube-system
  name: kube-scheduler
  labels:
    app.kubernetes.io/name: kube-scheduler
spec:
  selector:
    component: kube-scheduler
  ports:
  - name: https-metrics
    port: 10259  
    targetPort: 10259
EOF
```

```shell
kubectl apply -f ~/prometheus-yml/kube-yml/prometheus-kube-scheduler-Service.yml
```

3、对`kube-proxy`的监控

```shell
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e 's/metricsBindAddress: ""/metricsBindAddress: "0.0.0.0:10249"/' | \
kubectl diff -f - -n kube-system

kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e 's/metricsBindAddress: ""/metricsBindAddress: "0.0.0.0:10249"/' | \
kubectl apply -f - -n kube-system
```

```shell
kubectl rollout restart daemonset kube-proxy -n kube-system
```

```shell
netstat -tnlp |grep kube-proxy

netstat -antp|grep 10249
```

```shell
cat > ~/prometheus-yml/kube-yml/prometheus-kube-proxy-Service.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: kube-proxy
  namespace: kube-system
  labels:
    k8s-app: kube-proxy
spec:
  selector:
    k8s-app: kube-proxy
  ports:
  - name: https-metrics
    port: 10249
    targetPort: 10249
    protocol: TCP
EOF
```

```shell
kubectl apply -f ~/prometheus-yml/kube-yml/prometheus-kube-proxy-Service.yml
```

4、对`k8s-etcd`的监控

```shell
sed -i 's/127.0.0.1:2381/0.0.0.0:2381/g' /etc/kubernetes/manifests/etcd.yaml
```

```shell
cat > ~/prometheus-yml/kube-yml/etcd-k8s-master-Service.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: etcd-k8s
  namespace: kube-system
  labels:
    k8s-app: etcd
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - name: port
    port: 2381
---
apiVersion: v1
kind: Endpoints
metadata:
  name: etcd-k8s
  namespace: kube-system
  labels:
    k8s-app: etcd
subsets:
- addresses:
  - ip: 192.168.1.10
    nodeName: k8s-01
  ports:
  - name: port
    port: 2381
EOF
```

```shell
kubectl apply -f ~/prometheus-yml/kube-yml/etcd-k8s-master-Service.yml
```

> https://grafana.com/grafana/dashboards/9733-etcd-for-k8s-cn/
>
> 模版：9733

2、k8s 手撕方式安装 grafana

```shell
cat > ~/prometheus-yml/grafana-ConfigMap.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-config
  namespace: monitoring
data:
  grafana.ini: |
    [smtp]
    enabled = false
    host = localhost:25
    user =
    password =
    skip_verify = false
    from_address = admin@grafana.localhost
    from_name = Grafana
    [alerting]
    enabled =
    execute_alerts = true
EOF
```

```shell
kubectl apply -f ~/prometheus-yml/grafana-ConfigMap.yml
```

```shell
cat > ~/prometheus-yml/grafana-Deployment.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
  labels:
    app: grafana
spec:
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      securityContext:
        fsGroup: 472
        supplementalGroups:
          - 0
      containers:
        - name: grafana
          #image: grafana/grafana:11.6.0
          image: ccr.ccs.tencentyun.com/huanghuanhui/grafana:11.6.0
          imagePullPolicy: IfNotPresent
          ports:
          - containerPort: 3000
            name: http-grafana
            protocol: TCP
          env:
          - name: TZ
            value: Asia/Shanghai
          - name: GF_SECURITY_ADMIN_USER
            value: admin
          - name: GF_SECURITY_ADMIN_PASSWORD
            value: Admin@2025
          readinessProbe:
            failureThreshold: 3
            httpGet:
              path: /robots.txt
              port: 3000
              scheme: HTTP
            initialDelaySeconds: 10
            periodSeconds: 30
            successThreshold: 1
            timeoutSeconds: 2
          livenessProbe:
            failureThreshold: 3
            initialDelaySeconds: 30
            periodSeconds: 10
            successThreshold: 1
            tcpSocket:
              port: 3000
            timeoutSeconds: 1
          resources:
            limits:
              cpu: "1"
              memory: "2Gi"
            requests:
              cpu: "0.5"
              memory: "1Gi"
          volumeMounts:
            - mountPath: /var/lib/grafana
              name: grafana-data
            - mountPath: /etc/grafana
              name: config
      volumes:
        - name: grafana-data
          persistentVolumeClaim:
            claimName: grafana-pvc
        - name: config
          configMap:
            name: grafana-config
---
apiVersion: v1
kind:  PersistentVolumeClaim
metadata:
  name: grafana-pvc
  namespace: monitoring
spec:
  storageClassName: nfs-storage
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 2Ti
---
apiVersion: v1
kind: Service
metadata:
  name: grafana-service
  namespace: monitoring
  labels:
    app: grafana
spec:
  type: NodePort
  ports:
  - nodePort: 31998
    port: 3000
  selector:
    app: grafana
EOF
```

```shell
kubectl apply -f ~/prometheus-yml/grafana-Deployment.yml
```

```shell
cat > ~/prometheus-yml/grafana-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: prod-issuer 
    acme.cert-manager.io/http01-edit-in-place: "true" 
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: grafana.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana-service
            port:
              number: 3000

  tls:
  - hosts:
    - grafana.openhhh.com
    secretName: grafana-ingress-tls
EOF
```

```shell
#kubectl create secret -n monitoring \
#tls grafana-ingress-tls \
#--key=/root/ssl/openhhh.com.key \
#--cert=/root/ssl/openhhh.com.pem
```

```shell
kubectl apply -f ~/prometheus-yml/grafana-Ingress.yml
```

> 访问地址：https://grafana.openhhh.com
>
> 账号密码：admin、Admin@2024

> https://grafana.com/grafana/dashboards/
>
> 模版：8919、12159、13105、9276、12006

3、k8s 手撕方式安装 alertmanager

> 1、与qq邮箱集成
>
> 2、与企业微信集成 + webhook
>
> 3、与钉钉集成 + webhook

1、与qq邮箱集成（alertmanager-config）

```shell
cat > ~/prometheus-yml/alertmanager-qq-ConfigMap.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |-
    global:
      resolve_timeout: 5m
      smtp_smarthost: 'smtp.qq.com:465'
      smtp_from: '1308470940@qq.com'
      smtp_auth_username: '1308470940@qq.com'
      smtp_auth_password: 'kgwsqpzsvhxvjjii'
      smtp_hello: 'qq.com'
      smtp_require_tls: false
    route:
      group_by: ['alertname', 'cluster']
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 5m
      receiver: default
      routes:
      - receiver: email
        group_wait: 10s
        match:
          team: node
    templates:
      - '/etc/config/template/email.tmpl'
    receivers:
    - name: 'default'
      email_configs:
      - to: '1308470940@qq.com'
        html: '{{ template "email.html" . }}'
        headers: { Subject: "[WARN] Prometheus 告警邮件" }
    - name: 'email'
      email_configs:
      - to: '1308470940@qq.com'
        send_resolved: true
EOF
```

2、与企业微信集成（alertmanager-config）

```shell
cat > ~/prometheus-yml/alertmanager-webhook-WeCom-ConfigMap.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |-
    global:
      resolve_timeout: 5m
    route:
      receiver: webhook
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
      group_by: [alertname]
      routes:
      - receiver: webhook
        group_wait: 10s
        match:
          team: node
    receivers:
    - name: webhook
      webhook_configs:
      - url: 'http://alertmanager-webhook-wecom.monitoring.svc.cluster.local:8060/adapter/wx'
        send_resolved: true
EOF
```

3、与钉钉集成（为例）（alertmanager-config）

```shell
cat > ~/prometheus-yml/alertmanager-webhook-dingtalk-ConfigMap.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |-
    global:
      resolve_timeout: 5m
    route:
      receiver: webhook
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
      group_by: [alertname]
      routes:
      - receiver: webhook
        group_wait: 10s
        match:
          team: node
    receivers:
    - name: webhook
      webhook_configs:
      - url: 'http://alertmanager-webhook-dingtalk.monitoring.svc.cluster.local:8060/dingtalk/webhook1/send'
        send_resolved: true
EOF
```

```shell
cat > ~/prometheus-yml/alertmanager-Deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alertmanager
  template:
    metadata:
      labels:
        app: alertmanager
    spec:
      containers:
      - name: alertmanager
        #image: prom/alertmanager:v0.28.1
        image: ccr.ccs.tencentyun.com/huanghuanhui/alertmanager:v0.28.1
        ports:
        - containerPort: 9093
          name: http
        volumeMounts:
        - name: alertmanager-config
          mountPath: /etc/alertmanager
        - name: alertmanager-data
          mountPath: /alertmanager
        - name: localtime
          mountPath: /etc/localtime
        command:
        - "/bin/alertmanager"
        - "--config.file=/etc/alertmanager/alertmanager.yml"
        - "--storage.path=/alertmanager"
      volumes:
      - name: alertmanager-config
        configMap:
          name: alertmanager-config
      - name: alertmanager-data
        persistentVolumeClaim:
          claimName: alertmanager-pvc
      - name: localtime
        hostPath:
          path: /etc/localtime

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: alertmanager-pvc
  namespace: monitoring
spec:
  storageClassName: nfs-storage
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: "2Ti"
EOF
```

1、与qq邮箱集成

```shell
kubectl apply -f ~/prometheus-yml/alertmanager-qq-ConfigMap.yml

kubectl apply -f ~/prometheus-yml/alertmanager-Deployment.yaml
```

2、与企业微信集成 + webhook

```shell
kubectl apply -f ~/prometheus-yml/alertmanager-webhook-WeCom-ConfigMap.yml

kubectl apply -f ~/prometheus-yml/alertmanager-Deployment.yaml
```

3、与钉钉集成 + webhook

```shell
kubectl apply -f ~/prometheus-yml/alertmanager-webhook-dingtalk-ConfigMap.yml

kubectl apply -f ~/prometheus-yml/alertmanager-Deployment.yaml
```

```shell
cat > ~/prometheus-yml/alertmanager-Service.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: alertmanager-service
  namespace: monitoring
spec:
  selector:
    app: alertmanager
    
  type: NodePort
  ports:
  - name: web
    port: 9093
    targetPort: http
    nodePort: 31997
EOF
```

```shell
kubectl apply -f ~/prometheus-yml/alertmanager-Service.yml
```

```shell
cat > ~/prometheus-yml/alertmanager-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: alertmanager-ingress
  namespace: monitoring
  annotations:
    cert-manager.io/cluster-issuer: prod-issuer 
    acme.cert-manager.io/http01-edit-in-place: "true" 
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: alertmanager.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: alertmanager-service
            port:
              number: 9093

  tls:
  - hosts:
    - prometheus.openhhh.com
    secretName: alertmanager-ingress-tls
EOF
```

```shell
#kubectl create secret -n monitoring \
#tls alertmanager-ingress-tls \
#--key=/root/ssl/openhhh.com.key \
#--cert=/root/ssl/openhhh.com.pem
```

```shell
kubectl apply -f ~/prometheus-yml/alertmanager-Ingress.yml
```

> 访问地址：https://alertmanager.openhhh.com

`与企业微信集成（alertmanager-webhook-wecom）`

```shell
cat > ~/prometheus-yml/alertmanager-webhook-WeCom-Deployment.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: alertmanager-webhook-wecom
  name: alertmanager-webhook-wecom
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: alertmanager-webhook-wecom
  template:
    metadata:
      labels:
        app: alertmanager-webhook-wecom
    spec:
      containers:
      - args:
        - --adapter=/app/prometheusalert/wx.js=/adapter/wx=https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=fb916d40-f5e1-40fb-ac7e-e73324aaab1f  #注意变更这个地址，即企业微信机器人的webhook地址
        image: registry.cn-hangzhou.aliyuncs.com/guyongquan/webhook-adapter  
        name: alertmanager-webhook-wecom
        ports:
        - containerPort: 80
          protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: alertmanager-webhook-wecom
  name: alertmanager-webhook-wecom
  namespace: monitoring
spec:
  ports:
  - port: 8060
    protocol: TCP
    targetPort: 80
  selector:
    app: alertmanager-webhook-wecom
  type: ClusterIP
EOF
```

```shell
kubectl apply -f ~/prometheus-yml/alertmanager-webhook-WeCom-Deployment.yml
```

`与钉钉集成：alertmanager-webhook-dingtalk`

```shell
cat > ~/prometheus-yml/alertmanager-webhook-dingtalk-Deployment.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-webhook-dingtalk
  namespace: monitoring
data:
  config.yaml: |-
    templates:
      - /config/template.tmpl

    targets:
      webhook1:
        url: https://oapi.dingtalk.com/robot/send?access_token=423eedfe3802198314e15f712f0578545b74a44cb982723623db2fb034bdc83e
        secret: SECd3c53fbbb1df76a987a658e0ca759ef371ae955ff731af8945219e99d143d3ae

  # 告警模版(也就是钉钉收到怎样的信息模板)
  template.tmpl: |-
    {{ define "__subject" }}
    [{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}]
    {{ end }}


    {{ define "__alert_list" }}{{ range . }}
    ---
    {{ if .Labels.owner }}@{{ .Labels.owner }}{{ end }}

    >- **告警状态 ：** {{   .Status }}

    >- **告警级别 ：** **{{ .Labels.severity }}**

    >- **告警类型 ：** {{ .Labels.alertname }}

    >- **告警主机 ：** {{ .Labels.instance }} 

    >- **告警主题 ：** {{ .Annotations.summary }}

    >- **告警信息 ：** {{ index .Annotations "description" }}

    >- **告警时间 ：** {{ dateInZone "2006.01.02 15:04:05" (.StartsAt) "Asia/Shanghai" }}
    {{ end }}{{ end }}

    {{ define "__resolved_list" }}{{ range . }}
    ---
    {{ if .Labels.owner }}@{{ .Labels.owner }}{{ end }}

    >- **告警状态 ：** {{   .Status }}

    >- **告警类型 ：** {{ .Labels.alertname }}

    >- **告警主机 ：** {{ .Labels.instance }} 

    >- **告警主题 ：** {{ .Annotations.summary }}

    >- **告警信息 ：** {{ index .Annotations "description" }}

    >- **告警时间 ：** {{ dateInZone "2006.01.02 15:04:05" (.StartsAt) "Asia/Shanghai" }}

    >- **恢复时间 ：** {{ dateInZone "2006.01.02 15:04:05" (.EndsAt) "Asia/Shanghai" }}
    {{ end }}{{ end }}


    {{ define "default.title" }}
    {{ template "__subject" . }}
    {{ end }}

    {{ define "default.content" }}
    {{ if gt (len .Alerts.Firing) 0 }}
    **Prometheus-Alertmanager 监控到{{ .Alerts.Firing | len  }}个故障**
    {{ template "__alert_list" .Alerts.Firing }}
    ---
    {{ end }}

    {{ if gt (len .Alerts.Resolved) 0 }}
    **恢复{{ .Alerts.Resolved | len  }}个故障**
    {{ template "__resolved_list" .Alerts.Resolved }}
    {{ end }}
    {{ end }}


    {{ define "ding.link.title" }}{{ template "default.title" . }}{{ end }}
    {{ define "ding.link.content" }}{{ template "default.content" . }}{{ end }}
    {{ template "default.title" . }}
    {{ template "default.content" . }}

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager-webhook-dingtalk
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alertmanager-webhook-dingtalk
  template:
    metadata:
      labels:
        app: alertmanager-webhook-dingtalk
    spec:
      volumes:
        - name: config
          configMap:
            name: alertmanager-webhook-dingtalk
      containers:
        - name: alertmanager-webhook-dingtalk
          image: ccr.ccs.tencentyun.com/huanghuanhui/prometheus-alertmanager-webhook-dingtalk:v1
          imagePullPolicy: Always
          args:
            - --web.listen-address=:8060
            - --config.file=/config/config.yaml
          volumeMounts:
            - name: config
              mountPath: /config
          resources:
            limits:
              cpu: 100m
              memory: 100Mi
          ports:
            - name: http
              containerPort: 8060

---
apiVersion: v1
kind: Service
metadata:
  name: alertmanager-webhook-dingtalk
  namespace: monitoring
spec:
  selector:
    app: alertmanager-webhook-dingtalk
  ports:
    - name: http
      port: 8060
      targetPort: http
EOF
```

```shell
kubectl apply -f ~/prometheus-yml/alertmanager-webhook-dingtalk-Deployment.yml
```

企业微信添加多个机器人

````shell
cat > alertmanager-webhook-WeCom-ConfigMap.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: monitoring
data:
  alertmanager.yml: |-
    global:
      resolve_timeout: 5m
    route:
      receiver: webhook
      group_wait: 10s
      group_interval: 2m
      repeat_interval: 1h
      group_by: [alertname]
    receivers:
    - name: webhook
      webhook_configs:
      - url: 'http://alertmanager-webhook-wecom.monitoring.svc.cluster.local:8060/adapter/wx'
        send_resolved: true
      - url: 'http://alertmanager-webhook-wecom-2.monitoring.svc.cluster.local:8060/adapter/wx'
        send_resolved: true
EOF
````

```shell
cat > alertmanager-webhook-WeCom-Deployment.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: alertmanager-webhook-wecom-2
  name: alertmanager-webhook-wecom-2
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app: alertmanager-webhook-wecom-2
  template:
    metadata:
      labels:
        app: alertmanager-webhook-wecom-2
    spec:
      containers:
      - args:
        - --adapter=/app/prometheusalert/wx.js=/adapter/wx=https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=xxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxx
        image: ccr.ccs.tencentyun.com/huanghuanhui/prometheus-webhook:2025  
        name: alertmanager-webhook-wecom-2
        ports:
        - containerPort: 80
          protocol: TCP
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: alertmanager-webhook-wecom-2
  name: alertmanager-webhook-wecom-2
  namespace: monitoring
spec:
  ports:
  - port: 8060
    protocol: TCP
    targetPort: 80
  selector:
    app: alertmanager-webhook-wecom-2
  type: ClusterIP
EOF
```





`yml 截图`

![](https://md.huanghuanhui.com/2023-11-27-prometheus.png)

`钉钉告警截图`

![](https://md.huanghuanhui.com/2023-11-27-prometheus-dingtalk.png)

