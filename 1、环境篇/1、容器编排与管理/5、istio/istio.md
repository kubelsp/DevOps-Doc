### 4、istio

> 版本：istio-1.22.3
>
> https://github.com/istio/istio

```shell
# cd && wget https://github.com/istio/istio/releases/download/1.22.3/istio-1.22.3-linux-amd64.tar.gz
```

```shell
cd && wget https://gitee.com/kubelsp/upload/raw/master/istio/1.22.3/istio-1.22.3-linux-amd64.tar.gz
```

```shell
tar xf istio-1.22.3-linux-amd64.tar.gz

cp ~/istio-1.22.3/bin/istioctl /usr/bin/istioctl
```

```shell
# istioctl version
no ready Istio pods in "istio-system"
1.22.3
```

```shell
istioctl install --set profile=demo -y
```

```shell
# istioctl version
client version: 1.22.3
control plane version: 1.22.3
data plane version: 1.22.3 (2 proxies)
```

stioctl 命令补全

```
yum -y install bash-completion

source /etc/profile.d/bash_completion.sh

cp ~/istio-1.22.3/tools/istioctl.bash ~/.istioctl.bash

source ~/.istioctl.bash
```

卸载

```
istioctl manifest generate --set profile=demo | kubectl delete --ignore-not-found=true -f -
kubectl delete namespace istio-system
```

