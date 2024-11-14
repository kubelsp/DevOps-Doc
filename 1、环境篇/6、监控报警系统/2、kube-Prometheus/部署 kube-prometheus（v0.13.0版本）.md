**部署 kube-prometheus**

> k8s版本：k8s-1.30.0
>
> kube-prometheus版本：v0.13.0

#### 1、获取项目

https://github.com/prometheus-operator/kube-prometheus

```powershell
cd && wget https://github.com/prometheus-operator/kube-prometheus/archive/refs/tags/v0.13.0.tar.gz

cd && tar xf v0.13.0.tar.gz && cd ~/kube-prometheus-0.13.0
```

#### 2、拉取（导入）镜像（containerd版）

查看镜像

```powershell
find ~/kube-prometheus-0.13.0/manifests -type f |xargs grep 'image: '|sort|uniq|awk '{print $3}'|grep ^[a-zA-Z]|grep -Evw 'error|kubeRbacProxy'|sort -rn|uniq |grep -n ".*"
```

替换镜像地址（腾讯云）

`````shell
registry.k8s.io/prometheus-adapter/prometheus-adapter:v0.11.1
registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.9.2
quay.io/prometheus/prometheus:v2.46.0
quay.io/prometheus-operator/prometheus-operator:v0.67.1
quay.io/prometheus/node-exporter:v1.6.1
quay.io/prometheus/blackbox-exporter:v0.24.0
quay.io/prometheus/alertmanager:v0.26.0
quay.io/brancz/kube-rbac-proxy:v0.14.2
jimmidyson/configmap-reload:v0.5.0
grafana/grafana:9.5.3
`````

```shell
ccr.ccs.tencentyun.com/huanghuanhui/prometheus-adapter:v0.11.1
ccr.ccs.tencentyun.com/huanghuanhui/kube-state-metrics:v2.9.2
ccr.ccs.tencentyun.com/huanghuanhui/prometheus:v2.46.0
ccr.ccs.tencentyun.com/huanghuanhui/prometheus-operator:v0.67.1
ccr.ccs.tencentyun.com/huanghuanhui/node-exporter:v1.6.1
ccr.ccs.tencentyun.com/huanghuanhui/blackbox-exporter:v0.24.0
ccr.ccs.tencentyun.com/huanghuanhui/alertmanager:v0.26.0
ccr.ccs.tencentyun.com/huanghuanhui/kube-rbac-proxy:v0.14.2
ccr.ccs.tencentyun.com/huanghuanhui/configmap-reload:v0.5.0
ccr.ccs.tencentyun.com/huanghuanhui/grafana:9.5.3
```

`````shell
cd ~/kube-prometheus-0.13.0/manifests

sed -i 's#registry.k8s.io/prometheus-adapter/prometheus-adapter:v0.11.1#ccr.ccs.tencentyun.com/huanghuanhui/prometheus-adapter:v0.11.1#g' *yaml

sed -i 's#registry.k8s.io/kube-state-metrics/kube-state-metrics:v2.9.2#ccr.ccs.tencentyun.com/huanghuanhui/kube-state-metrics:v2.9.2#g' *yaml

sed -i 's#quay.io/prometheus/prometheus:v2.46.0#ccr.ccs.tencentyun.com/huanghuanhui/prometheus:v2.46.0#g' *yaml

sed -i 's#quay.io/prometheus-operator/prometheus-operator:v0.67.1#ccr.ccs.tencentyun.com/huanghuanhui/prometheus-operator:v0.67.1#g' *yaml

sed -i 's#quay.io/prometheus/node-exporter:v1.6.1#ccr.ccs.tencentyun.com/huanghuanhui/node-exporter:v1.6.1#g' *yaml

sed -i 's#quay.io/prometheus/blackbox-exporter:v0.24.0#ccr.ccs.tencentyun.com/huanghuanhui/blackbox-exporter:v0.24.0#g' *yaml

sed -i 's#quay.io/prometheus/alertmanager:v0.26.0#ccr.ccs.tencentyun.com/huanghuanhui/alertmanager:v0.26.0#g' *yaml

sed -i 's#quay.io/brancz/kube-rbac-proxy:v0.14.2#ccr.ccs.tencentyun.com/huanghuanhui/kube-rbac-proxy:v0.14.2#g' *yaml

sed -i 's#jimmidyson/configmap-reload:v0.5.0#ccr.ccs.tencentyun.com/huanghuanhui/configmap-reload:v0.5.0#g' *yaml

sed -i 's#grafana/grafana:9.5.3#ccr.ccs.tencentyun.com/huanghuanhui/grafana:9.5.3#g' *yaml
`````

在线预拉取镜像

