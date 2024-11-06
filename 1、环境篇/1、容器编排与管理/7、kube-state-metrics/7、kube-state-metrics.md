### 7、kube-state-metrics

> 版本：k8s-v1.30.0
>
> 版本：v2.12.0
>
> https://github.com/kubernetes/kube-state-metrics

| kube-state-metrics | Kubernetes client-go Version |
| ------------------ | ---------------------------- |
| **v2.8.2**         | v1.26                        |
| **v2.9.2**         | v1.26                        |
| **v2.10.1**         | v1.27                        |
| **v2.11.0**         | v1.28                        |
| **v2.12.0**        | v1.29                        |
| **main**           | v1.29                        |

```shell
mkdir -p ~/kube-state-metrics-yml && cd ~/kube-state-metrics-yml
```

```shell
# wget https://github.com/kubernetes/kube-state-metrics/raw/v2.12.0/examples/standard/service-account.yaml

# wget https://github.com/kubernetes/kube-state-metrics/raw/v2.12.0/examples/standard/cluster-role.yaml

# wget https://github.com/kubernetes/kube-state-metrics/raw/v2.12.0/examples/standard/cluster-role-binding.yaml

# wget https://github.com/kubernetes/kube-state-metrics/raw/v2.12.0/examples/standard/deployment.yaml

# wget https://github.com/kubernetes/kube-state-metrics/raw/v2.12.0/examples/standard/service.yaml
```

```shell
wget https://gitee.com/kubelsp/upload/raw/master/kube-state-metrics/v2.12.0/service-account.yaml

wget https://gitee.com/kubelsp/upload/raw/master/kube-state-metrics/v2.12.0/cluster-role.yaml

wget https://gitee.com/kubelsp/upload/raw/master/kube-state-metrics/v2.12.0/cluster-role-binding.yaml

wget https://gitee.com/kubelsp/upload/raw/master/kube-state-metrics/v2.12.0/deployment.yaml

wget https://gitee.com/kubelsp/upload/raw/master/kube-state-metrics/v2.12.0/service.yaml
```

```shell
# 修改镜像（默认谷歌k8s.gcr.io）

sed -i 's#registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.12.0#ccr.ccs.tencentyun.com/huanghuanhui/kube-state-metrics:v2.12.0#g' deployment.yaml
```

```shell
kubectl apply -f .
```

```shell
kube_state_metrics_podIP=`kubectl get pods -n kube-system -o custom-columns='NAME:metadata.name,podIP:status.podIPs[*].ip' |grep kube-state-metrics |awk '{print $2}'`

curl "http://$kube_state_metrics_podIP:8080/metrics"
```

