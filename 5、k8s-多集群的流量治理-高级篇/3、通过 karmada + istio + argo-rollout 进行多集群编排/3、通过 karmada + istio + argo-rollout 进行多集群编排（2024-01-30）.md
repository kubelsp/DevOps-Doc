## 通过 karmada + istio + argo-rollout 进行多集群编排（2024-01-30）

### k8s发布方案

> `（金丝雀发布）（渐进式交付）`
>
> `单集群：`
>
> 发布方案 1：`Deployment + Ingress`
>
> 发布方案 2：`Argo-Rollout + Ingress`
>
> 发布方案 3：`Argo-Rollout + Istio `
>
> `多集群`
>
> 发布方案 1：`Karmada + Deployment + Ingress`
>
> 发布方案 2：`Karmada + Argo-Rollout + Ingress`
>
> 发布方案 3：`Karmada + Argo-Rollout + Istio `

### 后端发布方案：

> 四个集群，每个集群都部署 Rollout、Services

```shell
mkdir -p ~/helloworld-rollout-yml
```

```shell
export k8s_master_beijing=k8s-master-beijing@kubernetes
export k8s_master_shanghai=k8s-master-shanghai@kubernetes
export k8s_master_guangzhou=k8s-master-guangzhou@kubernetes
export k8s_master_shenzhen=k8s-master-shenzhen@kubernetes
```

```shell
kubectl create --context="${k8s_master_beijing}" namespace helloworld-rollout

kubectl create --context="${k8s_master_shanghai}" namespace helloworld-rollout

kubectl create --context="${k8s_master_guangzhou}" namespace helloworld-rollout

kubectl create --context="${k8s_master_shenzhen}" namespace helloworld-rollout
```

```shell
kubectl label --context="${k8s_master_beijing}" namespace helloworld-rollout \
    istio-injection=enabled

kubectl label --context="${k8s_master_shanghai}" namespace helloworld-rollout \
    istio-injection=enabled
    
kubectl label --context="${k8s_master_guangzhou}" namespace helloworld-rollout \
    istio-injection=enabled

kubectl label --context="${k8s_master_shenzhen}" namespace helloworld-rollout \
    istio-injection=enabled
```

```shell
cat > helloworld-stable-rollout.yml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: helloworld-stable
  namespace: helloworld-rollout
spec:
  replicas: 4 # 副本数
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {} # 人工卡点
      - setWeight: 40
      - pause: {duration: 10}
      - setWeight: 60
      - pause: {duration: 10}
      - setWeight: 80
      - pause: {duration: 10}
      - setWeight: 100
      - pause: {} # 人工卡点
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: helloworld
  template:
    metadata:
      labels:
        app: helloworld
    spec:
      containers:
      - name: helloworld
        image: ccr.ccs.tencentyun.com/huanghuanhui/helloworld:stable
        imagePullPolicy: IfNotPresent
        ports:
        - name: http
          containerPort: 80
          protocol: TCP
EOF
```

```shell
cat > helloworld-stable-svc.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: helloworld
  namespace: helloworld-rollout
  labels:
    app: helloworld
    service: helloworld
spec:
  ports:
  - port: 80
    name: http
  selector:
    app: helloworld
EOF
```

```shell
cat > helloworld-stable-policy.yml << 'EOF'
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
 name: helloworld-stable-propagation
 namespace: helloworld-rollout
spec:
 resourceSelectors:
   - apiVersion: argoproj.io/v1alpha1  # 修正为 Argo Rollout 的 apiVersion
     kind: Rollout
     name: helloworld-stable
   - apiVersion: v1
     kind: Service
     name: helloworld
 placement:
   clusterAffinity:
     clusterNames:
       - k8s-master-beijing
       - k8s-master-shanghai
       - k8s-master-guangzhou
       - k8s-master-shenzhen
   replicaScheduling:
     replicaDivisionPreference: Weighted
     replicaSchedulingType: Divided
     weightPreference:
       staticWeightList:
         - targetCluster:
             clusterNames:
               - k8s-master-beijing
           weight: 1
         - targetCluster:
             clusterNames:
               - k8s-master-shanghai
           weight: 1
         - targetCluster:
             clusterNames:
               - k8s-master-guangzhou
           weight: 1
         - targetCluster:
             clusterNames:
               - k8s-master-shenzhen
           weight: 1
EOF
```

