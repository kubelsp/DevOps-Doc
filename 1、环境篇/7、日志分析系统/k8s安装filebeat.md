k8s安装filebeat

https://github.com/elastic/beats/blob/v9.0.3/deploy/kubernetes/filebeat-kubernetes.yaml

`````shell
cat > filebeat.yml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: filebeat
  namespace: elk
  labels:
    k8s-app: filebeat
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: filebeat
  labels:
    k8s-app: filebeat
rules:
- apiGroups: [""] # "" indicates the core API group
  resources:
  - namespaces
  - pods
  - nodes
  verbs:
  - get
  - watch
  - list
- apiGroups: ["apps"]
  resources:
    - replicasets
  verbs: ["get", "list", "watch"]
- apiGroups: ["batch"]
  resources:
    - jobs
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: filebeat
  # should be the namespace where filebeat is running
  namespace: elk
  labels:
    k8s-app: filebeat
rules:
  - apiGroups:
      - coordination.k8s.io
    resources:
      - leases
    verbs: ["get", "create", "update"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: filebeat-kubeadm-config
  namespace: elk
  labels:
    k8s-app: filebeat
rules:
  - apiGroups: [""]
    resources:
      - configmaps
    resourceNames:
      - kubeadm-config
    verbs: ["get"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: filebeat
subjects:
- kind: ServiceAccount
  name: filebeat
  namespace: elk
roleRef:
  kind: ClusterRole
  name: filebeat
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: filebeat
  namespace: elk
subjects:
  - kind: ServiceAccount
    name: filebeat
    namespace: elk
roleRef:
  kind: Role
  name: filebeat
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: filebeat-kubeadm-config
  namespace: elk
subjects:
  - kind: ServiceAccount
    name: filebeat
    namespace: elk
roleRef:
  kind: Role
  name: filebeat-kubeadm-config
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: filebeat-config
  namespace: elk
  labels:
    k8s-app: filebeat
data:
  filebeat.yml: |-
    filebeat.inputs:
    - type: filestream
      id: kubernetes-container-logs
      paths:
        - /var/log/containers/*.log
      fields:
        log_type: "hhh"                  # 添加固定字段
      fields_under_root: true              # 将字段提升到根级别
      parsers:
        - container: ~
      prospector:
        scanner:
          fingerprint.enabled: true
          symlinks: true
      file_identity.fingerprint: ~
      processors:
        - add_kubernetes_metadata:
            host: ${NODE_NAME}
            matchers:
            - logs_path:
                logs_path: "/var/log/containers/"

    processors:
      # 添加元数据
      - add_cloud_metadata: ~
      - add_host_metadata: ~
      - add_kubernetes_metadata:
          default_indexers.enabled: true
          default_matchers.enabled: true
          # 优化Kubernetes元数据采集
          indexers:
            - ip_port:
                host: ${NODE_NAME}
          matchers:
            - logs_path:
                logs_path: "/var/log/containers/"

      # 基于标签的处理
      - add_tags:
          tags: ["kubernetes", "container"]
          target: "event"

      # 移除多余的字段
      - drop_fields:
          fields:
            - host
            - ecs
            - log
            - agent
            - input
            - stream
            - container
            - kubernetes.pod.uid
            - kubernetes.namespace_uid
            - kubernetes.namespace_labels
            - kubernetes.node.uid
            - kubernetes.node.labels
            - kubernetes.replicaset
            - kubernetes.labels
            - kubernetes.node.name
          ignore_missing: true


    # Elasticsearch配置(保留原始配置)
    cloud.id: ${ELASTIC_CLOUD_ID}
    cloud.auth: ${ELASTIC_CLOUD_AUTH}

    # Kafka输出配置优化
    output.kafka:
      hosts: ['kafka-headless:9092']
      topic: 'k8s-logs'
      partition.round_robin:
        reachable_only: false
      required_acks: 1
      compression: gzip
      max_message_bytes: 1000000
      worker: 2
      timeout: 30s
      bulk_max_size: 2048
      retry.enabled: true
      retry.backoff.init: 1s
      retry.backoff.max: 60s
      max_retries: 3

---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: filebeat
  namespace: elk
  labels:
    k8s-app: filebeat
spec:
  selector:
    matchLabels:
      k8s-app: filebeat
  template:
    metadata:
      labels:
        k8s-app: filebeat
    spec:
      serviceAccountName: filebeat
      terminationGracePeriodSeconds: 30
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet
      containers:
      - name: filebeat
        image: docker.elastic.co/beats/filebeat-wolfi:9.0.3
        args: [
          "-c", "/etc/filebeat.yml",
          "-e",
        ]
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        securityContext:
          runAsUser: 0
          # If using Red Hat OpenShift uncomment this:
          #privileged: true
        resources:
          limits:
            memory: 2000Mi
          requests:
            cpu: 100m
            memory: 100Mi
        volumeMounts:
        - name: config
          mountPath: /etc/filebeat.yml
          readOnly: true
          subPath: filebeat.yml
        - name: data
          mountPath: /usr/share/filebeat/data
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: varlog
          mountPath: /var/log
          readOnly: true
      volumes:
      - name: config
        configMap:
          defaultMode: 0640
          name: filebeat-config
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: varlog
        hostPath:
          path: /var/log
      # data folder stores a registry of read status for all files, so we don't send everything again on a Filebeat pod restart
      - name: data
        hostPath:
          # When filebeat runs as non-root user, this directory needs to be writable by group (g+w).
          path: /var/lib/filebeat-data
          type: DirectoryOrCreate
EOF
`````

