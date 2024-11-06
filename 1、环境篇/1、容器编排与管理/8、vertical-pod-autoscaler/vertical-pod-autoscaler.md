## vertical-pod-autoscaler

> 版本：k8s-v1.30.0
>
> https://github.com/kubernetes/autoscaler

```shell
mkdir -p vertical-pod-autoscaler-yml
```

```shell
# wget https://github.com/kubernetes/autoscaler/raw/vertical-pod-autoscaler-0.13.0/vertical-pod-autoscaler/deploy/vpa-rbac.yaml

# wget https://github.com/kubernetes/autoscaler/raw/vertical-pod-autoscaler-0.13.0/vertical-pod-autoscaler/deploy/vpa-v1-crd-gen.yaml

# wget https://github.com/kubernetes/autoscaler/raw/vertical-pod-autoscaler-0.8.0/vertical-pod-autoscaler/pkg/admission-controller/gencerts.sh

# wget https://github.com/kubernetes/autoscaler/raw/vertical-pod-autoscaler-0.13.0/vertical-pod-autoscaler/deploy/admission-controller-deployment.yaml

# wget https://github.com/kubernetes/autoscaler/raw/vertical-pod-autoscaler-0.13.0/vertical-pod-autoscaler/deploy/recommender-deployment.yaml

# wget https://github.com/kubernetes/autoscaler/raw/vertical-pod-autoscaler-0.13.0/vertical-pod-autoscaler/deploy/updater-deployment.yaml
```

```shell
wget https://gitee.com/kubelsp/upload/raw/master/vpa/vertical-pod-autoscaler-0.13.0/vpa-rbac.yaml

wget https://gitee.com/kubelsp/upload/raw/master/vpa/vertical-pod-autoscaler-0.13.0/vpa-v1-crd-gen.yaml

wget https://gitee.com/kubelsp/upload/raw/master/vpa/vertical-pod-autoscaler-0.13.0/gencerts.sh

wget https://gitee.com/kubelsp/upload/raw/master/vpa/vertical-pod-autoscaler-0.13.0/admission-controller-deployment.yaml

wget https://gitee.com/kubelsp/upload/raw/master/vpa/vertical-pod-autoscaler-0.13.0/recommender-deployment.yaml

wget https://gitee.com/kubelsp/upload/raw/master/vpa/vertical-pod-autoscaler-0.13.0/updater-deployment.yaml
```

```shell
sed -i 's/Always/IfNotPresent/g' ./*

sed -i 's/k8s\.gcr\.io\/autoscaling/registry.cn-hangzhou.aliyuncs.com\/acs/g' ./*
```

```shell
kubectl apply -f vpa-rbac.yaml
kubectl apply -f vpa-v1-crd-gen.yaml
sh gencerts.sh
kubectl apply -f admission-controller-deployment.yaml
kubectl apply -f recommender-deployment.yaml
kubectl apply -f updater-deployment.yaml
```

验证 VPA

```shell
cat > nginx-deployment-basic.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment-basic
  namespace: default
  labels:
    app: nginx
spec:
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: ccr.ccs.tencentyun.com/huanghuanhui/nginx:1.25.3-alpine
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: default
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP

---
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: nginx-deployment-basic-vpa
  namespace: default
spec:
  targetRef:
    apiVersion: "apps/v1"
    kind:       Deployment
    name:       nginx-deployment-basic
  updatePolicy:
    updateMode: "Off"
EOF
```

```shell
kubectl apply -f nginx-deployment-basic.yml
```

```shell
# 需要等待两分钟，才能返回结果
kubectl get vpa -n default

kubectl describe vpa nginx-deployment-basic-vpa -n default |tail -n 16
```

如下：

```shell
[root@k8s-master ~]# kubectl get vpa -n default
NAME                         MODE   CPU   MEM       PROVIDED   AGE
nginx-deployment-basic-vpa   Off    25m   262144k   True       5m3s
[root@k8s-master ~]# kubectl describe vpa nginx-deployment-basic-vpa -n default |tail -n 16
  Recommendation:
    Container Recommendations:
      Container Name:  nginx
      Lower Bound:
        Cpu:     25m
        Memory:  262144k
      Target:
        Cpu:     25m
        Memory:  262144k
      Uncapped Target:
        Cpu:     25m
        Memory:  262144k
      Upper Bound:
        Cpu:     4089m
        Memory:  8765548505
Events:          <none>
```

```shell
yum -y install httpd-tools

#  50 并发、2000 个请求
ab -c 50 -n 2000 LoadBalancer(sample-app):8080/
ab -c 50 -n 2000 http://10.103.87.82/
ab -c 1000 -n 100000000 http://10.103.87.82/
```
