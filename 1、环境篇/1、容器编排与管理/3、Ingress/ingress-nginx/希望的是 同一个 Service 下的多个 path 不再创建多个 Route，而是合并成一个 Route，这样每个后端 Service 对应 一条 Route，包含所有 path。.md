希望的是 **同一个 Service 下的多个 path 不再创建多个 Route，而是合并成一个 Route**，这样每个后端 Service 对应 **一条 Route，包含所有 path**。

````shell
KONG_ADMIN="http://10.1.14.17:30715"

# 先删除所有 Route
curl -s "$KONG_ADMIN/routes" | jq -r '.data[].id' | while read route_id; do
    echo "Deleting Route: $route_id"
    curl -s -X DELETE "$KONG_ADMIN/routes/$route_id"
done

# 再删除所有 Service
curl -s "$KONG_ADMIN/services" | jq -r '.data[].name' | while read svc; do
    echo "Deleting Service: $svc"
    curl -s -X DELETE "$KONG_ADMIN/services/$svc"
done
````

```shell
cat > ingress2kong.sh << 'EOF'
#!/bin/bash
# ingress2kong.sh
# 同一个 Service 下，每个 host 对应一条 Route，多个 path 合并

NAMESPACE="dev-jingsocial"
KONG_ADMIN="http://10.1.14.17:31987"
TARGET_INGRESS_CLASS="internal-nginx"

# 获取 Ingress 列表
INGRESSES=$(kubectl get ingress -n "$NAMESPACE" -o json)

mapfile -t ingress_list < <(jq -c '.items[]' <<<"$INGRESSES")

for ingress in "${ingress_list[@]}"; do
    ingress_name=$(jq -r '.metadata.name' <<<"$ingress")
    ingress_class=$(jq -r '.spec.ingressClassName' <<<"$ingress")

    if [ "$ingress_class" != "$TARGET_INGRESS_CLASS" ]; then
        echo "[SKIP] 跳过 Ingress: $ingress_name (class=$ingress_class)"
        continue
    fi

    echo "[INFO] 处理 Ingress: $ingress_name (class=$ingress_class)"

    declare -A service_paths_host  # key=service-port__host, value=array of paths

    mapfile -t rules < <(jq -c '.spec.rules[]' <<<"$ingress")
    for rule in "${rules[@]}"; do
        host=$(jq -r '.host' <<<"$rule")
        mapfile -t paths < <(jq -c '.http.paths[]' <<<"$rule")
        for path in "${paths[@]}"; do
            backend_service=$(jq -r '.backend.service.name' <<<"$path")
            backend_port=$(jq -r '.backend.service.port.number' <<<"$path")
            path_rule=$(jq -r '.path' <<<"$path")
            key="${backend_service}-${backend_port}__${host}"

            if [ -z "${service_paths_host[$key]}" ]; then
                service_paths_host[$key]="$path_rule"
            else
                service_paths_host[$key]="${service_paths_host[$key]} $path_rule"
            fi
        done
    done

    for key in "${!service_paths_host[@]}"; do
        service_port="${key%%__*}"
        host="${key##*__}"
        backend_service="${service_port%-*}"
        backend_port="${service_port##*-}"

        kong_service_name="${backend_service}-${backend_port}"
        service_url="http://${backend_service}.${NAMESPACE}.svc.cluster.local:${backend_port}"
        route_name="${kong_service_name}-route-${host//./_}"  # host中点替换下划线，保证唯一

        echo "  [INFO] 创建/确认 Service: $kong_service_name -> $service_url"
        curl -s -o /dev/null -w "%{http_code}" -X POST "$KONG_ADMIN/services" \
            --data "name=$kong_service_name" \
            --data "url=$service_url" | grep -qE "200|201|409" \
            && echo "  [OK] Service $kong_service_name 已存在或创建成功" \
            || echo "  [ERROR] Service $kong_service_name 创建失败"

        paths="${service_paths_host[$key]}"
        echo "  [INFO] 创建 Route: $route_name (host=$host, paths=[$paths])"

        curl_cmd=(curl -s -o /dev/null -w "%{http_code}" -X POST "$KONG_ADMIN/services/$kong_service_name/routes" --data "name=$route_name" --data "hosts[]=$host" --data "protocols[]=http" --data "protocols[]=https")
        for p in $paths; do
            curl_cmd+=(--data "paths[]=$p")
        done

        "${curl_cmd[@]}" | grep -qE "200|201|409" \
            && echo "  [OK] Route $route_name 已存在或创建成功" \
            || echo "  [ERROR] Route $route_name 创建失败"
    done

    unset service_paths_host
done
EOF
```

