### MetalLB

使用 [MetalLB](https://metallb.universe.tf/installation/) 让 `LoadBalancer` 服务使用 `EXTERNAL-IP`

在 `k8s-master` 安装 `MetalLB`

> https://github.com/metallb/metallb
>
> https://metallb.universe.tf/installation/
>
>MetalLB: v0.15.2
>
>k8s版本：k8s-v1.33.1

```shell
kubectl get configmap -n kube-system kube-proxy
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: "ipvs"
ipvs:
  strictARP: true
```

```shell
# see what changes would be made, returns nonzero returncode if different
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl diff -f - -n kube-system

# actually apply the changes, returns nonzero returncode on errors only
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed -e "s/strictARP: false/strictARP: true/" | \
kubectl apply -f - -n kube-system
```

```shell
kubectl rollout restart daemonset kube-proxy -n kube-system
```

**配置 MetalLB 为Layer2 模式**

```shell
# kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml

# mkdir -p ~/MetalLB-yml && cd ~/MetalLB-yml

# wget https://raw.githubusercontent.com/metallb/metallb/v0.15.2/config/manifests/metallb-native.yaml

# kubectl apply -f ~/MetalLB-yml/metallb-native.yaml
```

```shell
# kubectl apply -f https://gitee.com/kubelsp/upload/raw/master/metallb/v0.15.2/metallb-native.yaml

mkdir -p ~/MetalLB-yml && cd ~/MetalLB-yml

wget https://gitee.com/kubelsp/upload/raw/master/metallb/v0.15.2/metallb-native.yaml

sed -i 's#quay.io/metallb/controller:v0.15.2#ccr.ccs.tencentyun.com/huanghuanhui/metallb:controller-v0.15.2#g' metallb-native.yaml

sed -i 's#quay.io/metallb/speaker:v0.15.2#ccr.ccs.tencentyun.com/huanghuanhui/metallb:speaker-v0.15.2#g' metallb-native.yaml

kubectl apply -f ~/MetalLB-yml/metallb-native.yaml
```

```shell
# k8s-master 创建ip地址池
cat > ~/MetalLB-yml/iptool.yaml << 'EOF'
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: default
  namespace: metallb-system
spec:
  addresses:
  - 192.168.1.100-192.168.1.172 # 网段跟node节点保持一致
  autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: default
  namespace: metallb-system
spec:
  ipAddressPools:
  - default
EOF

kubectl apply -f ~/MetalLB-yml/iptool.yaml
```

```shell
# kubectl get IPAddressPool -n metallb-system
NAME      AUTO ASSIGN   AVOID BUGGY IPS   ADDRESSES
default   true          false             ["192.168.1.100-192.168.1.172"]
```

