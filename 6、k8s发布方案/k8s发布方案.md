### k8s发布方案

> `（金丝雀发布）（渐进式交付）`

`单集群：`

发布方案 1：`Deployment + Ingress`

发布方案 2：`Argo-Rollout + Ingress`

发布方案 3：`Argo-Rollout + Istio `



`多集群`

发布方案 1：`Karmada + Deployment + Ingress`

发布方案 2：`Karmada + Argo-Rollout + Ingress`

发布方案 3：`Karmada + Argo-Rollout + Istio `

===

`单集群：`

###### 发布方案 1：`Deployment + Ingress`

> （Java）SpringCloud（k8s生产yml文件）接入skywalking的生产yml

```shell
cat > ~/prd-yml/${AppName}-Deployment.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${AppName}
  namespace: prd
  labels:
    app: ${AppName}
spec:
  minReadySeconds: 10  # 最小准备时间
  replicas: 3  # 副本数
  revisionHistoryLimit: 10  # 修订历史限制
  selector:
    matchLabels:
      app: ${AppName}
  strategy:
    rollingUpdate:
      maxSurge: 25%  # 滚动更新中允许超出的最大副本数
      maxUnavailable: 25%  # 滚动更新中允许不可用的最大副本数
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: ${AppName}
      annotations:
        prometheus.io/port: "${Port}"
        prometheus.io/scrape: "true"
        prometheus.io/path: "actuator/prometheus"
    spec:
      initContainers:
        - name: skywalking-agent
          image: apache/skywalking-java-agent:9.1.0-alpine
          imagePullPolicy: IfNotPresent
          resources:
            limits:
              cpu: "1"
              memory: 1Gi
            requests:
              cpu: "0.5"
              memory: 512Mi
          command:
            - "sh"
          args:
            - "-c"
            - "cp -R /skywalking/agent /agent/"
          volumeMounts:
            - name: sw-agent
              mountPath: /agent
      restartPolicy: Always  # 重启策略
      terminationGracePeriodSeconds: 30  # 终止优雅期限
      imagePullSecrets:
        - name: harbor-secret  # 镜像拉取密钥
      containers:
      - name: ${AppName}
        image: ccr.ccs.tencentyun.com/huanghuanhui/helloworld:stable  # 容器镜像
        imagePullPolicy: IfNotPresent  # 镜像拉取策略
        ports:
        - name: http
          containerPort: ${Port}  # 容器端口
        env:
          - name: JAVA_TOOL_OPTIONS
            value: "-javaagent:/skywalking/agent/skywalking-agent.jar"
          - name: SW_AGENT_NAME
            value: ${AppName}
          - name: SW_AGENT_COLLECTOR_BACKEND_SERVICES
            value: "skywalking-oap.skywalking.svc.cluster.local:11${Port}0"
        resources:
          requests:
            cpu: "128m"
            memory: "512Mi"  # 容器资源请求
          limits:
            cpu: "2"
            memory: "4Gi"  # 容器资源限制
        livenessProbe:
          failureThreshold: 3  # 失败阈值
          httpGet:
            port: ${Port}
            path: /  # 检测应用是否存活的路径
          initialDelaySeconds: 30  # 初始延迟时间，容器启动后多久开始检测
          periodSeconds: 30  # 检测间隔时间
          successThreshold: 1
          timeoutSeconds: 1
        readinessProbe:
          failureThreshold: 3  # 失败阈值
          httpGet:
            path: /   # 检测应用是否准备好接收流量的路径
            port: ${Port}
          initialDelaySeconds: 30  # 初始延迟时间，容器启动后多久开始检测
          periodSeconds: 30  # 检测间隔时间
          successThreshold: 1
          timeoutSeconds: 1
        volumeMounts:
        - name: localtime
          mountPath: /etc/localtime  # 时间同步挂载
        - name: sw-agent
          mountPath: /skywalking
        - name: prd-logs
          mountPath: /usr/local/prd-logs
      volumes:
      - name: localtime
        hostPath:
          path: /etc/localtime  # 宿主机时间路径
      - name: sw-agent
        emptyDir: {}
      - name: prd-logs
        emptyDir: {}
EOF
```



