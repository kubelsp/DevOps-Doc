## 1、helm 安装 karmada（2024-01-29）

> k8s版本：k8s-1.29.1
>
> 器运行时版本：containerd-1.6.27
>
> 网络插件：calico-v3.27.0
>
> istio版本：istio-1.20.2
>
> karmada版本：v1.8.0
>
> 这里准备四个 k8s 集群（假设四个集群分别部署运行在北上广深区域）
>
> 前提条件：四个集群的API-SERVER（kube-apiserver）需要互通！！！
>
> 每一个集群的 istio 都有独立的控制平面、独立的网络
>
> 所有操作都在 k8s-master-beijing 集群上（管理者）
>
> https://github.com/karmada-io/karmada
>
> https://github.com/karmada-io/karmada/tree/master/charts/karmada

###### 方式1：下载chart（推荐）

```shell
helm repo add karmada-charts https://raw.githubusercontent.com/karmada-io/karmada/master/charts

helm search repo karmada

helm pull karmada-charts/karmada --version v1.8.0 --untar
```

```shell
cat > ~/karmada/values-prod.yaml << 'EOF'
cfssl:
  image:
    registry: ccr.ccs.tencentyun.com/huanghuanhui
    repository: cfssl
    tag: v1.6.4
    pullPolicy: IfNotPresent

certs:
  mode: auto
  auto:
    expiry: 43800h
    hosts: [
      "kubernetes.default.svc",
      "*.etcd.karmada-system.svc.cluster.local",
      "*.karmada-system.svc.cluster.local",
      "*.karmada-system.svc",
      "*.karmada-system.svc",
      "localhost",
      "127.0.0.1",
      "192.168.1.201"
    ]

apiServer:
  image:
    registry: registry.aliyuncs.com/google_containers
    repository: kube-apiserver
    tag: "v1.29.1"
    pullPolicy: IfNotPresent
  hostNetwork: false
  serviceType: NodePort
  nodePort: 32443

kubeControllerManager:
  image:
    registry: registry.aliyuncs.com/google_containers
    repository: kube-controller-manager
    tag: "v1.29.1"

etcd:
  internal:
    image:
      registry: registry.aliyuncs.com/google_containers
      repository: etcd
      tag: "3.5.10-0"
      pullPolicy: IfNotPresent

    tolerations:
    - key: "node-role.kubernetes.io/k8s-master-beijing"
      operator: "Equal"
      effect: "NoSchedule"

    nodeSelector:
      kubernetes.io/hostname: "k8s-master-beijing"

metricsAdapter:
  image:
    pullPolicy: IfNotPresent
EOF
```

```shell
kubectl create ns karmada-system

helm upgrade --install --namespace karmada-system karmada -f ./values-prod.yaml .
```

###### 方式2：直接命令行（ 不推荐）

```shell
helm --namespace karmada-system upgrade -i karmada karmada-charts/karmada --version=v1.8.0 --create-namespace \
  --set cfssl.image.registry=ccr.ccs.tencentyun.com/huanghuanhui \
  --set cfssl.image.repository=cfssl \
  --set cfssl.image.tag=v1.6.4 \
  --set etcd.internal.image.registry=registry.aliyuncs.com/google_containers \
  --set etcd.internal.image.tag=3.5.10-0 \
  --set etcd.internal.nodeSelector=kubernetes.io/hostname=k8s-master-beijing \
  --set etcd.internal.tolerations[0].key=node-role.kubernetes.io/k8s-master-beijing \
  --set etcd.internal.tolerations[0].operator=Exists \
  --set etcd.internal.tolerations[0].effect=NoSchedule \
  --set apiServer.image.registry=registry.aliyuncs.com/google_containers \
  --set apiServer.image.tag=v1.29.1 \
  --set kubeControllerManager.image.registry=registry.aliyuncs.com/google_containers \
  --set kubeControllerManager.image.tag=v1.29.1 \
  --set apiServer.hostNetwork=false \
  --set apiServer.serviceType=NodePort \
  --set apiServer.nodePort=32443 \
  --set certs.auto.hosts[0]="kubernetes.default.svc" \
  --set certs.auto.hosts[1]="*.etcd.karmada-system.svc.cluster.local" \
  --set certs.auto.hosts[2]="*.karmada-system.svc.cluster.local" \
  --set certs.auto.hosts[3]="*.karmada-system.svc" \
  --set certs.auto.hosts[4]="localhost" \
  --set certs.auto.hosts[5]="127.0.0.1" \
  --set certs.auto.hosts[6]="192.168.1.201"
```

