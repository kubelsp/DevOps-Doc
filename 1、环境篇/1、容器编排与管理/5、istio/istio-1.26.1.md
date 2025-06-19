### istio

> 版本：istio-1.26.1
>
> https://github.com/istio/istio

```shell
# cd && wget https://github.com/istio/istio/releases/download/1.26.1/istio-1.26.1-linux-amd64.tar.gz
```

```shell
cd && wget https://gh-proxy.com/github.com/istio/istio/releases/download/1.26.1/istio-1.26.1-linux-amd64.tar.gz
```

```shell
tar xf istio-1.26.1-linux-amd64.tar.gz

cp ~/istio-1.26.1/bin/istioctl /usr/bin/istioctl
```

```shell
# istioctl version
no ready Istio pods in "istio-system"
1.26.1
```

```shell
istioctl install --set profile=demo -y
```

```shell
# istioctl version
client version: 1.26.1
control plane version: 1.26.1
data plane version: 1.26.1 (2 proxies)
```

stioctl 命令补全

```
yum -y install bash-completion

source /etc/profile.d/bash_completion.sh

cp ~/istio-1.26.1/tools/istioctl.bash ~/.istioctl.bash

source ~/.istioctl.bash
```

卸载

```
istioctl uninstall --purge
```

`````shell
istioctl install -y \
    --set profile=default \  # 使用默认安装配置（适合生产环境）
    --set components.egressGateways[0].name=istio-egressgateway \  # 启用 Egress Gateway
    --set values.global.mtls.auto=true \  # 全局自动启用 mTLS
    --set values.gateways.istio-ingressgateway.type=LoadBalancer  # Ingress Gateway 使用 LoadBalancer 类型
`````

```shell
istioctl install --set profile=demo --set values.gateways.istio-ingressgateway.type=NodePort
```

