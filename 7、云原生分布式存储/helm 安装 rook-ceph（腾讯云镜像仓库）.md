## 云原生分布式存储

### 1、helm 安装 rook-ceph（腾讯云镜像仓库）

> 在 Kubernetes 集群中通过 Rook 部署 ceph 分布式存储集群
>
> https://github.com/rook/rook

> Prerequisites
>
> - Kubernetes 1.22+
> - Helm 3.x

> - 一主三从（最少）
> - 所有 k8s 节点另外准备一块磁盘（裸盘）（/dev/sdb）

1、 rook-ceph-operator

```shell
helm repo add rook-release https://charts.rook.io/release

helm repo update

helm search repo rook-release/rook-ceph

helm pull rook-release/rook-ceph --version v1.12.2 --untar
cat > ~/rook-ceph/values-prod.yml << 'EOF'
image:
  repository: ccr.ccs.tencentyun.com/huanghuanhui/rook-ceph
  tag: ceph-v1.12.2
  pullPolicy: IfNotPresent

resources:
  limits:
    cpu: "2"
    memory: "4Gi"
  requests:
    cpu: "1"
    memory: "2Gi"

csi:
  cephcsi:
    # @default -- `quay.io/cephcsi/cephcsi:v3.9.0`
    image: ccr.ccs.tencentyun.com/huanghuanhui/rook-ceph:cephcsi-v3.9.0

  registrar:
    # @default -- `registry.k8s.io/sig-storage/csi-node-driver-registrar:v2.8.0`
    image: ccr.ccs.tencentyun.com/huanghuanhui/rook-ceph:csi-node-driver-registrar-v2.8.0

  provisioner:
    # @default -- `registry.k8s.io/sig-storage/csi-provisioner:v3.5.0`
    image: ccr.ccs.tencentyun.com/huanghuanhui/rook-ceph:csi-provisioner-v3.5.0

  snapshotter:
    # @default -- `registry.k8s.io/sig-storage/csi-snapshotter:v6.2.2`
    image: ccr.ccs.tencentyun.com/huanghuanhui/rook-ceph:csi-snapshotter-v6.2.2

  attacher:
    # @default -- `registry.k8s.io/sig-storage/csi-attacher:v4.3.0`
    image: ccr.ccs.tencentyun.com/huanghuanhui/rook-ceph:csi-attacher-v4.3.0

  resizer:
    # @default -- `registry.k8s.io/sig-storage/csi-resizer:v1.8.0`
    image: ccr.ccs.tencentyun.com/huanghuanhui/rook-ceph:csi-resizer-v1.8.0

  # -- Image pull policy
  imagePullPolicy: IfNotPresent

EOF
cd ~/rook-ceph

helm upgrade --install --create-namespace --namespace rook-ceph rook-ceph -f ./values-prod.yml .
```

2、rook-ceph-cluster

```shell
helm repo add rook-release https://charts.rook.io/release

helm repo update

helm search repo rook-release/rook-ceph-cluster

helm pull rook-release/rook-ceph-cluster --version v1.12.2 --untar
cat > ~/rook-ceph-cluster/values-prod.yml << 'EOF'

toolbox:
  enabled: true
  image: ccr.ccs.tencentyun.com/huanghuanhui/rook-ceph:ceph-ceph-v17.2.6
cephClusterSpec:
  cephVersion:
    image: ccr.ccs.tencentyun.com/huanghuanhui/rook-ceph:ceph-ceph-v17.2.6

EOF
cd ~/rook-ceph-cluster

helm upgrade --install --create-namespace --namespace rook-ceph rook-ceph-cluster --set operatorNamespace=rook-ceph -f ./values-prod.yml .
kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') bash
```

3、NodePort（nodeport方式访问）

```shell
kubectl expose pod $(kubectl get pod -n rook-ceph | grep rook-ceph-mgr-a | awk '{print $1}') --type=NodePort --name=rook-ceph-mgr-a-service --port=8443

# kubectl delete service rook-ceph-mgr-a-service
# 访问地址：https://ip+端口
```

密码

```shell
kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 --decode && echo
```

4、rook-ceph-mgr-dashboard-Ingress（ingress域名方式访问）

```shell
cat > ~/rook-ceph/rook-ceph-mgr-dashboard-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rook-ceph-mgr-dashboard-ingress
  namespace: rook-ceph
  annotations:
    kubernetes.io/ingress.class: "nginx"
    kubernetes.io/tls-acme: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    nginx.ingress.kubernetes.io/server-snippet: |
      proxy_ssl_verify off;
spec:
  rules:
    - host: rook-ceph.huanghuanhui.cloud
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: rook-ceph-mgr-dashboard
                port:
                  name: https-dashboard
  tls:
  - hosts:
    - rook-ceph.huanghuanhui.cloud
    secretName: rook-ceph-mgr-dashboard-ingress-tls
EOF
kubectl create secret -n rook-ceph \
tls rook-ceph-mgr-dashboard-ingress-tls \
--key=/root/ssl/huanghuanhui.cloud_nginx/huanghuanhui.cloud.key \
--cert=/root/ssl/huanghuanhui.cloud_nginx/huanghuanhui.cloud_bundle.crt
 kubectl apply -f ~/rook-ceph/rook-ceph-mgr-dashboard-Ingress.yml
```

密码

```shell
kubectl -n rook-ceph get secret rook-ceph-dashboard-password -o jsonpath="{['data']['password']}" | base64 --decode && echo
```