```shell
cat > ~/prd-yml/prd-vue-Deployment.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prd-vue
  namespace: prd
  labels:
    app: prd-vue
spec:
  minReadySeconds: 10  # 最小准备时间
  replicas: 3  # 副本数
  revisionHistoryLimit: 10  # 修订历史限制
  selector:
    matchLabels:
      app: prd-vue
  strategy:
    rollingUpdate:
      maxSurge: 25%  # 滚动更新中允许超出的最大副本数（如果设置0）
      maxUnavailable: 25%  # 滚动更新中允许不可用的最大副本数（如果设置1==>删掉一个，新起一个）
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: prd-vue
      annotations:
        prometheus.io/port: "80"
        prometheus.io/scrape: "true"
        prometheus.io/path: "actuator/prometheus"
    spec:
      initContainers:
        - name: skywalking-agent
          image: apache/skywalking-java-agent:9.1.0-alpine
          imagePullPolicy: IfNotPresent
          resources:
            limits:
              cpu: "1"
              memory: 1Gi
            requests:
              cpu: "0.5"
              memory: 512Mi
          command:
            - "sh"
          args:
            - "-c"
            - "cp -R /skywalking/agent /agent/"
          volumeMounts:
            - name: sw-agent
              mountPath: /agent
      restartPolicy: Always  # 重启策略
      terminationGracePeriodSeconds: 30  # 终止优雅期限
      imagePullSecrets:
        - name: harbor-secret  # 镜像拉取密钥
      containers:
      - name: prd-vue
        image: ccr.ccs.tencentyun.com/huanghuanhui/helloworld:stable  # 容器镜像
        imagePullPolicy: IfNotPresent  # 镜像拉取策略
        ports:
        - name: http
          containerPort: 80  # 容器端口
        env:
          - name: JAVA_TOOL_OPTIONS
            value: "-javaagent:/skywalking/agent/skywalking-agent.jar"
          - name: SW_AGENT_NAME
            value: prd-vue
          - name: SW_AGENT_COLLECTOR_BACKEND_SERVICES
            value: "skywalking-oap.skywalking.svc.cluster.local:11800"
        resources:
          requests:
            cpu: "128m"
            memory: "512Mi"  # 容器资源请求
          limits:
            cpu: "2"
            memory: "4Gi"  # 容器资源限制
        livenessProbe:
          failureThreshold: 3  # 失败阈值
          httpGet:
            port: 80
            path: /  # 检测应用是否存活的路径
          initialDelaySeconds: 30  # 初始延迟时间，容器启动后多久开始检测
          periodSeconds: 30  # 检测间隔时间
          successThreshold: 1
          timeoutSeconds: 1
        readinessProbe:
          failureThreshold: 3  # 失败阈值
          httpGet:
            path: /   # 检测应用是否准备好接收流量的路径
            port: 80
          initialDelaySeconds: 30  # 初始延迟时间，容器启动后多久开始检测
          periodSeconds: 30  # 检测间隔时间
          successThreshold: 1
          timeoutSeconds: 1
        volumeMounts:
        - name: localtime
          mountPath: /etc/localtime  # 时间同步挂载
        - name: sw-agent
          mountPath: /skywalking
        - name: prd-logs
          mountPath: /usr/local/prd-logs
      volumes:
      - name: localtime
        hostPath:
          path: /etc/localtime  # 宿主机时间路径
      - name: sw-agent
        emptyDir: {}
      - name: prd-logs
        emptyDir: {}
EOF
```

```shell
cat > ~/prd-yml/prd-vue-Service.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: prd-vue-service
  namespace: prd
  labels:
    app: prd-vue
spec:
  selector:
    app: prd-vue
  type: ClusterIP
  ports:
  - name: http
    port: 80
    targetPort: http
EOF
```

```shell
cat > ~/prd-yml/prd-vue-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prd-vue-ingress
  namespace: prd
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: prd-vue.huanghuanhui.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prd-vue-service
            port:
              number: 80
  tls:
  - hosts:
    - prd-vue.huanghuanhui.cloud
    secretName: prd-vue-ingress-tls
EOF
```

```shell
kubectl create secret -n prd \
tls prd-vue-ingress-tls \
--key=/root/ssl/huanghuanhui.cloud.key \
--cert=/root/ssl/huanghuanhui.cloud.crt
```

```shell
kubectl apply -f ~/prd-yml/prd-vue-Ingress.yml
```

```shell
kubectl set image deploy prd-vue prd-vue=ccr.ccs.tencentyun.com/huanghuanhui/helloworld:canary -n prd --record

kubectl rollout status -n prd deploy prd-vue
```

###### 发布方案 2：`Argo-Rollout + Ingress`

