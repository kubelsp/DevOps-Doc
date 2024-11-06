### xxl-job-2.4.1

```shell
mkdir -p ~/xxl-job-yml

kubectl create ns xxl-job
```

```shell
cd ~/xxl-job-yml && wget https://github.com/xuxueli/xxl-job/raw/2.4.1/doc/db/tables_xxl_job.sql
```

```shell
mysql -h 192.168.1.200 -P 3306 -uroot -pAdmin@2024 < tables_xxl_job.sql
```

```shell
cat > ~/xxl-job-yml/xxl-job-admin-Deployment.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: xxl-job-admin
  namespace: xxl-job
spec:
  replicas: 3
  selector:
    matchLabels:
      app: xxl-job-admin
  template:
    metadata:
      labels:
        app: xxl-job-admin
    spec:
      containers:
      - name: xxl-job-admin
        #image: xuxueli/xxl-job-admin:2.4.1
        image: ccr.ccs.tencentyun.com/huanghuanhui/xxl-job-admin:2.4.1
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
        volumeMounts:
        - mountPath: /etc/localtime
          name: localtime
        env:
        - name: PARAMS
          value: "--spring.datasource.url=jdbc:mysql://192.168.1.200:3306/xxl_job?Unicode=true&characterEncoding=UTF-8&useSSL=false --spring.datasource.username=root --spring.datasource.password=Admin@2024"
      volumes:
      - name: localtime
        hostPath:
          path: /etc/localtime
EOF
```

```shell
kubectl apply -f ~/xxl-job-yml/xxl-job-admin-Deployment.yml
```

```shell
cat > ~/xxl-job-yml/xxl-job-admin-Service.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: xxl-job-admin-service
  namespace: xxl-job
  labels:
    app: xxl-job-admin
spec:
  type: NodePort
  ports:
  - port: 8080
    protocol: TCP
    name: http
    nodePort: 30008
  selector:
    app: xxl-job-admin
EOF
```

```shell
kubectl apply -f ~/xxl-job-yml/xxl-job-admin-Service.yml
```

```shell
cat > ~/xxl-job-yml/xxl-job-admin-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: xxl-job-admin-ingress
  namespace: xxl-job
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: xxl-job-admin.huanghuanhui.cloud
    http:
      paths:
      - path: /xxl-job-admin
        pathType: Prefix
        backend:
          service:
            name: xxl-job-admin-service
            port:
              number: 8080
  tls:
  - hosts:
    - www.huanghuanhui.cloud
    secretName: xxl-job-admin-ingress-tls
EOF
```

```shell
kubectl create secret -n xxl-job \
tls xxl-job-admin-ingress-tls \
--key=/root/ssl/huanghuanhui.cloud.key \
--cert=/root/ssl/huanghuanhui.cloud.crt
```

```shell
kubectl apply -f ~/xxl-job-yml/xxl-job-admin-Ingress.yml
```

> web访问地址：https://xxl-job-admin.huanghuanhui.cloud/xxl-job-admin/toLogin
>
> 默认账号密码: admin、123456
>
> 账号密码: admin、Admin@2024（登录后记得改密码）