```shell
kubectl apply -f ~/argo-rollouts-yml/crd.yaml --kubeconfig=/root/karmada-config

kubectl get crd --kubeconfig=/root/karmada-config |grep argoproj.io

kubectl create ns helloworld-rollout --kubeconfig=/root/karmada-config

kubectl get ns --kubeconfig=/root/karmada-config
```

```shell
kubectl apply -f ~/helloworld-rollout-yml/helloworld-stable-rollout.yml --kubeconfig=/root/karmada-config

kubectl apply -f ~/helloworld-rollout-yml/helloworld-stable-svc.yml --kubeconfig=/root/karmada-config

kubectl describe ro -n helloworld-rollout helloworld-stable --kubeconfig=/root/karmada-config

kubectl apply -f ~/helloworld-rollout-yml/helloworld-stable-policy.yml --kubeconfig=/root/karmada-config
```

```shell
kubectl get ro -n helloworld-rollout --kubeconfig=/root/karmada-config

kubectl get svc -n helloworld-rollout --kubeconfig=/root/karmada-config

kubectl get PropagationPolicy -n helloworld-rollout --kubeconfig=/root/karmada-config

kubectl describe ro -n helloworld-rollout helloworld-stable --kubeconfig=/root/karmada-config

kubectl describe PropagationPolicy -n helloworld-rollout helloworld-stable-propagation --kubeconfig=/root/karmada-config
```

> 共部署4个副本，每个集群分配4个副本（这里以四个集群为例！！！）（这里是rollout控制器）
>
> 如果是deployment，这里共部署4个副本，每个集群将分配1个副本（这里以四个集群为例！！！）

###### 卸载

```shell
kubectl delete -f ~/helloworld-rollout-yml/helloworld-stable-policy.yml --kubeconfig=/root/karmada-config

kubectl delete -f ~/helloworld-rollout-yml/helloworld-stable-svc.yml --kubeconfig=/root/karmada-config

kubectl delete -f ~/helloworld-rollout-yml/helloworld-stable-rollout.yml --kubeconfig=/root/karmada-config
```

### 前端发布方案（无金丝雀）：

> 四个集群，每个集群都部署 Rollout、Services、Istio VirtualService 和 Istio Gateway

```shell
mkdir -p ~/helloworld-rollout-yml
```

```shell
cat > helloworld-stable-rollout.yml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: helloworld-stable
  namespace: helloworld-rollout
spec:
  replicas: 4
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {} # 人工卡点
      - setWeight: 40
      - pause: {duration: 10}
      - setWeight: 60
      - pause: {duration: 10}
      - setWeight: 80
      - pause: {duration: 10}
      - setWeight: 100
      - pause: {} # 人工卡点
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: helloworld
  template:
    metadata:
      labels:
        app: helloworld
    spec:
      containers:
      - name: helloworld
        image: ccr.ccs.tencentyun.com/huanghuanhui/helloworld:stable
        imagePullPolicy: IfNotPresent
        ports:
        - name: http
          containerPort: 80
          protocol: TCP
EOF
```

```shell
cat > helloworld-stable-svc.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: helloworld
  namespace: helloworld-rollout
  labels:
    app: helloworld
    service: helloworld
spec:
  ports:
  - port: 80
    name: http
  selector:
    app: helloworld
EOF
```

```shell
cat > helloworld-stable-vsvc.yml << 'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: helloworld-vsvc
  namespace: helloworld-rollout
spec:
  gateways:
  - helloworld-gateway
  hosts:
  - "helloworld.huanghuanhui.cloud"
  http:
  - name: primary
    route:
    - destination:
        host: prd-vue-svc-stable
      weight: 100
    - destination:
        host: prd-vue-svc-canary
      weight: 0
EOF
```

