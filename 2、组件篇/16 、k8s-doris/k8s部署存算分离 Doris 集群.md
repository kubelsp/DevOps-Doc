### k8s部署存算分离 Doris 集群

> [GitHub - FoundationDB/fdb-kubernetes-operator: A kubernetes operator for FoundationDB](https://github.com/FoundationDB/fdb-kubernetes-operator)
>
> [GitHub - apache/doris-operator: Doris kubernetes operator](https://github.com/apache/doris-operator)
>
> k8s版本：v1.32.3
>
> k8s-fdb版本：v2.1.0
>
> k8s-doris版本：25.2.1（doris-3.0.3）

````shell
kubectl taint nodes k8s-doris-10.1.1.201 doris=doris:NoSchedule
kubectl taint nodes k8s-doris-10.1.1.202 doris=doris:NoSchedule
kubectl taint nodes k8s-doris-10.1.1.203 doris=doris:NoSchedule
````

### 前提（k8s部署 FoundationDB）

1、crds

```shell
mkdir -p ~/k8s-doris-yml/{k8s-doris-yml,k8s-fdb-yml}
```

````shell
cd ~/k8s-doris-yml/k8s-fdb-yml
````

```shell
wget https://github.com/FoundationDB/fdb-kubernetes-operator/raw/refs/tags/v2.1.0/config/crd/bases/apps.foundationdb.org_foundationdbbackups.yaml

wget https://github.com/FoundationDB/fdb-kubernetes-operator/raw/refs/tags/v2.1.0/config/crd/bases/apps.foundationdb.org_foundationdbclusters.yaml

wget https://github.com/FoundationDB/fdb-kubernetes-operator/raw/refs/tags/v2.1.0/config/crd/bases/apps.foundationdb.org_foundationdbrestores.yaml
```

````shell
kubectl apply -f .
````

2、部署 fdb-kubernetes-operator 服务

````shell
wget -O fdb-operator.yaml https://github.com/FoundationDB/fdb-kubernetes-operator/raw/refs/tags/v2.1.0/config/samples/deployment.yaml
````

`````shell
kubectl apply -f fdb-operator.yaml
`````

````shell
cat > fdb-operator.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: fdb-kubernetes-operator-controller-manager
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  creationTimestamp: null
  name: fdb-kubernetes-operator-manager-clusterrole
rules:
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: fdb-kubernetes-operator-manager-role
rules:
- apiGroups:
  - ""
  resources:
  - configmaps
  - events
  - persistentvolumeclaims
  - pods
  - secrets
  - services
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
- apiGroups:
  - apps
  resources:
  - deployments
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
- apiGroups:
  - apps.foundationdb.org
  resources:
  - foundationdbbackups
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
- apiGroups:
  - apps.foundationdb.org
  resources:
  - foundationdbbackups/status
  verbs:
  - get
  - patch
  - update
- apiGroups:
  - apps.foundationdb.org
  resources:
  - foundationdbclusters
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
- apiGroups:
  - apps.foundationdb.org
  resources:
  - foundationdbclusters/status
  verbs:
  - get
  - patch
  - update
- apiGroups:
  - apps.foundationdb.org
  resources:
  - foundationdbrestores
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
- apiGroups:
  - apps.foundationdb.org
  resources:
  - foundationdbrestores/status
  verbs:
  - get
  - patch
  - update
- apiGroups:
  - coordination.k8s.io
  resources:
  - leases
  verbs:
  - create
  - delete
  - get
  - list
  - patch
  - update
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  creationTimestamp: null
  name: fdb-kubernetes-operator-manager-rolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: fdb-kubernetes-operator-manager-role
subjects:
- kind: ServiceAccount
  name: fdb-kubernetes-operator-controller-manager
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  creationTimestamp: null
  name: fdb-kubernetes-operator-manager-clusterrolebinding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: fdb-kubernetes-operator-manager-clusterrole
subjects:
- kind: ServiceAccount
  name: fdb-kubernetes-operator-controller-manager
  namespace: metadata.namespace
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: fdb-kubernetes-operator-controller-manager
    control-plane: controller-manager
  name: fdb-kubernetes-operator-controller-manager
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fdb-kubernetes-operator-controller-manager
  template:
    metadata:
      labels:
        app: fdb-kubernetes-operator-controller-manager
        control-plane: controller-manager
    spec:
      tolerations:
        - key: "doris"
          operator: "Equal"
          value: "doris"
          effect: "NoSchedule"
      containers:
      - command:
        - /manager
        env:
        - name: WATCH_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        #image: foundationdb/fdb-kubernetes-operator:v2.1.0
        image: ccr.ccs.tencentyun.com/huanghuanhui/fdb-kubernetes-operator:v2.1.0
        name: manager
        ports:
        - containerPort: 8080
          name: metrics
        resources:
          limits:
            cpu: 500m
            memory: 256Mi
          requests:
            cpu: 500m
            memory: 256Mi
        securityContext:
          allowPrivilegeEscalation: false
          privileged: false
          readOnlyRootFilesystem: true
        volumeMounts:
        - mountPath: /tmp
          name: tmp
        - mountPath: /var/log/fdb
          name: logs
        - mountPath: /usr/bin/fdb
          name: fdb-binaries
      initContainers:
      - args:
        - --copy-library
        - "6.2"
        - --copy-binary
        - fdbcli
        - --copy-binary
        - fdbbackup
        - --copy-binary
        - fdbrestore
        - --output-dir
        - /var/output-files/6.2.30
        - --init-mode
        #image: foundationdb/foundationdb-kubernetes-sidecar:6.2.30-1
        image: ccr.ccs.tencentyun.com/huanghuanhui/foundationdb-kubernetes-sidecar:6.2.30-1
        name: foundationdb-kubernetes-init-6-2
        volumeMounts:
        - mountPath: /var/output-files
          name: fdb-binaries
      - args:
        - --copy-library
        - "6.3"
        - --copy-binary
        - fdbcli
        - --copy-binary
        - fdbbackup
        - --copy-binary
        - fdbrestore
        - --output-dir
        - /var/output-files/6.3.24
        - --init-mode
        #image: foundationdb/foundationdb-kubernetes-sidecar:6.3.24-1
        image: ccr.ccs.tencentyun.com/huanghuanhui/foundationdb-kubernetes-sidecar:6.3.24-1
        name: foundationdb-kubernetes-init-6-3
        volumeMounts:
        - mountPath: /var/output-files
          name: fdb-binaries
      - args:
        - --copy-library
        - "7.1"
        - --copy-binary
        - fdbcli
        - --copy-binary
        - fdbbackup
        - --copy-binary
        - fdbrestore
        - --output-dir
        - /var/output-files/7.1.26
        - --init-mode
        #image: foundationdb/foundationdb-kubernetes-sidecar:7.1.26-1
        image: ccr.ccs.tencentyun.com/huanghuanhui/foundationdb-kubernetes-sidecar:7.1.26-1
        name: foundationdb-kubernetes-init-7-1
        volumeMounts:
        - mountPath: /var/output-files
          name: fdb-binaries
      securityContext:
        fsGroup: 4059
        runAsGroup: 4059
        runAsUser: 4059
      serviceAccountName: fdb-kubernetes-operator-controller-manager
      terminationGracePeriodSeconds: 10
      volumes:
      - emptyDir: {}
        name: tmp
      - emptyDir: {}
        name: logs
      - emptyDir: {}
        name: fdb-binaries
EOF
````

3、部署 FoundationDB 集群

````shell
wget -O fdb-cluster.yaml https://github.com/FoundationDB/fdb-kubernetes-operator/raw/refs/tags/v2.1.0/config/samples/cluster.yaml
````

````shell
kubectl apply -f fdb-cluster.yaml
````

```shell
cat > fdb-cluster.yaml << 'EOF'
apiVersion: apps.foundationdb.org/v1beta2
kind: FoundationDBCluster
metadata:
  name: fdb-cluster
spec:
  automationOptions:
    replacements:
      enabled: true
  faultDomain:
    key: foundationdb.org/none
  imageType: split
  labels:
    filterOnOwnerReference: false
    matchLabels:
      foundationdb.org/fdb-cluster-name: fdb-cluster
    processClassLabels:
    - foundationdb.org/fdb-process-class
    processGroupIDLabels:
    - foundationdb.org/fdb-process-group-id
  minimumUptimeSecondsForBounce: 60
  processCounts:
    cluster_controller: 1
    stateless: -1
  processes:
    general:
      customParameters:
      - knob_disable_posix_kernel_aio=1
      podTemplate:
        spec:
          tolerations:
            - key: "doris"
              operator: "Equal"
              value: "doris"
              effect: "NoSchedule"
          containers:
          - name: foundationdb
            resources:
              requests:
                cpu: 100m
                memory: 128Mi
            securityContext:
              runAsUser: 0
          - name: foundationdb-kubernetes-sidecar
            resources:
              limits:
                cpu: 100m
                memory: 128Mi
              requests:
                cpu: 100m
                memory: 128Mi
            securityContext:
              runAsUser: 0
          initContainers:
          - name: foundationdb-kubernetes-init
            resources:
              limits:
                cpu: 100m
                memory: 128Mi
              requests:
                cpu: 100m
                memory: 128Mi
            securityContext:
              runAsUser: 0
      volumeClaimTemplate:
        spec:
          storageClassName: dev-sc
          resources:
            requests:
              storage: 200G
  routing:
    defineDNSLocalityFields: true
  sidecarContainer:
    enableLivenessProbe: true
    enableReadinessProbe: false
  useExplicitListenAddress: true
  version: 7.1.26
  mainContainer:
    imageConfigs:
      - baseImage: ccr.ccs.tencentyun.com/huanghuanhui/foundationdb
  sidecarContainer:
    imageConfigs:
      - baseImage: ccr.ccs.tencentyun.com/huanghuanhui/foundationdb-kubernetes-sidecar
EOF
```

### k8s-doris

1、crds

````shell
wget https://github.com/apache/doris-operator/raw/refs/tags/25.2.1/config/crd/bases/crds.yaml

kubectl create -f crds.yaml
````

2、部署 Doris Operator

````shell
wget https://github.com/apache/doris-operator/raw/refs/tags/25.2.1/config/operator/disaggregated-operator.yaml
````

```shell
sed -i 's|selectdb/doris.k8s-operator:latest|ccr.ccs.tencentyun.com/huanghuanhui/doris.k8s-operator:25.2.1|g' disaggregated-operator.yaml
```

````shell
kubectl apply -f disaggregated-operator.yaml
````

3、部署ddc

````shell
cat > cm.yml << 'EOF'
apiVersion: v1
data:
  doris_cloud.conf: |
    # // meta_service
    brpc_listen_port = 5000
    brpc_num_threads = -1
    brpc_idle_timeout_sec = 30
    http_token = greedisgood9999

    # // doris txn config
    label_keep_max_second = 259200
    expired_txn_scan_key_nums = 1000

    # // logging
    log_dir = ./log/
    # info warn error
    log_level = info
    log_size_mb = 1024
    log_filenum_quota = 10
    log_immediate_flush = false
    # log_verbose_modules = *

    # //max stage num
    max_num_stages = 40
kind: ConfigMap
metadata:
  name: doris-metaservice
  namespace: doris

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: fe-configmap
  namespace: doris
  labels:
    app.kubernetes.io/component: fe
data:
  fe.conf: |
    CUR_DATE=`date +%Y%m%d-%H%M%S`
    # Log dir
    LOG_DIR = ${DORIS_HOME}/log
    # For jdk 17, this JAVA_OPTS will be used as default JVM options
    JAVA_OPTS_FOR_JDK_17="-Djavax.security.auth.useSubjectCredsOnly=false -Xmx8192m -Xms8192m -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$LOG_DIR -Xlog:gc*:$LOG_DIR/fe.gc.log.$CUR_DATE:time,uptime:filecount=10,filesize=50M --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens java.base/jdk.internal.ref=ALL-UNNAMED"
    # INFO, WARN, ERROR, FATAL
    sys_log_level = INFO
    # NORMAL, BRIEF, ASYNC
    sys_log_mode = NORMAL
    # Default dirs to put jdbc drivers,default value is ${DORIS_HOME}/jdbc_drivers
    # jdbc_drivers_dir = ${DORIS_HOME}/jdbc_drivers
    http_port = 8030
    rpc_port = 9020
    query_port = 9030
    edit_log_port = 9010
    enable_fqdn_mode=true

---
apiVersion: v1
kind: ConfigMap
metadata:
  name: be-configmap
  namespace: doris
  labels:
    app.kubernetes.io/component: be
data:
  be.conf: |
    # For jdk 17, this JAVA_OPTS will be used as default JVM options
    JAVA_OPTS_FOR_JDK_17="-Xmx1024m -DlogPath=$LOG_DIR/jni.log -Xlog:gc*:$LOG_DIR/be.gc.log.$CUR_DATE:time,uptime:filecount=10,filesize=50M -Djavax.security.auth.useSubjectCredsOnly=false -Dsun.security.krb5.debug=true -Dsun.java.command=DorisBE -XX:-CriticalJNINatives -XX:+IgnoreUnrecognizedVMOptions --add-opens=java.base/java.lang=ALL-UNNAMED --add-opens=java.base/java.lang.invoke=ALL-UNNAMED --add-opens=java.base/java.lang.reflect=ALL-UNNAMED --add-opens=java.base/java.io=ALL-UNNAMED --add-opens=java.base/java.net=ALL-UNNAMED --add-opens=java.base/java.nio=ALL-UNNAMED --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED --add-opens=java.base/java.util.concurrent.atomic=ALL-UNNAMED --add-opens=java.base/sun.nio.ch=ALL-UNNAMED --add-opens=java.base/sun.nio.cs=ALL-UNNAMED --add-opens=java.base/sun.security.action=ALL-UNNAMED --add-opens=java.base/sun.util.calendar=ALL-UNNAMED --add-opens=java.security.jgss/sun.security.krb5=ALL-UNNAMED --add-opens=java.management/sun.management=ALL-UNNAMED"
    file_cache_path = [{"path":"/mnt/disk1/doris_cloud/file_cache","total_size":107374182400,"query_limit":107374182400}]
EOF
````

```shell
kubectl apply -f cm.yml
```

````shell
wget https://github.com/apache/doris-operator/raw/refs/tags/25.2.1/doc/examples/disaggregated/cluster/ddc-sample.yaml
````

```shell
cat > ddc-sample.yaml << 'EOF'
apiVersion: disaggregated.cluster.doris.com/v1
kind: DorisDisaggregatedCluster
metadata:
  name: disaggregated-cluster
spec:
  metaService:
    image: ccr.ccs.tencentyun.com/huanghuanhui/doris:ms-3.0.3
    fdb:
      configMapNamespaceName:
        name: fdb-cluster-config
        namespace: doris
    # 添加容忍（如果 metaService 支持 Pod 模板配置）
    tolerations:
    - key: "doris"
      operator: "Equal"
      value: "doris"
      effect: "NoSchedule"
  feSpec:
    replicas: 2
    image: ccr.ccs.tencentyun.com/huanghuanhui/doris:fe-3.0.3
    # 添加容忍
    tolerations:
    - key: "doris"
      operator: "Equal"
      value: "doris"
      effect: "NoSchedule"
  computeGroups:
    - uniqueId: cg1
      replicas: 3
      image: ccr.ccs.tencentyun.com/huanghuanhui/doris:be-3.0.3
      # 添加容忍
      tolerations:
      - key: "doris"
        operator: "Equal"
        value: "doris"
        effect: "NoSchedule"
    - uniqueId: cg2
      replicas: 3
      image: ccr.ccs.tencentyun.com/huanghuanhui/doris:be-3.0.3
      # 添加容忍
      tolerations:
      - key: "doris"
        operator: "Equal"
        value: "doris"
        effect: "NoSchedule"
EOF
```

````shell
kubectl apply -f ddc-sample.yaml
````

###### 部署一个mysql-client客户端

````shell
cat > ~/k8s-doris-yml/mysql-client.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql-client
  namespace: doris
spec:
  serviceName: mysql-client-headless
  replicas: 1
  selector:
    matchLabels:
      app: mysql-client
  template:
    metadata:
      labels:
        app: mysql-client
    spec:
      tolerations:
        - key: "doris"
          operator: "Equal"
          value: "doris"
          effect: "NoSchedule"
      containers:
      - name: mysql-client
        #image: mysql:5.7.44
        image: ccr.ccs.tencentyun.com/huanghuanhui/mysql:5.7.44
        imagePullPolicy: IfNotPresent
#       resources:
#         limits:
#           cpu: "2"
#           memory: "4Gi"
#         requests:
#           cpu: "2"
#           memory: "4Gi"
        ports:
        - name: mysql-client
          containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "Admin@2025"
        volumeMounts:
        - mountPath: /etc/localtime
          name: localtime
      volumes:
      - name: localtime
        hostPath:
          path: /etc/localtime
EOF
````

````shell
kubectl apply -f ~/k8s-doris-yml/mysql-client.yml
````

````shell
mysql -uroot -P9030 -h disaggregated-cluster-fe
````

配置对象存储

`````shell
# MYSQL 命令执行：S3 Storage Vault 
CREATE STORAGE VAULT IF NOT EXISTS s3_vault
    PROPERTIES (
        "type"="S3",
        "s3.endpoint" = "oss-cn-shanghai-internal.aliyuncs.com", 
        "s3.region" = "cn-shanghai",
        "s3.bucket" = "k8s-doris-dev",
        "s3.root.path" = "k8s-doris-dev", 
        "s3.access_key" = "ak-xxxxxxxxxxxx",
        "s3.secret_key" = "sk-xxxxxxxxxxxxxxxxxxxxx",
        "provider" = "OSS",
        "use_path_style" = "false"
    );

SET s3_vault AS DEFAULT STORAGE VAULT;
`````

创建库、表、插入数据测试

````shell
-- 查看 FE 节点状态
SHOW FRONTENDS;

-- 查看 BE 节点状态
SHOW BACKENDS;

-- 创建测试数据库
CREATE DATABASE test_db;
USE test_db;

-- 创建测试表
CREATE TABLE test_tbl
(
    id INT,
    name VARCHAR(50),
    score DECIMAL(10,2)
)
UNIQUE KEY(id)
DISTRIBUTED BY HASH(id) BUCKETS 3;

-- 插入测试数据
INSERT INTO test_tbl VALUES 
(1, 'Tom', 89.5),
(2, 'Jerry', 92.0),
(3, 'Jack', 85.5);

-- 查询数据
SELECT * FROM test_tbl;
````

