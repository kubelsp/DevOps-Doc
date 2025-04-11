### 3、ingress-nginx

helm安装 ingress-nginx（k8s-master边缘节点）

> master（ingress-nginx边缘节点）
>
> chart version：4.11.1  （k8s：1.30、1.29、1.28、1.27、1.26）
>
> k8s版本：k8s-v1.30.3

https://github.com/kubernetes/ingress-nginx


```powershell
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx

helm repo update

helm search repo ingress-nginx/ingress-nginx

helm pull ingress-nginx/ingress-nginx --version 4.11.1 --untar
```

`方式1：DaemonSet + HostNetwork + nodeSelector`（后面的课程会使用这个方式，简单方便）

```powershell
cat > ~/ingress-nginx/values-prod.yaml << 'EOF'
controller:
  name: controller
  image:
    registry: ccr.ccs.tencentyun.com/huanghuanhui
    image: ingress-nginx
    tag: "v1.11.1"
    digest:
    pullPolicy: IfNotPresent

  dnsPolicy: ClusterFirstWithHostNet

  hostNetwork: true

  publishService:  # hostNetwork 模式下设置为false，通过节点IP地址上报ingress status数据
    enabled: false

  metrics:
    enabled: true

  kind: DaemonSet

  tolerations:   # kubeadm 安装的集群默认情况下 k8s-master 是有污点，需要容忍这个污点才可以部署
  - key: "node-role.kubernetes.io/k8s-master"
    operator: "Equal"
    effect: "NoSchedule"

  nodeSelector:   # 固定到k8s-master节点(自己master啥名字就写啥)
    kubernetes.io/hostname: "k8s-master"

  service:  # HostNetwork 模式不需要创建service
    enabled: false

  admissionWebhooks: # 强烈建议开启 admission webhook
    enabled: true
    patch:
      enabled: true
      image:
        registry: ccr.ccs.tencentyun.com/huanghuanhui
        image: ingress-nginx
        tag: kube-webhook-certgen-v1.4.1
        digest:
        pullPolicy: IfNotPresent

defaultBackend:
  enabled: true
  name: defaultbackend
  image:
    registry: ccr.ccs.tencentyun.com/huanghuanhui
    image: ingress-nginx
    tag: "defaultbackend-amd64-1.5"
    digest:
    pullPolicy: IfNotPresent
EOF
```

```powershell
kubectl create ns ingress-nginx

helm upgrade --install --namespace ingress-nginx ingress-nginx -f ./values-prod.yaml .
```

`方式2：MetalLB + Deployment + LoadBalancer（多副本、高可用）`

```shell
cat > ~/ingress-nginx/values-prod.yaml << 'EOF'
controller:
  name: controller
  image:
    registry: ccr.ccs.tencentyun.com/huanghuanhui
    image: ingress-nginx
    tag: "v1.11.1"
    digest:
    pullPolicy: IfNotPresent

  ingressClass: nginx
  ingressClassResource:
    name: nginx
    controllerValue: k8s.io/ingress-nginx

  metrics:
    enabled: true

  kind: Deployment
  replicaCount: 3  # 设置副本数为 3

  affinity: # 设置软策略
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app
              operator: In
              values:
              - ingress-nginx
          topologyKey: kubernetes.io/hostname
        weight: 100

  admissionWebhooks: # 强烈建议开启 admission webhook
    enabled: true
    patch:
      enabled: true
      image:
        registry: ccr.ccs.tencentyun.com/huanghuanhui
        image: ingress-nginx
        tag: kube-webhook-certgen-v1.4.1
        digest:
        pullPolicy: IfNotPresent

defaultBackend:
  enabled: true
  name: defaultbackend
  image:
    registry: ccr.ccs.tencentyun.com/huanghuanhui
    image: ingress-nginx
    tag: "defaultbackend-amd64-1.5"
    digest:
    pullPolicy: IfNotPresent
EOF
```

```shell
kubectl create ns ingress-nginx

helm upgrade --install --namespace ingress-nginx ingress-nginx -f ./values-prod.yaml .
```

卸载

```shell
[root@k8s-master ~/ingress-nginx]# helm delete ingress-nginx -n ingress-nginx

[root@k8s-master ~/ingress-nginx]# kubectl delete ns ingress-nginx
```