```shell
cat > helloworld-stable-gateway.yml << 'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: helloworld-gateway
  namespace: helloworld-rollout
spec:
  selector:
    istio: ingressgateway # 默认创建的 istio ingressgateway pod 有这个 Label
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "helloworld.huanghuanhui.cloud" # 匹配所有 host
    tls:
      mode: SIMPLE
      credentialName: helloworld-rollout-tls-secret
EOF
```

```shell
# 所有的istio的证书都放在（istio-system）命名空间下
kubectl create secret -n istio-system \
tls prd-vue-tls-secret \
--key=/root/ssl/huanghuanhui.cloud.key \
--cert=/root/ssl/huanghuanhui.cloud.crt
```

```shell
cat > helloworld-stable-policy.yml << 'EOF'
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
 name: helloworld-stable-propagation
 namespace: helloworld-rollout
spec:
 resourceSelectors:
   - apiVersion: argoproj.io/v1alpha1  # 修正为 Argo Rollout 的 apiVersion
     kind: Rollout
     name: helloworld-stable
   - apiVersion: v1
     kind: Service
     name: helloworld
 placement:
   clusterAffinity:
     clusterNames:
       - k8s-master-beijing
       - k8s-master-shanghai
       - k8s-master-guangzhou
       - k8s-master-shenzhen
   replicaScheduling:
     replicaDivisionPreference: Weighted
     replicaSchedulingType: Divided
     weightPreference:
       staticWeightList:
         - targetCluster:
             clusterNames:
               - k8s-master-beijing
           weight: 1
         - targetCluster:
             clusterNames:
               - k8s-master-shanghai
           weight: 1
         - targetCluster:
             clusterNames:
               - k8s-master-guangzhou
           weight: 1
         - targetCluster:
             clusterNames:
               - k8s-master-shenzhen
           weight: 1
EOF
```

```shell
kubectl get crd --kubeconfig=/root/karmada-config |grep istio

kubectl apply -f ~/istio-1.20.2/manifests/charts/base/crds/crd-all.gen.yaml --kubeconfig=/root/karmada-config

kubectl create ns helloworld-rollout --kubeconfig=/root/karmada-config

kubectl get ns --kubeconfig=/root/karmada-config
```

```shell
kubectl apply -f ~/helloworld-rollout-yml/helloworld-stable-rollout.yml --kubeconfig=/root/karmada-config

kubectl apply -f ~/helloworld-rollout-yml/helloworld-stable-svc.yml --kubeconfig=/root/karmada-config

kubectl describe ro -n helloworld-rollout helloworld-stable --kubeconfig=/root/karmada-config

kubectl apply -f ~/helloworld-rollout-yml/helloworld-stable-policy.yml --kubeconfig=/root/karmada-config

kubectl apply -f ~/helloworld-rollout-yml/helloworld-stable-vsvc.yml --kubeconfig=/root/karmada-config

kubectl apply -f ~/helloworld-rollout-yml/helloworld-stable-gateway.yml --kubeconfig=/root/karmada-config
```

```shell
kubectl get ro -n helloworld-rollout --kubeconfig=/root/karmada-config

kubectl get svc -n helloworld-rollout --kubeconfig=/root/karmada-config

kubectl get PropagationPolicy -n helloworld-rollout --kubeconfig=/root/karmada-config

kubectl describe ro -n helloworld-rollout helloworld-stable --kubeconfig=/root/karmada-config

kubectl describe PropagationPolicy -n helloworld-rollout helloworld-stable-propagation --kubeconfig=/root/karmada-config

kubectl get vs -n helloworld-rollout --kubeconfig=/root/karmada-config

kubectl get gateway -n helloworld-rollout --kubeconfig=/root/karmada-config
```

> 共部署4个副本，每个集群分配4个副本（这里以四个集群为例！！！）

