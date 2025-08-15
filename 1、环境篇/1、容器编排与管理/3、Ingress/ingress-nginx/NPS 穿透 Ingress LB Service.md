###### NPS 穿透 Ingress LB Service

假设：

- **域名**：example.com
- **公网 NPS 服务器 IP**：8.8.8.8
- **Ingress Controller SVC 名**：ingress-nginx-controller
- **Namespace**：ingress-nginx
- **LB Service 类型**：LoadBalancer，暴露端口 80

你要做的就是：

1. 让域名解析到公网 NPS 服务器 8.8.8.8
2. 在公网 NPS 上创建 HTTP 代理，把外部的 80 端口请求转发到本地集群 Ingress Controller 的 80 端口

### 操作步骤

### 1、公网 VPS 安装 NPS 服务端

````shell
````

###### 2、本地 K8s 部署 NPS 客户端 Pod

你可以直接在集群跑 NPS 客户端，让它连公网 NPS 服务器：

````shell
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nps-client
  namespace: ingress-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nps-client
  template:
    metadata:
      labels:
        app: nps-client
    spec:
      containers:
      - name: npc
        #image: ffdfgdfg/npc:latest
        image: ccr.ccs.tencentyun.com/huanghuanhui/npc:v0.26.10
        args: ["-server=8.8.8.8:8024", "-vkey=your-vkey"]
````

###### 3、NPS 服务端创建 HTTP 穿透规则

在 NPS Web 控制台：

- 类型：HTTP
- 域名：example.com
- 目标地址：ingress-nginx-controller.ingress-nginx.svc.cluster.local:80

这样：

1. 外部 CA 访问 http://example.com
2. 请求到达公网 NPS
3. NPS 通过内网穿透连接到你本地 K8s
4. 请求被转发到 Ingress Controller LB Service
5. cert-manager 的 HTTP-01 验证 Pod 返回 token
6. CA 校验通过 → 签发证书

````shell
cat > npc-config.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: npc-config
  namespace: internal-ingress-nginx
data:
  npc.conf: |
    [common]
    server_addr=193.112.118.79:8024
    conn_type=tcp
    vkey=123
    auto_reconnection=true
    max_conn=1000
    flow_limit=1000
    rate_limit=1000
    basic_username=11
    basic_password=3
    web_username=user
    web_password=1234
    crypt=true
    compress=true
    #pprof_addr=0.0.0.0:9999
    disconnect_timeout=60

    [tcp-ingress-nginx-80]
    mode=tcp
    target_addr=10.1.14.32:80
    server_port=80

    [tcp-ingress-nginx-443]
    mode=tcp
    target_addr=10.1.14.32:443
    server_port=443
EOF
````

```shell
cat > npc.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: npc
  namespace: internal-ingress-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app: npc
  template:
    metadata:
      labels:
        app: npc
    spec:
      containers:
      - name: npc
        #image: ffdfgdfg/npc:latest
        image: ccr.ccs.tencentyun.com/huanghuanhui/npc:v0.26.10
        volumeMounts:
        - name: npc-config
          mountPath: /conf/npc.conf
          subPath: npc.conf
      volumes:
      - name: npc-config
        configMap:
          name: npc-config
EOF
```