````shell
cat > jing-security-deployment.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jing-security-deployment
  namespace: security
spec:
  replicas: 1
  selector:
    matchLabels:
      app: security
  template:
    metadata:
      labels:
        app: security
    spec:
      containers:
      - name: security
        image: registry.cn-hangzhou.aliyuncs.com/jingsocial/security:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8123
          name: http
          protocol: TCP
        env:
        - name: TZ
          value: Asia/Shanghai

---
apiVersion: v1
kind: Service
metadata:
  name: jing-security-svc
  namespace: security
spec:
  selector:
    app: security
  ports:
    - protocol: TCP
      port: 8123
      targetPort: 8123
      nodePort: 30123
  type: NodePort
EOF
````

````shell
GRANT ALL PRIVILEGES ON `jing_security`.* TO 'jing_security_rw'@'%';
````



``````shell
cat > bayonet.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bayonet
  namespace: bayonet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bayonet
  template:
    metadata:
      labels:
        app: bayonet
    spec:
      containers:
      - name: bayonet
        #image: missfeng/bayonet:v1.2
        image: ccr.ccs.tencentyun.com/huanghuanhui/bayonet:v1.2
        command: ["/bin/bash", "-c", "sleep infinity"]
        ports:
        - containerPort: 80

---
apiVersion: v1
kind: Service
metadata:
  name: bayonet-svc
  namespace: bayonet
spec:
  selector:
    app: bayonet
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 30880
  type: NodePort
EOF
``````

````shell
mkdir -p ~/k8s-kalilinux-yml

kubectl create ns kalilinux
````

````shell
cat > ~/k8s-kalilinux-yml/k8s-kalilinux.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8s-kalilinux
  namespace: kalilinux
spec:
  replicas: 1
  selector:
    matchLabels:
      app: k8s-kalilinux
  template:
    metadata:
      labels:
        app: k8s-kalilinux
    spec:
      containers:
      - name: k8s-kalilinux
        #image: kalilinux/kali-rolling:latest
        image: ccr.ccs.tencentyun.com/huanghuanhui/kalilinux:latest
        command: ["/bin/bash", "-c", "sleep infinity"]
EOF
````

````shell
在 L3 网络下，Cilium 的推荐安装模式

Cilium-Overlay 模式
````

````shell
Cilium 功能
网络功能
Cilium 提供网络连接，允许 pod 和其他组件（Kubernetes 集群内部或外部）进行通信。Cilium 实现了一个简单的扁平 3 层网络，能够跨越多个集群连接所有应用容器(ClusterMesh 功能)。

默认情况下，Cilium 支持 overlay 网络模型，其中一个虚拟网络跨越所有主机。Overlay 网络中的流量经过封装，可在不同主机之间传输。之所以选择这种模式作为默认模式，是因为它对基础设施和集成的要求最低，只需要主机之间的 IP 连接。	
````

````shell
helm repo add cilium https://helm.cilium.io/

helm repo update

helm search repo cilium
````

````shell
helm upgrade --install cilium cilium/cilium --version 1.18.1 \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set ipam.mode=kubernetes \
  --set routingMode=tunnel \
  --set tunnelProtocol=vxlan \
  --set ipam.operator.clusterPoolIPv4PodCIDRList=10.244.0.0/16 \
  --set ipam.operator.clusterPoolIPv4MaskSize=24
````

```shell
helm upgrade --install cilium cilium/cilium --version 1.18.1 \
  --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set ipam.mode=kubernetes \
  --set routingMode=tunnel \
  --set tunnelProtocol=vxlan \
  --set ipam.operator.clusterPoolIPv4PodCIDRList=10.244.0.0/16 \
  --set ipam.operator.clusterPoolIPv4MaskSize=24 \
  --set operator.replicas=1
```

````shell
cat > ~/jenkins-yml/Jenkins-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jenkins-ingress
  namespace: jenkins
  annotations:
    cert-manager.io/cluster-issuer: prod-issuer 
    acme.cert-manager.io/http01-edit-in-place: "true" 
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: jenkins.wjxtzd.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: jenkins # 将所有请求发送到 jenkins 服务的 8080 端口
            port:
              number: 8080
  tls:
  - hosts:
    - jenkins.wjxtzd.com
    secretName: jenkins-ingress-tls
EOF




````



````shell
cat > mysql_backup.sh << 'EOF'
#!/bin/bash

DB_HOST=192.168.0.78
DB_PORT=30336
DB_USER=root
DB_PASS=Jya3QE7M0e
BACKUP_DIR=/root/mysql-yml/db

