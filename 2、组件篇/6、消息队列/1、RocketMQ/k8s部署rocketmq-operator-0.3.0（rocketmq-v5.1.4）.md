## k8s部署rocketmq-operator-0.3.0（rocketmq-v5.1.4）

> 多 Master 多 Slave-异步复制模式部署
>
> 版本：rocketmq-v5.1.4
>
> 适合生产环境

## 0、克隆 RocketMQ Operator 项目

```shell
# 版本 rocketmq-operator-0.3.0
git clone -b 0.3.0 https://github.com/apache/rocketmq-operator.git
```

```shell
cd ~/rocketmq-operator
```

## 1、使用官方的Dockerfile制作镜像

### 方式1：在 Harbor 中创建项目（私有仓库）

```shell
curl -u "admin:Moan@2022" -X POST -H "Content-Type: application/json" http://192.168.1.112/api/v2.0/projects -d '{ "project_name": "apacherocketmq", "public": true}'
```

### 方式2：在 Harbor 中创建项目（云镜像仓库）

```shell
腾讯云为例
```

### 制作 RocketMQ Broker Image

```shell
cd ~/rocketmq-operator/images/broker/alpine
```

```shell
cp ~/rocketmq-operator/images/broker/alpine/{Dockerfile,Dockerfile.bak}

cat > ~/rocketmq-operator/images/broker/alpine/Dockerfile << 'EOF'
FROM openjdk:8-alpine

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories && \
    apk add --no-cache bash gettext nmap-ncat openssl busybox-extras

ARG version

# Rocketmq version
ENV ROCKETMQ_VERSION ${version}

# Rocketmq home
ENV ROCKETMQ_HOME  /root/rocketmq/broker

WORKDIR  ${ROCKETMQ_HOME}

# Install
RUN set -eux; \
    apk add --virtual .build-deps curl gnupg unzip; \
    curl https://mirrors.tuna.tsinghua.edu.cn/apache/rocketmq/${ROCKETMQ_VERSION}/rocketmq-all-${ROCKETMQ_VERSION}-bin-release.zip -o rocketmq.zip; \
    unzip rocketmq.zip; \
        mv rocketmq-all*/* . ; \
        rmdir rocketmq-all* ; \
        rm rocketmq.zip ; \
        apk del .build-deps ; \
    rm -rf /var/cache/apk/* ; \
    rm -rf /tmp/*

# Copy customized scripts
COPY runbroker-customize.sh ${ROCKETMQ_HOME}/bin/

# Expose broker ports
EXPOSE 10909 10911 10912

# Override customized scripts for broker
RUN mv ${ROCKETMQ_HOME}/bin/runbroker-customize.sh ${ROCKETMQ_HOME}/bin/runbroker.sh \
 && chmod a+x ${ROCKETMQ_HOME}/bin/runbroker.sh \
 && chmod a+x ${ROCKETMQ_HOME}/bin/mqbroker

# Export Java options
RUN export JAVA_OPT=" -Duser.home=/opt"

# Add ${JAVA_HOME}/lib/ext as java.ext.dirs
RUN sed -i 's/${JAVA_HOME}\/jre\/lib\/ext/${JAVA_HOME}\/jre\/lib\/ext:${JAVA_HOME}\/lib\/ext/' ${ROCKETMQ_HOME}/bin/tools.sh

COPY brokerGenConfig.sh brokerStart.sh ${ROCKETMQ_HOME}/bin/

RUN chmod a+x ${ROCKETMQ_HOME}/bin/brokerGenConfig.sh \
 && chmod a+x ${ROCKETMQ_HOME}/bin/brokerStart.sh

WORKDIR ${ROCKETMQ_HOME}/bin

CMD ["/bin/bash", "./brokerStart.sh"]
EOF
```

```shell
sed -i.bak 's#apacherocketmq#ccr.ccs.tencentyun.com/huanghuanhui#g' build-broker-image.sh
```

```shell
docker login ccr.ccs.tencentyun.com --username=xxxxxxx

xxxxx
```

```shell
./build-broker-image.sh 5.1.4
```

```shell
docker images | grep rocketmq-broker

ccr.ccs.tencentyun.com/huanghuanhui/rocketmq-broker:5.1.4-alpine-operator-0.3.0
```

### 制作 RocketMQ Name Server Image

```shell
cd ~/rocketmq-operator/images/namesrv/alpine
```