```powershell
find ~/kube-prometheus-0.13.0/manifests -type f |xargs grep 'image: '|sort|uniq|awk '{print $3}'|grep ^[a-zA-Z]|grep -Evw 'error|kubeRbacProxy'|sort -rn|uniq |xargs -i crictl pull {}
```

离线导入镜像

```powershell
ls *tar |xargs -i ctr -n k8s.io i import {}
```

#### 3、部署kube-prometheus项目

```powershell
cd ~/kube-prometheus-0.13.0

kubectl apply --server-side -f manifests/setup

kubectl wait \
	--for condition=Established \
	--all CustomResourceDefinition \
	--namespace=monitoring

kubectl apply -f manifests/
```

#### 4、暴露prometheus、grafana、alertmanager服务端口

```powershell
#1、prometheus
kubectl patch svc/prometheus-k8s -n monitoring --patch '{"spec":
{"type":"NodePort"}}'

#2、grafana
kubectl patch svc/grafana -n monitoring --patch '{"spec": {"type":"NodePort"}}'

#3、alertmanager
kubectl patch svc/alertmanager-main -n monitoring --patch '{"spec":
{"type":"NodePort"}}'
```

```shell
kubectl patch svc/prometheus-k8s -n monitoring --type='json' -p '[{"op": "replace", "path": "/spec/ports/0/nodePort", "value":31999}]'

kubectl patch svc/grafana -n monitoring --type='json' -p '[{"op": "replace", "path": "/spec/ports/0/nodePort", "value":31998}]'

kubectl patch svc/alertmanager-main -n monitoring --type='json' -p '[{"op": "replace", "path": "/spec/ports/0/nodePort", "value":31997}]'
```

```powershell
kubectl get svc -n monitoring |grep NodePort
```

```powershell
kubectl get netpol -n monitoring
```

````shell
kubectl delete netpol --all -n monitoring
````

#### 5、访问

- ***访问 Grafana UI                 URL***：http://192.168.1.10:31999
- ***访问 Prometheus UI         URL***：http://192.168.1.10:31998
- ***访问 alertmanager UI       URL***：http://192.168.1.10:31997
- ***grafana默认用户名密码 ： amin/admin***

###### ingress

````shell
cat > ~/prometheus-yml/prometheus-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prometheus-ingress
  namespace: monitoring
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: prometheus.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prometheus-k8s
            port:
              number: 9090

  tls:
  - hosts:
    - prometheus.openhhh.com
    secretName: prometheus-ingress-tls
EOF
````

```shell
kubectl create secret -n monitoring \
tls prometheus-ingress-tls \
--key=/root/ssl/openhhh.com.key \
--cert=/root/ssl/openhhh.com.pem
```

````shell
kubectl apply -f ~/prometheus-yml/prometheus-Ingress.yml
````

> 访问地址：https://prometheus.openhhh.com

````shell
cat > ~/prometheus-yml/grafana-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana-ingress
  namespace: monitoring
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: grafana.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 3000

  tls:
  - hosts:
    - grafana.openhhh.com
    secretName: grafana-ingress-tls
EOF
````

```shell
kubectl create secret -n monitoring \
tls grafana-ingress-tls \
--key=/root/ssl/openhhh.com.key \
--cert=/root/ssl/openhhh.com.pem
```

````shell
kubectl apply -f ~/prometheus-yml/grafana-Ingress.yml
````

> 访问地址：https://grafana.openhhh.com
>
> 账号密码：admin、Admin@2024

> https://grafana.com/grafana/dashboards/
>
> 模版：8919、12159、13105、9276、12006

```shell
cat > ~/prometheus-yml/alertmanager-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: alertmanager-ingress
  namespace: monitoring
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: alertmanager.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: alertmanager-main
            port:
              number: 9093

  tls:
  - hosts:
    - prometheus.openhhh.com
    secretName: alertmanager-ingress-tls
EOF
```

````shell
kubectl create secret -n monitoring \
tls alertmanager-ingress-tls \
--key=/root/ssl/openhhh.com.key \
--cert=/root/ssl/openhhh.com.pem
````

```shell
kubectl apply -f ~/prometheus-yml/alertmanager-Ingress.yml
```

> 访问地址：https://alertmanager.openhhh.com

#### 6、监控kube-controller-manager+kube-scheduler

#### a、原因分析：

