### k8s手撕yml方式安装Nginx

```shell
mkdir -p ~/nginx-yml

kubectl create ns nginx
```

```nginx
# grep -v '^\s*#' nginx.conf
# grep -v '^\s*#' conf.d/default.conf

cat > ~/nginx-yml/nginx.conf << 'EOF'
user  nginx;
worker_processes  auto;
worker_cpu_affinity auto;
worker_rlimit_nofile 65535;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;


events {
    use epoll;
    worker_connections  10240;
}


http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    server_tokens off;
    sendfile        on;
    tcp_nopush on;
    keepalive_timeout  65;
    client_max_body_size 100m;
    gzip on;
    gzip_disable "MSIE [1-6].";
    gzip_proxied any;
    gzip_min_length 1k;
    gzip_comp_level 5;
    gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;
    gzip_vary on;

  include /etc/nginx/conf.d/*.conf;
}
EOF
```

```shell
kubectl create -n nginx configmap nginx-config --from-file=/root/nginx-yml/nginx.conf
```

```shell
kubectl create configmap nginx-config \
--from-file=/root/nginx-yml/nginx.conf \
-o yaml --dry-run=client | kubectl apply -f -
```

```yaml
cat > ~/nginx-yml/nginx.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: nginx
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 1
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: nginx
              topologyKey: kubernetes.io/hostname
      containers:
      - name: nginx
        #image: nginx:1.27.0-alpine
        image: ccr.ccs.tencentyun.com/huanghuanhui/nginx:1.27.0-alpine
        ports:
        - containerPort: 80
        volumeMounts:
        - name: nginx-config
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
      volumes:
      - name: nginx-config
        configMap:
          name: nginx-config
          
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: nginx
spec:
  selector:
    app: nginx
  ports:
  - protocol: TCP
    port: 80
    targetPort: 80
    nodePort: 30080
  type: NodePort
EOF
```

```shell
kubectl apply -f ~/nginx-yml/nginx.yml
```

```shell
cat > ~/nginx-yml/nginx-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: nginx
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: nginx.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 80
  tls:
  - hosts:
    - nginx.openhhh.com
    secretName: nginx-ingress-tls
EOF

```

```shell
kubectl create secret -n nginx \
tls nginx-ingress-tls \
--key=/root/ssl/openhhh.com.key \
--cert=/root/ssl/openhhh.com.pem
```

```shell
kubectl apply -f ~/nginx-yml/nginx-Ingress.yml
```

> 访问地址：https://nginx.openhhh.com

===

### `全局配置`

```nginx
worker_processes  auto;
worker_cpu_affinity auto;
worker_rlimit_nofile 65535;
events {
	use epoll;
    worker_connections  10240;
}
```

### `http配置`

```nginx
http {
	server_tokens off; 					
	sendfile        on;
	tcp_nopush on;  				
	keepalive_timeout  60;
	client_max_body_size 100m;
	gzip on;
	gzip_disable "msie6";
	gzip_proxied any;  				    
	gzip_min_length 1k;  				
	gzip_comp_level 5;  				
	gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript;	
	gzip_vary on;						    
}
```

### `server配置`

```nginx
server {
	listen       8080;
    server_name  localhost;

	location /abc/ {
        proxy_read_timeout 240s;
        proxy_pass http://192.168.1.2:8088;
    }
}
```