```shell
cp ~/rocketmq-operator/images/namesrv/alpine/{Dockerfile,Dockerfile.bak}

cat > ~/rocketmq-operator/images/namesrv/alpine/Dockerfile << 'EOF'
FROM openjdk:8-alpine

RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories && \
    apk add --no-cache bash gettext nmap-ncat openssl busybox-extras

ARG version

# Rocketmq version
ENV ROCKETMQ_VERSION ${version}

# Rocketmq home
ENV ROCKETMQ_HOME  /root/rocketmq/nameserver

WORKDIR  ${ROCKETMQ_HOME}

# Install
RUN set -eux; \
    apk add --virtual .build-deps curl gnupg unzip; \
    curl https://mirrors.tuna.tsinghua.edu.cn/apache/rocketmq/${ROCKETMQ_VERSION}/rocketmq-all-${ROCKETMQ_VERSION}-bin-release.zip -o rocketmq.zip; \
    unzip rocketmq.zip; \
        mv rocketmq-all*/* . ; \
        rmdir rocketmq-all* ; \
        rm rocketmq.zip ; \
        apk del .build-deps ; \
    rm -rf /var/cache/apk/* ; \
    rm -rf /tmp/*

# Copy customized scripts
COPY runserver-customize.sh ${ROCKETMQ_HOME}/bin/

# Expose namesrv port
EXPOSE 9876

# Override customized scripts for namesrv
# Export Java options
# Add ${JAVA_HOME}/lib/ext as java.ext.dirs
RUN mv ${ROCKETMQ_HOME}/bin/runserver-customize.sh ${ROCKETMQ_HOME}/bin/runserver.sh \
 && chmod a+x ${ROCKETMQ_HOME}/bin/runserver.sh \
 && chmod a+x ${ROCKETMQ_HOME}/bin/mqnamesrv \
 && export JAVA_OPT=" -Duser.home=/opt" \
 && sed -i 's/${JAVA_HOME}\/jre\/lib\/ext/${JAVA_HOME}\/jre\/lib\/ext:${JAVA_HOME}\/lib\/ext/' ${ROCKETMQ_HOME}/bin/tools.sh

WORKDIR ${ROCKETMQ_HOME}/bin

CMD ["/bin/bash", "mqnamesrv"]
EOF
```

```shell
# 修改镜像仓库地址为内网地址

sed -i.bak 's#apacherocketmq#ccr.ccs.tencentyun.com/huanghuanhui#g' build-namesrv-image.sh
```

```shell
./build-namesrv-image.sh 5.1.4
```

```shell
docker images | grep rocketmq-nameserver

ccr.ccs.tencentyun.com/huanghuanhui/rocketmq-nameserver:5.1.4-alpine-operator-0.3.0
```

### 制作 RocketMQ Console Image

```shell
docker pull apacherocketmq/rocketmq-console:2.0.0

docker tag apacherocketmq/rocketmq-console:2.0.0 ccr.ccs.tencentyun.com/huanghuanhui/rocketmq-console:2.0.0

docker push ccr.ccs.tencentyun.com/huanghuanhui/rocketmq-console:2.0.0
```

## 2、修改 RocketMQ Operator 部署yml文件

```shell
cd ~/rocketmq-operator

sed -i 'N;8 a \  namespace: rocketmq' deploy/crds/rocketmq.apache.org_brokers.yaml
sed -i 'N;8 a \  namespace: rocketmq' deploy/crds/rocketmq.apache.org_consoles.yaml
sed -i 'N;8 a \  namespace: rocketmq' deploy/crds/rocketmq.apache.org_nameservices.yaml
sed -i 'N;8 a \  namespace: rocketmq' deploy/crds/rocketmq.apache.org_topictransfers.yaml
sed -i 'N;18 a \  namespace: rocketmq' deploy/operator.yaml
sed -i 'N;18 a \  namespace: rocketmq' deploy/role_binding.yaml
sed -i 's/namespace: default/namespace: rocketmq/g' deploy/role_binding.yaml
sed -i 'N;18 a \  namespace: rocketmq' deploy/service_account.yaml
sed -i 'N;20 a \  namespace: rocketmq' deploy/role.yaml
```

```shell
grep -r 'namespace: rocketmq' deploy/*   |grep -n '.*'
```

## 3、修改 RocketMQ 集群部署yml文件

```shell
# 备份
cp example/rocketmq_v1alpha1_rocketmq_cluster.yaml example/rocketmq_v1alpha1_rocketmq_cluster.yaml-bak

# 命名空间
sed -i 's/namespace: default/namespace: rocketmq/g' example/rocketmq_v1alpha1_rocketmq_cluster.yaml

# 替换镜像地址
sed -i 's#apacherocketmq#ccr.ccs.tencentyun.com/huanghuanhui#g' example/rocketmq_v1alpha1_rocketmq_cluster.yaml
sed -i 's/4.5.0/5.1.4/g' example/rocketmq_v1alpha1_rocketmq_cluster.yaml

# 禁用 hostNetwork 模式
sed -i 's/hostNetwork: true/hostNetwork: false/g' example/rocketmq_v1alpha1_rocketmq_cluster.yaml 
sed -i 's/dnsPolicy: ClusterFirstWithHostNet/dnsPolicy: ClusterFirst/g' example/rocketmq_v1alpha1_rocketmq_cluster.yaml

# pvc
sed -i 's/storageClassName: rocketmq-storage/storageClassName: nfs-storage/g' example/rocketmq_v1alpha1_rocketmq_cluster.yaml
sed -i 's/storageMode: EmptyDir/storageMode: StorageClass/g' example/rocketmq_v1alpha1_rocketmq_cluster.yaml
sed -i 's/storage: 8Gi/storage: 2Ti/g' example/rocketmq_v1alpha1_rocketmq_cluster.yaml
sed -i 's/storage: 1Gi/storage: 2Ti/g' example/rocketmq_v1alpha1_rocketmq_cluster.yaml

# 修改 nameServers 为域名的形式
sed -i 's/nameServers: ""/nameServers: "name-server-service.rocketmq:9876"/g' example/rocketmq_v1alpha1_rocketmq_cluster.yaml

# cpu
sed -i 's/cpu: "500m"/cpu: "1"/g' example/rocketmq_v1alpha1_rocketmq_cluster.yaml
sed -i 's/cpu: "250m"/cpu: "1"/g' example/rocketmq_v1alpha1_rocketmq_cluster.yaml

# memory
sed -i 's/memory: "1024Mi"/memory: "2Gi"/g' example/rocketmq_v1alpha1_rocketmq_cluster.yaml
sed -i 's/memory: "512Mi"/memory: "2Gi"/g' example/rocketmq_v1alpha1_rocketmq_cluster.yaml

# 部署2个broker
sed -i '41s/1/2/' example/rocketmq_v1alpha1_rocketmq_cluster.yaml
```