> 1、和 `ServiceMonitor` 的定义有关系
>
> 2、先来查看下 kube-scheduler 组件对应的 ServiceMonitor 资源的定义
>
> ```powershell
> cat manifests/kubernetesControlPlane-serviceMonitorKubeScheduler.yaml
> ```
>
> 3、在`ServiceMonitor` 资源对象里的`selector.matchLabels` 在 `kube-system` 这个命名空间下面匹配具有 `k8s-app=kube-scheduler` 这样的 Service
>
> 4、但是系统中根本就没有对应的 Service：（问题所在）
>
> ```powershell
> kubectl get svc -n kube-system -l app.kubernetes.io/name=kube-scheduler
> 
> No resources found in kube-system namespace.
> ```
>
> 5、所以需要去创建一个对应的 Service 对象，才能与 `ServiceMonitor` 进行关联：（解决问题）

```powershell
# cat manifests/kubernetesControlPlane-serviceMonitorKubeControllerManager.yaml

#2、先来查看下 kube-scheduler组件对应的 ServiceMonitor资源的定义
# cat manifests/kubernetesControlPlane-serviceMonitorKubeScheduler.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    app.kubernetes.io/name: kube-scheduler
    app.kubernetes.io/part-of: kube-prometheus
  name: kube-scheduler
  namespace: monitoring
spec:
  endpoints:
  - bearerTokenFile: /var/run/secrets/kubernetes.io/serviceaccount/token
    interval: 30s
    port: https-metrics
    scheme: https
    tlsConfig:
      insecureSkipVerify: true
  jobLabel: app.kubernetes.io/name
  namespaceSelector:
    matchNames:
    - kube-system
  selector:
    matchLabels:
      app.kubernetes.io/name: kube-scheduler
```

#### b、解决问题：

```powershell
mkdir ~/my-kube-prometheus && cd ~/my-kube-prometheus
```

#### 1、对kube-Controller-manager的监控

```powershell
cat > ~/my-kube-prometheus/prometheus-kubeControllerManagerService.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  namespace: kube-system
  name: kube-controller-manager
  labels:  #必须和上面的 ServiceMonitor 下面的 matchLabels 保持一致
    app.kubernetes.io/name: kube-controller-manager
spec:
  selector:
    component: kube-controller-manager
  ports:
  - name: https-metrics
    port: 10257
    targetPort: 10257  #controller-manager的安全端口为10257
EOF
```

> 其中最重要的是上面 labels 和 selector 部分，labels 区域的配置必须和我们上面的 ServiceMonitor 对象中的 selector 保持一致，selector 下面配置的是 `component=kube-scheduler`，为什么会是这个 label 标签呢，我们可以去 describe 下 kube-scheduler 这个 Pod：

```powershell
# kubectl describe pod kube-scheduler-master -n kube-system
Name:                 kube-scheduler-master
Namespace:            kube-system
Priority:             2000001000
Priority Class Name:  system-node-critical
Node:                 master/192.168.1.201
Start Time:           Tue, 04 Jan 2022 10:09:14 +0800
Labels:               component=kube-scheduler
                      tier=control-plane
......
```

> 可以看到这个 Pod 具有 `component=kube-scheduler` 和 `tier=control-plane` 这两个标签，而前面这个标签具有更唯一的特性，所以使用前面这个标签较好，这样上面创建的 Service 就可以和这个 Pod 进行关联了

```powershell
kubectl apply -f ~/my-kube-prometheus/prometheus-kubeControllerManagerService.yaml
```

```powershell
kubectl get svc -n kube-system 
```

```powershell
sed -i 's/bind-address=127.0.0.1/bind-address=0.0.0.0/g' /etc/kubernetes/manifests/kube-controller-manager.yaml
```

> 因为 kube-controller-manager 启动的时候默认绑定的是 `127.0.0.1` 地址，所以要通过 IP 地址去访问就被拒绝了，所以需要将 `--bind-address=127.0.0.1` 更改为 `--bind-address=0.0.0.0` ，更改后 kube-scheduler 会自动重启，重启完成后再去查看 Prometheus 上面的采集目标就正常了

#### 2、对kube-Scheduler的监控

```powershell
cat > ~/my-kube-prometheus/prometheus-kubeSchedulerService.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  namespace: kube-system
  name: kube-scheduler
  labels:  #必须和上面的 ServiceMonitor 下面的 matchLabels 保持一致
    app.kubernetes.io/name: kube-scheduler
spec:
  selector:
    component: kube-scheduler
  ports:
  - name: https-metrics
    port: 10259  
    targetPort: 10259  #需要注意现在版本默认的安全端口是10259
EOF
```

```powershell
kubectl apply -f ~/my-kube-prometheus/prometheus-kubeSchedulerService.yaml
```

```powershell
sed -i 's/bind-address=127.0.0.1/bind-address=0.0.0.0/g' /etc/kubernetes/manifests/kube-scheduler.yaml
```

如果要清理 Prometheus-Operator，可以直接删除对应的资源清单即可：

```powershell
# kubectl delete -f manifests

# kubectl delete -f manifests/setup
```