###### 卸载

```shell
kubectl delete -f . --kubeconfig=/root/karmada-config
```

### 前端发布方案（金丝雀）：

> 四个集群，每个集群都部署 Rollout、Services、Istio VirtualService 和 Istio Gateway

```shell
mkdir -p ~/helloworld-rollout-yml
```

```shell
cat > helloworld-rollout.yml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: helloworld-stable
  namespace: helloworld-rollout
spec:
  replicas: 4
  strategy:
    canary:
      canaryService: helloworld-svc-canary # 关联 canary Service
      stableService: helloworld-svc-stable # 关联 stable Service
      trafficRouting:
        managedRoutes:
          - name: "header-route-1"
        istio:
          virtualServices:
          - name: helloworld-vsvc # 关联的 Istio virtualService
            routes:
            - primary
      steps:
      - setHeaderRoute:
          name: "header-route-1"
          match:
            - headerName: "X-canary"
              headerValue:
                exact: "test-user"
      - pause: {duration: 10}
      - setCanaryScale:
          weight: 20
      - pause: {} # 人工卡点（当有新版本上线的时候，给canary版本20%流量，并且暂停新版本继续更新，当测试人员完成测试可以继续更新，从而达到前端可以一直触发构建并且直接上到金丝雀上）
      - setCanaryScale:
          weight: 40
      - pause: {duration: 10}
      - setCanaryScale:
          weight: 60
      - pause: {duration: 10}
      - setCanaryScale:
          weight: 80
      - pause: {duration: 10}
  revisionHistoryLimit: 5
  selector:
    matchLabels:
      app: helloworld
  template:
    metadata:
      labels:
        app: helloworld
    spec:
      containers:
      - name: helloworld
        image: ccr.ccs.tencentyun.com/huanghuanhui/helloworld:canary
        imagePullPolicy: IfNotPresent
        ports:
        - name: http
          containerPort: 80
          protocol: TCP
EOF
```

```shell
cat > helloworld-rollout-svc.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: helloworld-svc-stable
  namespace: helloworld-rollout
  labels:
    app: helloworld
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: helloworld

---
apiVersion: v1
kind: Service
metadata:
  name: helloworld-svc-canary
  namespace: helloworld-rollout
  labels:
    app: helloworld
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: helloworld
EOF
```

```shell
cat > helloworld-vsvc.yml << 'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: helloworld-vsvc
  namespace: helloworld-rollout
spec:
  gateways:
  - helloworld-gateway
  hosts:
  - "helloworld.huanghuanhui.cloud"
  http:
  - name: primary
    route:
    - destination:
        host: helloworld-svc-stable
      weight: 100
    - destination:
        host: helloworld-svc-canary
      weight: 0
EOF
```

```shell
cat > helloworld-gateway.yml << 'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: helloworld-gateway
  namespace: helloworld-rollout
spec:
  selector:
    istio: ingressgateway # 默认创建的 istio ingressgateway pod 有这个 Label
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "helloworld.huanghuanhui.cloud" # 匹配所有 host
    tls:
      mode: SIMPLE
      credentialName: helloworld-rollout-tls-secret
EOF
```

```shell
# 所有的istio的证书都放在（istio-system）命名空间下
kubectl create secret -n istio-system \
tls prd-vue-tls-secret \
--key=/root/ssl/huanghuanhui.cloud.key \
--cert=/root/ssl/huanghuanhui.cloud.crt
```

