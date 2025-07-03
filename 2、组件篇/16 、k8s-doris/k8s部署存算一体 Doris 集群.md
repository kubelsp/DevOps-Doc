### k8s部署存算一体 Doris 集群

> https://github.com/apache/doris-operator
>
> k8s版本：v1.33.2
>
> k8s-doris版本：25.5.2（doris-3.0.5）

````shell
kubectl label nodes k8s-doris-10.1.1.201 doris=doris
kubectl label nodes k8s-doris-10.1.1.202 doris=doris
kubectl label nodes k8s-doris-10.1.1.203 doris=doris
````

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
cd ~/k8s-doris-yml && wget https://github.com/apache/doris-operator/raw/refs/tags/25.5.2/config/crd/bases/crds.yaml
````

```shell
kubectl create -f ~/k8s-doris-yml/crds.yaml
```

2、部署 Doris Operator

````shell
cd ~/k8s-doris-yml && wget https://github.com/apache/doris-operator/raw/refs/tags/25.5.2/config/operator/operator.yaml
````

```shell
sed -i 's|apache/doris:operator-25.5.2|ccr.ccs.tencentyun.com/huanghuanhui/doris:operator-25.5.2|g' ~/k8s-doris-yml/operator.yaml
```

````shell
kubectl apply -f ~/k8s-doris-yml/operator.yaml
````

3、部署 doris 集群

````shell
cat > ~/k8s-doris-yml/cm.yml << 'EOF'
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: fe-cm
  namespace: doris
  labels:
    app.kubernetes.io/component: fe
data:
  fe.conf: |
    CUR_DATE=`date +%Y%m%d-%H%M%S`

    # the output dir of stderr and stdout
    LOG_DIR = ${DORIS_HOME}/log

    JAVA_OPTS="-Djavax.security.auth.useSubjectCredsOnly=false -Xss4m -Xmx8192m -XX:+UseMembar -XX:SurvivorRatio=8 -XX:MaxTenuringThreshold=7 -XX:+PrintGCDateStamps -XX:+PrintGCDetails -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:+CMSClassUnloadingEnabled -XX:-CMSParallelRemarkEnabled -XX:CMSInitiatingOccupancyFraction=80 -XX:SoftRefLRUPolicyMSPerMB=0 -Xloggc:$DORIS_HOME/log/fe.gc.log.$CUR_DATE"

    # For jdk 9+, this JAVA_OPTS will be used as default JVM options
    JAVA_OPTS_FOR_JDK_9="-Djavax.security.auth.useSubjectCredsOnly=false -Xss4m -Xmx8192m -XX:SurvivorRatio=8 -XX:MaxTenuringThreshold=7 -XX:+CMSClassUnloadingEnabled -XX:-CMSParallelRemarkEnabled -XX:CMSInitiatingOccupancyFraction=80 -XX:SoftRefLRUPolicyMSPerMB=0 -Xlog:gc*:$DORIS_HOME/log/fe.gc.log.$CUR_DATE:time"

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
    enable_fqdn_mode = true
    # 区分大小写（默认）
    lower_case_table_names=0
    qe_max_connection= 102400
    max_connection_scheduler_threads_num=409600
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: be-cm
  namespace: doris
  labels:
    app.kubernetes.io/component: be
data:
  be.conf: |
    CUR_DATE=`date +%Y%m%d-%H%M%S`

    PPROF_TMPDIR="$DORIS_HOME/log/"

    JAVA_OPTS="-Xmx1024m -DlogPath=$DORIS_HOME/log/jni.log -Xloggc:$DORIS_HOME/log/be.gc.log.$CUR_DATE -Djavax.security.auth.useSubjectCredsOnly=false -Dsun.java.command=DorisBE -XX:-CriticalJNINatives -DJDBC_MIN_POOL=1 -DJDBC_MAX_POOL=100 -DJDBC_MAX_IDLE_TIME=300000 -DJDBC_MAX_WAIT_TIME=5000"

    # For jdk 9+, this JAVA_OPTS will be used as default JVM options
    JAVA_OPTS_FOR_JDK_9="-Xmx1024m -DlogPath=$DORIS_HOME/log/jni.log -Xlog:gc:$DORIS_HOME/log/be.gc.log.$CUR_DATE -Djavax.security.auth.useSubjectCredsOnly=false -Dsun.java.command=DorisBE -XX:-CriticalJNINatives -DJDBC_MIN_POOL=1 -DJDBC_MAX_POOL=100 -DJDBC_MAX_IDLE_TIME=300000 -DJDBC_MAX_WAIT_TIME=5000"

    # since 1.2, the JAVA_HOME need to be set to run BE process.
    # JAVA_HOME=/path/to/jdk/

    # https://github.com/apache/doris/blob/master/docs/zh-CN/community/developer-guide/debug-tool.md#jemalloc-heap-profile
    # https://jemalloc.net/jemalloc.3.html
    JEMALLOC_CONF="percpu_arena:percpu,background_thread:true,metadata_thp:auto,muzzy_decay_ms:15000,dirty_decay_ms:15000,oversize_threshold:0,lg_tcache_max:20,prof:false,lg_prof_interval:32,lg_prof_sample:19,prof_gdump:false,prof_accum:false,prof_leak:false,prof_final:false"
    JEMALLOC_PROF_PRFIX=""

    # INFO, WARNING, ERROR, FATAL
    sys_log_level = INFO

    # ports for admin, web, heartbeat service
    be_port = 9060
    webserver_port = 8040
    heartbeat_service_port = 9050
    brpc_port = 8060
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
  name: doris
  namespace: doris
spec:
  feSpec:
    replicas: 3
    service:
      type: NodePort
      servicePorts:
      - nodePort: 30830
        targetPort: 8030
      - nodePort: 30910
        targetPort: 9010
      - nodePort: 30920
        targetPort: 9020
      - nodePort: 30930
        targetPort: 9030
    configMapInfo:
      configMapName: fe-conf
      resolveKey: fe.conf
    nodeSelector:
      doris: doris
    tolerations:
    - effect: NoSchedule
      key: doris
      operator: Equal
      value: doris
    #limits:
      #cpu: 8
      #memory: 16Gi
    #requests:
      #cpu: 8
      #memory: 16Gi
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
            storage: 10Ti
  beSpec:
    replicas: 3
    service:
      type: NodePort
      servicePorts:
      - nodePort: 30840
        targetPort: 8040
      - nodePort: 30860
        targetPort: 8060
      - nodePort: 30950
        targetPort: 9050
      - nodePort: 30960
        targetPort: 9060
    configMapInfo:
      configMapName: be-conf
      resolveKey: be.conf
    nodeSelector:
      doris: doris
    tolerations:
    - effect: NoSchedule
      key: doris
      operator: Equal
      value: doris
    #limits:
      #cpu: 16
      #memory: 32Gi
    #requests:
      #cpu: 16
      #memory: 32Gi
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
            storage: 20Ti
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
kubectl -n doris exec -it mysql-client-0 -- mysql -h doris-fe-internal -P 9030 -u root -p
````

配置管理用户名和密码

````shell
# 创建doris用户并设置为管理员
CREATE USER 'doris' IDENTIFIED BY 't4RQWtFRmFHyCCLb';

GRANT 'admin' TO 'doris'@'%';
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

> 代码连接地址：doris-fe-internal.doris:9030
>
> NodePort 访问地址：ip（192.168.1.10） + 端口（30930）
>
> 默认管理员1用户密码：root、 空
>
> 默认管理员2用户密码：admin、 空
>
> 默认管理员3用户密码：doris、 t4RQWtFRmFHyCCLb