```shell
cat > ~/prd-yml/prd-vue-Rollout.yml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: prd-vue
  namespace: prd
spec:
  replicas: 3
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
      app: prd-vue
  template:
    metadata:
      labels:
        app: prd-vue
    spec:
      restartPolicy: Always  # 重启策略
      terminationGracePeriodSeconds: 30  # 终止优雅期限
      imagePullSecrets:
        - name: harbor-secret  # 镜像拉取密钥
      containers:
      - name: prd-vue
        image: ccr.ccs.tencentyun.com/huanghuanhui/helloworld:stable  # 容器镜像
        imagePullPolicy: IfNotPresent  # 镜像拉取策略
        ports:
        - name: http
          containerPort: 80  # 容器端口
        livenessProbe:
          failureThreshold: 3  # 失败阈值
          httpGet:
            port: 80
            path: /  # 检测应用是否存活的路径
          initialDelaySeconds: 30  # 初始延迟时间，容器启动后多久开始检测
          periodSeconds: 30  # 检测间隔时间
          successThreshold: 1
          timeoutSeconds: 1
        readinessProbe:
          failureThreshold: 3  # 失败阈值
          httpGet:
            path: /   # 检测应用是否准备好接收流量的路径
            port: 80
          initialDelaySeconds: 30  # 初始延迟时间，容器启动后多久开始检测
          periodSeconds: 30  # 检测间隔时间
          successThreshold: 1
          timeoutSeconds: 1
        resources:
          requests:
            memory: "2Gi"  # 容器资源请求
            cpu: "1"
          limits:
            memory: "4Gi"  # 容器资源限制
            cpu: "2"
        volumeMounts:
        - name: localtime
          mountPath: /etc/localtime  # 时间同步挂载
      volumes:
      - name: localtime
        hostPath:
          path: /etc/localtime  # 宿主机时间路径
EOF
```

```shell
cat > ~/prd-yml/prd-vue-Service.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: prd-vue-service
  namespace: prd
  labels:
    app: prd-vue
spec:
  selector:
    app: prd-vue
  type: ClusterIP
  ports:
  - name: http
    port: 80
    targetPort: http
EOF
```

```shell
cat > ~/prd-yml/prd-vue-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: prd-vue-ingress
  namespace: prd
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: prd-vue.huanghuanhui.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: prd-vue-service
            port:
              number: 80
  tls:
  - hosts:
    - prd-vue.huanghuanhui.cloud
    secretName: prd-vue-ingress-tls
EOF
```

```shell
kubectl create secret -n prd \
tls prd-vue-ingress-tls \
--key=/root/ssl/huanghuanhui.cloud.key \
--cert=/root/ssl/huanghuanhui.cloud.crt
```

```shell
kubectl apply -f ~/prd-yml/prd-vue-Ingress.yml
```

```shell
kubectl argo rollouts set image prd-vue prd-vue=ccr.ccs.tencentyun.com/huanghuanhui/helloworld:canary -n prd

kubectl argo rollouts get rollout prd-vue -n prd

kubectl argo rollouts status prd-vue -n prd
```

###### 发布方案 3：`Argo-Rollout + Istio `

> argo-rollouts + istio（金丝雀发布）（渐进式交付）（请求头）
>
> 在 Istio 服务网格中使用 Argo Rollouts 实现智能的渐进式发布

> 部署 Rollout、Services、Istio VirtualService 和 Istio Gateway
>
> 下面部署一个前端vue为案例（实现带请求头的流量永远走canary版本，正常访问的流量走stable版本）

