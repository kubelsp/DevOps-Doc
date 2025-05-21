### k8s部署存算一体 Doris 集群

> [GitHub - apache/doris-operator: Doris kubernetes operator](https://github.com/apache/doris-operator)
>
> k8s版本：v1.33.1
>
> k8s-doris版本：25.4.0（doris-3.0.3）

````shell
kubectl taint nodes k8s-doris-10.1.1.201 doris=doris:NoSchedule
kubectl taint nodes k8s-doris-10.1.1.202 doris=doris:NoSchedule
kubectl taint nodes k8s-doris-10.1.1.203 doris=doris:NoSchedule
````

````shell
mkdir -p ~/k8s-doris-yml

kubectl create ns doris
````

### k8s-doris

1、crds

````shell
cd ~/k8s-doris-yml && wget https://github.com/apache/doris-operator/raw/refs/tags/25.4.0/config/crd/bases/crds.yaml
````

```shell
kubectl create -f ~/k8s-doris-yml/crds.yaml
```

2、部署 Doris Operator

````shell
cd ~/k8s-doris-yml && wget https://github.com/apache/doris-operator/raw/refs/tags/25.4.0/config/operator/disaggregated-operator.yaml
````

```shell
sed -i 's|selectdb/doris.k8s-operator:latest|ccr.ccs.tencentyun.com/huanghuanhui/doris.k8s-operator:25.2.1|g' ~/k8s-doris-yml/disaggregated-operator.yaml
```

````shell
kubectl apply -f ~/k8s-doris-yml/disaggregated-operator.yaml
````

3、部署ddc

````shell
cat > ~/k8s-doris-yml/cm.yml << 'EOF'
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
kubectl apply -f ~/k8s-doris-yml/cm.yml
```

```shell
cat > ~/k8s-doris-yml/doriscluster.yml << 'EOF'
apiVersion: doris.selectdb.com/v1
kind: DorisCluster
metadata:
  labels:
    app.kubernetes.io/name: doriscluster
    app.kubernetes.io/instance: doriscluster-sample
    app.kubernetes.io/part-of: doris-operator
  name: doriscluster
spec:
  authSecret: doris-cluster-secret
  feSpec:
    configMapInfo:
      configMapName: fe-configmap
      resolveKey: fe.conf
    replicas: 3
    #limits:
      #cpu: 6
      #memory: 12Gi
    #requests:
      #cpu: 0.5
      #memory: 2Gi
    #image: apache/doris:fe-3.0.5
    image: ccr.ccs.tencentyun.com/huanghuanhui/doris:fe-3.0.5
    persistentVolumes:
    - mountPath: /opt/apache-doris/fe/doris-meta
      name: fe-meta
      persistentVolumeClaimSpec:
        storageClassName: nfs-storage
        accessModes: [ReadWriteOnce]
        resources:
          requests:
            storage: 2Ti
  beSpec:
    configMapInfo:
      configMapName: be-configmap
      resolveKey: be.conf
    replicas: 3
    #limits:
      #cpu: 8
      #memory: 16Gi
    #requests:
      #cpu: 0.5
      #memory: 2Gi
    #image: apache/doris:be-3.0.5
    image: ccr.ccs.tencentyun.com/huanghuanhui/doris:be-3.0.5
    persistentVolumes:
    - mountPath: /opt/apache-doris/be/storage
      name: be-storage
      persistentVolumeClaimSpec:
        storageClassName: nfs-storage
        accessModes: [ReadWriteOnce]
        resources:
          requests:
            storage: 2Ti
EOF
```

````shell
kubectl apply -f ~/k8s-doris-yml/doriscluster.yaml
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