```shell
# 命名空间
sed -i 'N;18 a \  namespace: rocketmq' example/rocketmq_v1alpha1_cluster_service.yaml

# NodePort
sed -i 's/nodePort: 30000/nodePort: 31080/g' example/rocketmq_v1alpha1_cluster_service.yaml

# 打开注释
sed -i '32,46s/^#//g' example/rocketmq_v1alpha1_cluster_service.yaml
sed -i 's/namespace: default/namespace: rocketmq/g' example/rocketmq_v1alpha1_cluster_service.yaml
sed -i 's/nodePort: 30001/nodePort: 31081/g' example/rocketmq_v1alpha1_cluster_service.yaml
```

### 部署 RocketMQ Operator (手动)

```shell
kubectl create -f deploy/crds/rocketmq.apache.org_brokers.yaml
kubectl create -f deploy/crds/rocketmq.apache.org_nameservices.yaml
kubectl create -f deploy/crds/rocketmq.apache.org_consoles.yaml
kubectl create -f deploy/crds/rocketmq.apache.org_topictransfers.yaml
kubectl create -f deploy/service_account.yaml
kubectl create -f deploy/role.yaml
kubectl create -f deploy/role_binding.yaml
kubectl create -f deploy/operator.yaml
```

```shell
kubectl get crd | grep rocketmq.apache.org

kubectl get po -n rocketmq
```

### 部署 RocketMQ 集群

```shell
kubectl apply -f example/rocketmq_v1alpha1_cluster_service.yaml
```

```shell
kubectl apply -f example/rocketmq_v1alpha1_rocketmq_cluster.yaml
```

```shell
kubectl patch statefulset name-service -p '{"spec": {"template": {"spec": {"nodeSelector": {"kubernetes.io/hostname": "k8s-node1"}}}}}'


kubectl rollout restart statefulset name-service

kubectl delete pod name-service-0 --force
```

```shell
[root@master ~/rocketmq-operator]# kubectl get po -n rocketmq
NAME                                 READY   STATUS    RESTARTS   AGE
broker-0-master-0                    1/1     Running   0          47s
broker-0-replica-1-0                 1/1     Running   0          47s
broker-1-master-0                    1/1     Running   0          47s
broker-1-replica-1-0                 1/1     Running   0          47s
console-dfbc6445d-w9k75              1/1     Running   0          47s
name-service-0                       1/1     Running   0          47s
rocketmq-operator-79bd8cf9dd-b55zt   1/1     Running   0          42m

[root@master ~/rocketmq-operator]# kubectl get svc -n rocketmq
NAME                  TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
console-service       NodePort   10.97.145.235   <none>        8080:31080/TCP   39m
name-server-service   NodePort   10.108.83.191   <none>        9876:31081/TCP   39m
```

###### rocketmq-dashboard-Ingress

```shell
cat > ~/rocketmq-operator/rocketmq-dashboard-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rocketmq-dashboard-ingress
  namespace: rocketmq
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: rocketmq-dashboard.huanghuanhui.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: console-service
            port:
              number: 8080
  tls:
  - hosts:
    - rocketmq-dashboard.huanghuanhui.cloud
    secretName: rocketmq-console-ingress-tls
EOF
```

```shell
kubectl create secret -n rocketmq \
tls rocketmq-console-ingress-tls \
--key=/root/ssl/huanghuanhui.cloud.key \
--cert=/root/ssl/huanghuanhui.cloud.crt
```

```shell
kubectl apply -f ~/rocketmq-operator/rocketmq-dashboard-Ingress.yml
```

> dashboard 访问地址：https://rocketmq-dashboard.huanghuanhui.cloud/
>
> 代码连接地址：name-server-service.rocketmq:9876（集群内部连接地址）