```shell
cat > ~/prd-yml/prd-vue-Rollout.yml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: prd-vue
  namespace: prd
spec:
  replicas: 3
  strategy:
    canary:
      canaryService: prd-vue-svc-canary # 关联 canary Service
      stableService: prd-vue-svc-stable # 关联 stable Service
      trafficRouting:
        managedRoutes:
          - name: "header-route-1"
        istio:
          virtualServices:
          - name: prd-vue-vsvc # 关联的 Istio virtualService
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
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: prd-vue
  template:
    metadata:
      labels:
        app: prd-vue
    spec:
      restartPolicy: Always  # 重启策略
      terminationGracePeriodSeconds: 30  # 终止优雅期限
      imagePullSecrets:
        - name: harbor-secret  # 镜像拉取密钥
      containers:
      - name: prd-vue
        image: ccr.ccs.tencentyun.com/huanghuanhui/helloworld:stable  # 容器镜像
        imagePullPolicy: IfNotPresent  # 镜像拉取策略
        ports:
        - name: http
          containerPort: 80  # 容器端口
        livenessProbe:
          failureThreshold: 3  # 失败阈值
          httpGet:
            port: 80
            path: /  # 检测应用是否存活的路径
          initialDelaySeconds: 30  # 初始延迟时间，容器启动后多久开始检测
          periodSeconds: 30  # 检测间隔时间
          successThreshold: 1
          timeoutSeconds: 1
        readinessProbe:
          failureThreshold: 3  # 失败阈值
          httpGet:
            path: /   # 检测应用是否准备好接收流量的路径
            port: 80
          initialDelaySeconds: 30  # 初始延迟时间，容器启动后多久开始检测
          periodSeconds: 30  # 检测间隔时间
          successThreshold: 1
          timeoutSeconds: 1
        resources:
          requests:
            memory: "2Gi"  # 容器资源请求
            cpu: "1"
          limits:
            memory: "4Gi"  # 容器资源限制
            cpu: "2"
        volumeMounts:
        - name: localtime
          mountPath: /etc/localtime  # 时间同步挂载
      volumes:
      - name: localtime
        hostPath:
          path: /etc/localtime  # 宿主机时间路径
EOF
```

```shell
cat > ~/prd-yml/prd-vue-Service.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: prd-vue-svc-canary
  namespace: prd
  labels:
    app: prd-vue
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: prd-vue

---
apiVersion: v1
kind: Service
metadata:
  name: prd-vue-svc-stable
  namespace: prd
  labels:
    app: prd-vue
spec:
  type: ClusterIP
  ports:
  - port: 80
    targetPort: http
    protocol: TCP
    name: http
  selector:
    app: prd-vue
EOF
```

```shell
cat > ~/prd-yml/prd-vue-vsvc.yml << 'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: prd-vue-vsvc
  namespace: prd
spec:
  gateways:
  - prd-vue-gateway
  hosts:
  - "prd-vue-100.huanghuanhui.cloud"
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
cat > ~/prd-yml/prd-vue-Gateway.yml << 'EOF'
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: prd-vue-gateway
  namespace: prd
spec:
  selector:
    istio: ingressgateway # 默认创建的 istio ingressgateway pod 有这个 Label
  servers:
  - port:
      number: 443
      name: https
      protocol: HTTPS
    hosts:
    - "prd-vue-100.huanghuanhui.cloud" # 匹配所有 host
    tls:
      mode: SIMPLE
      credentialName: prd-vue-tls-secret
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
kubectl apply -f .
```

```shell
[root@k8s-master ~/prd-yml]# kubectl describe vs prd-vue-vsvc -n prd
Name:         prd-vue-vsvc
Namespace:    prd
Labels:       <none>
Annotations:  <none>
API Version:  networking.istio.io/v1beta1
Kind:         VirtualService
Metadata:
  Creation Timestamp:  2024-02-01T07:35:08Z
  Generation:          1
  Resource Version:    120501
  UID:                 729ae4d5-bda9-466f-a79a-8053096dc933
Spec:
  Gateways:
    prd-vue-gateway
  Hosts:
    prd-vue-100.huanghuanhui.cloud
  Http:
    Name:  primary
    Route:
      Destination:
        Host:  prd-vue-svc-stable
      Weight:  100  # stable版本的流量永远100%
      Destination:
        Host:  prd-vue-svc-canary
      Weight:  0    # 默认写法即可
Events:        <none>
```

```shell
kubectl-argo-rollouts set image prd-vue '*=ccr.ccs.tencentyun.com/huanghuanhui/helloworld:canary' -n prd

kubectl-argo-rollouts set image prd-vue '*=ccr.ccs.tencentyun.com/huanghuanhui/helloworld:stable' -n prd

kubectl argo rollouts get rollout prd-vue
```