time=$(date +%Y_%m_%d_%H_%M_%S)
mkdir -p "$BACKUP_DIR/$time"

# 多个数据库名，每个数据库一行
databases=(
  "bi"
  "bozhu"
  "erp"
  # 添加更多的数据库名...
)

for db in "${databases[@]}"; do
  # 备份数据库
  mysqldump -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -R "$db" --set-gtid-purged=OFF | gzip > "$BACKUP_DIR/$time/$db.sql.gz"
done

# 删除一个月前的备份目录
find "$BACKUP_DIR" -type d -mtime +30 -exec rm -rf {} \; > /dev/null 2>&1
EOF
````

````shell
registry.aliyuncs.com/google_containers/kube-apiserver:v1.33.4
registry.aliyuncs.com/google_containers/kube-controller-manager:v1.33.4
registry.aliyuncs.com/google_containers/kube-scheduler:v1.33.4
registry.aliyuncs.com/google_containers/kube-proxy:v1.33.4
registry.aliyuncs.com/google_containers/coredns:v1.12.0
registry.aliyuncs.com/google_containers/pause:3.10
registry.aliyuncs.com/google_containers/etcd:3.5.21-0
````

````shell
kubectl set image deployment/prometheus 'prometheus=registry.cn-hangzhou.aliyuncs.com/jingsocial/prometheus:v2.51.2' -n monitoring


registry.cn-hangzhou.aliyuncs.com/jingsocial/prometheus:v2.51.2
````

```shell
cat > Dockerfile << 'EOF'
FROM ccr.ccs.tencentyun.com/huanghuanhui/alpine:3.19.0
ADD crictl /usr/bin/crictl
EOF
```

```shell
docker build -t registry.cn-hangzhou.aliyuncs.com/jingsocial/crictl:v1 .
docker push registry.cn-hangzhou.aliyuncs.com/jingsocial/crictl:v1
```

```shell
cat > cronjob-prune-crictl-allnodes.yml << 'eof'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prune-crictl-sa
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prune-crictl-role
rules:
- apiGroups: ["apps"]
  resources: ["daemonsets"]
  verbs: ["get","list","create","delete","update","patch"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get","list","watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prune-crictl-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prune-crictl-role
subjects:
- kind: ServiceAccount
  name: prune-crictl-sa
  namespace: kube-system
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: prune-crictl-allnodes
  namespace: kube-system
spec:
  schedule: "*/5 * * * *"  # 每天凌晨3点
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 86400  # Job 完成后24小时自动删除
      template:
        spec:
          serviceAccountName: prune-crictl-sa
          restartPolicy: OnFailure
          containers:
          - name: create-daemonset
            image: registry.cn-hangzhou.aliyuncs.com/jingsocial/kubectl:bitnami-1.32.3
            command:
            - sh
            - -c
            - |
              echo "Creating temporary DaemonSet..."
              kubectl apply -f - <<EOF
              apiVersion: apps/v1
              kind: DaemonSet
              metadata:
                name: prune-crictl
                namespace: kube-system
              spec:
                selector:
                  matchLabels:
                    app: prune-crictl
                template:
                  metadata:
                    labels:
                      app: prune-crictl
                  spec:
                    hostPID: true
                    restartPolicy: Always
                    containers:
                    - name: prune
                      image: registry.cn-hangzhou.aliyuncs.com/jingsocial/crictl:v1
                      securityContext:
                        privileged: true
                      command:
                      - sh
                      - -c
                      - |
                        echo "Start prune on node $(hostname) ..."
                        crictl rmi --prune
                        echo "Done."
                      volumeMounts:
                      - name: run-containerd
                        mountPath: /run/containerd
                      - name: lib-containerd
                        mountPath: /var/lib/containerd
                    volumes:
                    - name: run-containerd
                      hostPath:
                        path: /run/containerd
                    - name: lib-containerd
                      hostPath:
                        path: /var/lib/containerd
                    tolerations:
                    - operator: "Exists"
              EOF

              echo "Waiting for all DaemonSet pods to complete..."
              kubectl wait --for=condition=ready pod -l app=prune-crictl --timeout=120s || true
              echo "Deleting temporary DaemonSet..."
              kubectl delete ds prune-crictl -n kube-system
              echo "All done."
eof
```

```shell
registry.cn-hangzhou.aliyuncs.com/jingsocial/vault:1.14.0

registry.cn-hangzhou.aliyuncs.com/jingsocial/vault-k8s:1.2.1
```

