### metrics-server

> https://github.com/kubernetes-sigs/metrics-server

> 版本：v0.7.1
>
> k8s-v1.30.0

| Metrics Server | Metrics API group/version | Supported Kubernetes version |
| -------------- | ------------------------- | ---------------------------- |
| 0.7.x          | `metrics.k8s.io/v1beta1`  | 1.19+                        |
| 0.6.x          | `metrics.k8s.io/v1beta1`  | 1.19+                        |
| 0.5.x          | `metrics.k8s.io/v1beta1`  | *1.8+                        |
| 0.4.x          | `metrics.k8s.io/v1beta1`  | *1.8+                        |
| 0.3.x          | `metrics.k8s.io/v1beta1`  | 1.8-1.21                     |


```shell
# mkdir -p ~/metrics-server && cd ~/metrics-server && wget https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.7.1/components.yaml
```

```shell
mkdir -p ~/metrics-server && cd ~/metrics-server && wget https://gitee.com/kubelsp/upload/raw/master/metrics-server/v0.7.1/components.yaml
```

```shell
#1、添加"- --kubelet-insecure-tls"参数（匹配行后）
sed -i '/15s/a\        - --kubelet-insecure-tls' ~/metrics-server/components.yaml

#2、 修改镜像（默认谷歌k8s.gcr.io）
sed -i 's#registry.k8s.io/metrics-server/metrics-server:v0.7.1#ccr.ccs.tencentyun.com/huanghuanhui/metrics-server:v0.7.1#g' components.yaml
```

```shell
kubectl apply -f ~/metrics-server/components.yaml

kubectl get pods -n kube-system -l k8s-app=metrics-server
```

```shell
[root@k8s-master ~/metrics-server]# kubectl top node
NAME         CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
k8s-master   209m         5%     1993Mi          25%
k8s-node1    100m         1%     749Mi           4%
k8s-node2    57m          0%     802Mi           5%
k8s-node3    64m          0%     891Mi           5%
[root@k8s-master ~/metrics-server]# kubectl top pod
NAME                                       CPU(cores)   MEMORY(bytes)
calico-kube-controllers-5fc7d6cf67-c9l8v   1m           26Mi
calico-node-lgvrg                          25m          197Mi
calico-node-nsns8                          38m          170Mi
calico-node-z2lv4                          28m          193Mi
calico-node-zn4k5                          46m          178Mi
coredns-857d9ff4c9-l8ltv                   2m           22Mi
coredns-857d9ff4c9-v9bn2                   2m           24Mi
etcd-k8s-master                            30m          145Mi
kube-apiserver-k8s-master                  68m          841Mi
kube-controller-manager-k8s-master         23m          66Mi
kube-proxy-6h7k8                           1m           27Mi
kube-proxy-7kwdk                           5m           30Mi
kube-proxy-fqbpm                           6m           26Mi
kube-proxy-q868k                           11m          35Mi
kube-scheduler-k8s-master                  3m           23Mi
metrics-server-84957d8477-wmpwc            3m           18Mi
[root@k8s-master ~/metrics-server]# kubectl get node
NAME         STATUS   ROLES           AGE   VERSION
k8s-master   Ready    control-plane   13h   v1.29.1
k8s-node1    Ready    <none>          13h   v1.29.1
k8s-node2    Ready    <none>          13h   v1.29.1
k8s-node3    Ready    <none>          13h   v1.29.1
[root@k8s-master ~/metrics-server]#
```