> 镜像使用腾讯云镜像仓库（公开）（dockerhub同步过来的）
>
> etcd固定k8s-master-beijing上

###### 卸载

```shell
helm uninstall karmada -n karmada-system

kubectl delete ns karmada-system

rm -rf /var/lib/karmada-system/karmada-etcd
```

```shell
kubectl get crd -o name | grep karmada.io | xargs kubectl delete

kubectl get crd | grep karmada.io
```

```shell
kubectl get secret karmada-kubeconfig \
 -n karmada-system \
 -o jsonpath={.data.kubeconfig} | base64 -d > ~/karmada-config

sed -i '/https/s/\(https.*\)/https:\/\/192.168.1.201:32443/g' ~/karmada-config

# 使用kubectl加上karmada的config文件操作karmada集群（直接使用karmadactl命令还是有点区别的）
[root@k8s-master-beijing ~]# kubectl get clusters --kubeconfig=/root/karmada-config
No resources found
```

```shell
cd && wget https://github.com/karmada-io/karmada/releases/download/v1.8.0/karmadactl-linux-amd64.tgz

tar xf ~/karmadactl-linux-amd64.tgz && mv ~/karmadactl /usr/local/sbin/
```

```shell
# 临时
alias karmadactl='karmadactl --kubeconfig=/root/karmada-config'
unalias karmadactl
alias

# 永久
cat >> ~/.bashrc << 'EOF'
alias karmadactl='karmadactl --kubeconfig=/root/karmada-config'
EOF
```

###### 添加其他集群的master节点到karmada上进行管理

```shell
mkdir -p ~/kubeconfig
```

```shell
scp k8s-master-beijing:~/.kube/config ~/kubeconfig/k8s-master-beijing-kubeconfig
scp k8s-master-shanghai:~/.kube/config ~/kubeconfig/k8s-master-shanghai-kubeconfig
scp k8s-master-guangzhou:~/.kube/config ~/kubeconfig/k8s-master-guangzhou-kubeconfig
scp k8s-master-shenzhen:~/.kube/config ~/kubeconfig/k8s-master-shenzhen-kubeconfig
```

```shell
karmadactl join k8s-master-beijing --kubeconfig=karmada-config --cluster-kubeconfig=/root/kubeconfig/k8s-master-beijing-kubeconfig

karmadactl join k8s-master-shanghai --kubeconfig=karmada-config --cluster-kubeconfig=/root/kubeconfig/k8s-master-shanghai-kubeconfig

karmadactl join k8s-master-guangzhou --kubeconfig=karmada-config --cluster-kubeconfig=/root/kubeconfig/k8s-master-guangzhou-kubeconfig

karmadactl join k8s-master-shenzhen --kubeconfig=karmada-config --cluster-kubeconfig=/root/kubeconfig/k8s-master-shenzhen-kubeconfig
```

```shell
kubectl get clusters --kubeconfig=/root/karmada-config
```

```shell
# 卸载
karmadactl unjoin k8s-master-beijing --kubeconfig=karmada-config

karmadactl unjoin k8s-master-shanghai --kubeconfig=karmada-config

karmadactl unjoin k8s-master-guangzhou --kubeconfig=karmada-config

karmadactl unjoin k8s-master-shenzhen --kubeconfig=karmada-config
```