```shell
[root@k8s-master ~/prd-yml]# kubectl describe vs prd-vue-vsvc -n prd
Name:         prd-vue-vsvc
Namespace:    prd
Labels:       <none>
Annotations:  <none>
API Version:  networking.istio.io/v1beta1
Kind:         VirtualService
Metadata:
  Creation Timestamp:  2024-02-01T07:35:08Z
  Generation:          2
  Resource Version:    122479
  UID:                 729ae4d5-bda9-466f-a79a-8053096dc933
Spec:
  Gateways:
    prd-vue-gateway
  Hosts:
    prd-vue-100.huanghuanhui.cloud
  Http:
    Match:
      Headers:
        X - Canary:
          Exact:  test-user
    Name:         header-route-1
    Route:
      Destination:
        Host:  prd-vue-svc-canary
      Weight:  100  # 当有canary版本发布，流量也到达100%，不过这个流量只能带请求头的访问，当canary确认没问题为stable版本，这个weight会自动删掉
    Name:      primary
    Route:
      Destination:
        Host:  prd-vue-svc-stable
      Weight:  100  # stable版本的流量永远100%
      Destination:
        Host:  prd-vue-svc-canary
      Weight:  0    # 默认写法即可
Events:        <none>
```

```shell
[root@k8s-master ~/prd-yml]# po -owide
NAME                       READY   STATUS    RESTARTS   AGE     IP               NODE        NOMINATED NODE   READINESS GATES
prd-vue-6c67966759-tbmq4   1/1     Running   0          11m     10.244.107.228   k8s-node3   <none>           <none>
prd-vue-6c67966759-vc8fd   1/1     Running   0          11m     10.244.36.80     k8s-node1   <none>           <none>
prd-vue-6c67966759-xfq6k   1/1     Running   0          11m     10.244.169.155   k8s-node2   <none>           <none>
prd-vue-86c74f4f64-hv9rl   1/1     Running   0          2m11s   10.244.169.156   k8s-node2   <none>           <none>
[root@k8s-master ~/prd-yml]# kubectl describe svc prd-vue-svc-stable
Name:              prd-vue-svc-stable
Namespace:         prd
Labels:            app=prd-vue
Annotations:       argo-rollouts.argoproj.io/managed-by-rollouts: prd-vue
Selector:          app=prd-vue,rollouts-pod-template-hash=6c67966759
Type:              ClusterIP
IP Family Policy:  SingleStack
IP Families:       IPv4
IP:                10.100.41.182
IPs:               10.100.41.182
Port:              http  80/TCP
TargetPort:        http/TCP
Endpoints:         10.244.107.228:80,10.244.169.155:80,10.244.36.80:80
Session Affinity:  None
Events:            <none>
[root@k8s-master ~/prd-yml]# kubectl describe svc prd-vue-svc-canary
Name:              prd-vue-svc-canary
Namespace:         prd
Labels:            app=prd-vue
Annotations:       argo-rollouts.argoproj.io/managed-by-rollouts: prd-vue
Selector:          app=prd-vue,rollouts-pod-template-hash=86c74f4f64
Type:              ClusterIP
IP Family Policy:  SingleStack
IP Families:       IPv4
IP:                10.102.36.192
IPs:               10.102.36.192
Port:              http  80/TCP
TargetPort:        http/TCP
Endpoints:         10.244.169.156:80
Session Affinity:  None
Events:            <none>
[root@k8s-master ~/prd-yml]#
```

```shell
curl https://prd-vue-100.huanghuanhui.cloud

curl -H "header-route-1: test-user" -H "X-canary: test-user" https://prd-vue-100.huanghuanhui.cloud
```

```shell
for i in {1..10}; do
  curl https://prd-vue-100.huanghuanhui.cloud
  sleep 1
done


for i in {1..10}; do
  curl -H "header-route-1: test-user" -H "X-canary: test-user" https://prd-vue-100.huanghuanhui.cloud
  sleep 1
done
```

```shell
[root@k8s-master ~/prd-yml]# for i in {1..10}; do
>   curl https://prd-vue-100.huanghuanhui.cloud
>   sleep 1
> done
This is a stable version !!!
This is a stable version !!!
This is a stable version !!!
This is a stable version !!!
This is a stable version !!!
This is a stable version !!!
This is a stable version !!!
This is a stable version !!!
This is a stable version !!!
This is a stable version !!!
[root@k8s-master ~/prd-yml]# for i in {1..10}; do
>   curl -H "header-route-1: test-user" -H "X-canary: test-user" https://prd-vue-100.huanghuanhui.cloud
>   sleep 1
> done
This is a canary version !!!
This is a canary version !!!
This is a canary version !!!
This is a canary version !!!
This is a canary version !!!
This is a canary version !!!
This is a canary version !!!
This is a canary version !!!
This is a canary version !!!
This is a canary version !!!
[root@k8s-master ~/prd-yml]#
```