> 访问地址：rook-ceph.huanghuanhui.cloud
>
> 用户密码：admin、（）

===

```shell
[root@k8s-master ~]# kubectl get sc
NAME                   PROVISIONER                                   RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
ceph-block (default)   rook-ceph.rbd.csi.ceph.com                    Delete          Immediate           true                   5h38m
ceph-bucket            rook-ceph.ceph.rook.io/bucket                 Delete          Immediate           false                  5h38m
ceph-filesystem        rook-ceph.cephfs.csi.ceph.com                 Delete          Immediate           true                   5h38m
```

> helm 安装 rook-ceph 会自动安装3个sc，推荐使用：ceph-block

```shell
# https://github.com/rook/rook/issues/12758
ceph crash prune 3 # 保留最近3天的崩溃日志，并删除3天前的以前的日志
ceph crash prune 0

ceph crash ls
[root@k8s-master ~/rook-ceph-cluster]# pod
NAME                                                  READY   STATUS      RESTARTS   AGE
csi-cephfsplugin-h6hrh                                2/2     Running     0          18m
csi-cephfsplugin-j5h6h                                2/2     Running     0          18m
csi-cephfsplugin-lhtt7                                2/2     Running     0          18m
csi-cephfsplugin-provisioner-5c4cddd6b-ghpv2          5/5     Running     0          18m
csi-cephfsplugin-provisioner-5c4cddd6b-zknlk          5/5     Running     0          18m
csi-rbdplugin-7mgjv                                   2/2     Running     0          18m
csi-rbdplugin-pksw6                                   2/2     Running     0          18m
csi-rbdplugin-provisioner-5c6b576c5d-l47gs            5/5     Running     0          18m
csi-rbdplugin-provisioner-5c6b576c5d-sgtqc            5/5     Running     0          18m
csi-rbdplugin-xcjn8                                   2/2     Running     0          16s
rook-ceph-crashcollector-k8s-node1-5dc5b587fd-zq5jg   1/1     Running     0          15m
rook-ceph-crashcollector-k8s-node2-7f457d645-2h6lf    1/1     Running     0          14m
rook-ceph-crashcollector-k8s-node3-69d797bd46-bm8vc   1/1     Running     0          14m
rook-ceph-mds-ceph-filesystem-a-7df575df4d-w5zkt      2/2     Running     0          14m
rook-ceph-mds-ceph-filesystem-b-67896bc489-qxp44      2/2     Running     0          14m
rook-ceph-mgr-a-696c6b65f7-k4nng                      3/3     Running     0          15m
rook-ceph-mgr-b-765ff4f954-h7fpw                      3/3     Running     0          15m
rook-ceph-mon-a-6fcf8f985b-wg6zv                      2/2     Running     0          18m
rook-ceph-mon-b-8d768bb94-fdb9r                       2/2     Running     0          15m
rook-ceph-mon-c-784d9fc768-z2hs5                      2/2     Running     0          15m
rook-ceph-operator-86888fdb75-7h4kl                   1/1     Running     0          2m17s
rook-ceph-osd-0-85d4cf449-mq8pz                       2/2     Running     0          14m
rook-ceph-osd-1-bfdff5dd-5m8lw                        2/2     Running     0          14m
rook-ceph-osd-2-7d4f96f5f5-7k62p                      2/2     Running     0          14m
rook-ceph-osd-prepare-k8s-node1-t9r2r                 0/1     Completed   0          102s
rook-ceph-osd-prepare-k8s-node2-tr926                 0/1     Completed   0          99s
rook-ceph-osd-prepare-k8s-node3-fsdfp                 0/1     Completed   0          96s
rook-ceph-rgw-ceph-objectstore-a-5d9fdbbbff-sntfb     2/2     Running     0          13m
rook-ceph-tools-c9b9dd85f-b9g5s                       1/1     Running     0          21m
[root@k8s-master ~/rook-ceph-cluster]# svc
NAME                             TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)             AGE
rook-ceph-mgr                    ClusterIP   10.103.189.158   <none>        9283/TCP            15m
rook-ceph-mgr-a-service          NodePort    10.106.35.196    <none>        8443:31397/TCP      5m49s
rook-ceph-mgr-dashboard          ClusterIP   10.105.214.130   <none>        8443/TCP            15m
rook-ceph-mon-a                  ClusterIP   10.102.21.160    <none>        6789/TCP,3300/TCP   18m
rook-ceph-mon-b                  ClusterIP   10.101.131.168   <none>        6789/TCP,3300/TCP   15m
rook-ceph-mon-c                  ClusterIP   10.108.229.248   <none>        6789/TCP,3300/TCP   15m
rook-ceph-rgw-ceph-objectstore   ClusterIP   10.105.52.243    <none>        80/TCP              14m
[root@k8s-master ~/rook-ceph-cluster]# sc
NAME                   PROVISIONER                                   RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION   AGE
ceph-block (default)   rook-ceph.rbd.csi.ceph.com                    Delete          Immediate           true                   21m
ceph-bucket            rook-ceph.ceph.rook.io/bucket                 Delete          Immediate           false                  21m
ceph-filesystem        rook-ceph.cephfs.csi.ceph.com                 Delete          Immediate           true                   21m
nfs-storage            k8s-sigs.io/nfs-subdir-external-provisioner   Delete          Immediate           false                  40d
[root@k8s-master ~/rook-ceph-cluster]#
```

