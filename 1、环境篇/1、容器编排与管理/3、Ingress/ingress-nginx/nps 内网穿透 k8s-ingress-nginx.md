### nps  内网穿透 k8s-ingress-nginx

###### 目的：k8s内网穿透（本地k8s集群通过ingress暴露的域名可以公网访问，并且免费自动申请证书）

https://github.com/ehang-io/nps

假设：

- **域名**：ingress.openhhh.com
- **公网 nps 服务器 IP**：193.112.118.79
- **Ingress Controller SVC 名**：ingress-nginx-controller
- **Namespace**：ingress-nginx
- **LB Service 类型**：LoadBalancer，暴露端口 80、443

你要做的就是：

1. 让域名解析到公网 NPS 服务器 193.112.118.79
2. 在公网 NPS 上创建 HTTP 代理，请求公网的 80、443 端口请求转发到本地集群 Ingress Controller 的 80、443 端口



###### 本地环境组成：metallb + ingress-nginx + cert-manager

1、metallb的ip池

````shell
# kubectl get IPAddressPool -n metallb-system
NAME      AUTO ASSIGN   AVOID BUGGY IPS   ADDRESSES
default   true          false             ["192.168.1.100-192.168.1.172"]
````

2、ingress-nginx的svc

````shell
svc
NAME                                 TYPE           CLUSTER-IP       EXTERNAL-IP                                                                   PORT(S)                      AGE
ingress-nginx-controller             LoadBalancer   172.20.9.148     192.168.1.100   80:32052/TCP,443:30087/TCP   8m27s
ingress-nginx-controller-admission   ClusterIP      172.20.246.218   <none>                                                                        443/TCP                      3m27s
ingress-nginx-controller-metrics     ClusterIP      172.20.44.10     <none>                                                                        10254/TCP                    3m27s
ingress-nginx-defaultbackend         ClusterIP      172.20.156.53    <none>                                                                        80/TCP                       3m27s
````

3、cert-manager的pod

````shell
po
NAME                                       READY   STATUS    RESTARTS   AGE
cert-manager-84f7d8bf7b-jcnm2              1/1     Running   0          8m27s
cert-manager-cainjector-868789bf8f-gfddm   1/1     Running   0          8m27s
cert-manager-webhook-56f8b8f596-8wlq5      1/1     Running   0          8m27s
````



### 操作步骤

###### 1、公网服务器安装 nps 服务端

````shell
touch clients.json hosts.json tasks.json
````

````shell
cat > nps.conf << 'EOF'
appname = nps
#Boot mode(dev|pro)
runmode = dev

#HTTP(S) proxy port, no startup if empty
http_proxy_ip=0.0.0.0
http_proxy_port=90
https_proxy_port=9443
https_just_proxy=true
#default https certificate setting
https_default_cert_file=conf/server.pem
https_default_key_file=conf/server.key

##bridge
bridge_type=tcp
bridge_port=8024
bridge_ip=0.0.0.0

# Public password, which clients can use to connect to the server
# After the connection, the server will be able to open relevant ports and parse related domain names according to its own configuration file.
public_vkey=123

#Traffic data persistence interval(minute)
#Ignorance means no persistence
#flow_store_interval=1

# log level LevelEmergency->0  LevelAlert->1 LevelCritical->2 LevelError->3 LevelWarning->4 LevelNotice->5 LevelInformational->6 LevelDebug->7
log_level=7
#log_path=nps.log

#Whether to restrict IP access, true or false or ignore
#ip_limit=true

#p2p
#p2p_ip=127.0.0.1
#p2p_port=6000

#web
web_host=a.o.com
web_username=admin
web_password=Admin@2025
web_port = 6080
web_ip=0.0.0.0
web_base_url=
web_open_ssl=false
web_cert_file=conf/server.pem
web_key_file=conf/server.key
# if web under proxy use sub path. like http://host/nps need this.
#web_base_url=/nps

#Web API unauthenticated IP address(the len of auth_crypt_key must be 16)
#Remove comments if needed
#auth_key=test
auth_crypt_key =1234567812345678

#allow_ports=9001-9009,10001,11000-12000

#Web management multi-user login
allow_user_login=false
allow_user_register=false
allow_user_change_username=false


#extension
allow_flow_limit=false
allow_rate_limit=false
allow_tunnel_num_limit=false
allow_local_proxy=false
allow_connection_num_limit=false
allow_multi_ip=false
system_info_display=false

#cache
http_cache=false
http_cache_length=100

#get origin ip
http_add_origin_header=false

#pprof debug options
#pprof_ip=0.0.0.0
#pprof_port=9999

#client disconnect timeout
disconnect_timeout=60
EOF
````

````shell
chmod +x nps.conf
````

````shell
# ffdfgdfg/nps:v0.26.10

docker run -d --name nps --restart=always --net=host -v /root/nps/conf:/conf ccr.ccs.tencentyun.com/huanghuanhui/nps:v0.26.10
````

###### 2、本地 K8s 部署 npc 客户端 Pod

直接在本地内网k8s集群跑 npc 客户端，让它连公网 nps 服务器：

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
    target_addr=ingress-nginx-controller:80
    server_port=80

    [tcp-ingress-nginx-443]
    mode=tcp
    target_addr=ingress-nginx-controller:443
    server_port=443
EOF
````

````shell
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
        #image: ffdfgdfg/npc:v0.26.10
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
````



###### 3、NPS 服务端查看 HTTP 穿透规则

在 NPS Web 控制台：

- 客户端
- tcp 隧道



###### 实现的效果：本地k8s集群通过ingress暴露的域名可以公网访问，并且免费自动申请证书

1. 域名ingress.openhhh.com 解析公网ip 193.112.118.79 
2. 外部 CA 访问 https://ingress.openhhh.com
3. 请求到达公网 nps
4. nps 通过内网穿透连接到你本地 K8s
5. 请求被转发到 Ingress Controller LB Service
6. cert-manager 的 HTTP-01 验证 Pod 返回 token
7. CA 校验通过 → 签发证书
8. ingress.openhhh.com能暴露公网访问、并且免费自动证书