```shell
cat > helloworld-stable-policy.yml << 'EOF'
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
 name: helloworld-stable-propagation
 namespace: helloworld-rollout
spec:
 resourceSelectors:
   - apiVersion: argoproj.io/v1alpha1  # 修正为 Argo Rollout 的 apiVersion
     kind: Rollout
     name: helloworld-stable
   - apiVersion: v1
     kind: Service
     name: helloworld-svc-stable
   - apiVersion: v1
     kind: Service
     name: helloworld-svc-canary
 placement:
   clusterAffinity:
     clusterNames:
       - k8s-master-beijing
       - k8s-master-shanghai
       - k8s-master-guangzhou
       - k8s-master-shenzhen
   replicaScheduling:
     replicaDivisionPreference: Weighted
     replicaSchedulingType: Divided
     weightPreference:
       staticWeightList:
         - targetCluster:
             clusterNames:
               - k8s-master-beijing
           weight: 1
         - targetCluster:
             clusterNames:
               - k8s-master-shanghai
           weight: 1
         - targetCluster:
             clusterNames:
               - k8s-master-guangzhou
           weight: 1
         - targetCluster:
             clusterNames:
               - k8s-master-shenzhen
           weight: 1
EOF
```

```shell
cat > helloworld-stable-vs-policy.yml << 'EOF'
apiVersion: policy.karmada.io/v1alpha1
kind: PropagationPolicy
metadata:
 name: helloworld-stable-propagation-vs
 namespace: helloworld-rollout
spec:
 resourceSelectors:
   - apiVersion: networking.istio.io/v1alpha3
     kind: VirtualService
     name: helloworld-vsvc
   - apiVersion: networking.istio.io/v1alpha3
     kind: Gateway
     name: helloworld-gateway
 placement:
   clusterAffinity:
     clusterNames:
       - k8s-master-beijing
       - k8s-master-shanghai
       - k8s-master-guangzhou
       - k8s-master-shenzhen
   replicaScheduling:
     replicaDivisionPreference: Weighted
     replicaSchedulingType: Divided
     weightPreference:
       staticWeightList:
         - targetCluster:
             clusterNames:
               - k8s-master-beijing
           weight: 1
         - targetCluster:
             clusterNames:
               - k8s-master-shanghai
           weight: 1
         - targetCluster:
             clusterNames:
               - k8s-master-guangzhou
           weight: 1
         - targetCluster:
             clusterNames:
               - k8s-master-shenzhen
           weight: 1
EOF
```

```shell
kubectl apply -f ~/calico-yml/calico.yaml --kubeconfig=/root/karmada-config
```

```shell
kubectl apply -f helloworld-stable-vs-policy.yml --kubeconfig=/root/karmada-config
```

```shell
kubectl apply -f . --kubeconfig=/root/karmada-config
```

```shell
kubectl get ro -n helloworld-rollout --kubeconfig=/root/karmada-config

kubectl get svc -n helloworld-rollout --kubeconfig=/root/karmada-config

kubectl get PropagationPolicy -n helloworld-rollout --kubeconfig=/root/karmada-config

kubectl describe ro -n helloworld-rollout helloworld-stable --kubeconfig=/root/karmada-config

kubectl describe PropagationPolicy -n helloworld-rollout helloworld-stable-propagation --kubeconfig=/root/karmada-config

kubectl describe PropagationPolicy -n helloworld-rollout helloworld-stable-propagation-vs --kubeconfig=/root/karmada-config

kubectl get vs -n helloworld-rollout --kubeconfig=/root/karmada-config

kubectl get gateway -n helloworld-rollout --kubeconfig=/root/karmada-config
```

> 共部署4个副本，每个集群分配一个副本（这里以四个集群为例！！！）

###### 卸载

```shell
kubectl delete -f . --kubeconfig=/root/karmada-config
```



1、ruoyi-gateway（部署 Rollout、Services、Istio VirtualService 和 Istio Gateway）

2、ruoyi-auth（部署 Rollout）

3、ruoyi-system（部署 Rollout）

4、ruoyi-vue（部署 Rollout、Services、Istio VirtualService 和 Istio Gateway）

```shell
正常的流量走vue的stable版本，连接stable的gateway

带请求头的流量走vue的canary版本，连接canary版本的gateway

访问前端canary版本，后端也走canary版本；访问前端stable版本，后端也走stable版本；
```

> 问题1：ruoyi-auth、ruoyi-system怎样区分流量？？？