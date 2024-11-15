### 13、gitlab

> 4c8g、100g

docker安装gitlab（使用k8s的ingress暴露）

版本：https://gitlab.com/gitlab-org/gitlab-foss/-/tags?sort=version_desc

官方docker仓库：https://hub.docker.com/r/gitlab/gitlab-ce/tags

```shell
docker pull gitlab/gitlab-ce:17.2.1-ce.0

docker pull ccr.ccs.tencentyun.com/huanghuanhui/gitlab:17.2.1-ce.0
```

```shell
cd && mkdir gitlab && cd gitlab && export GITLAB_HOME=/root/gitlab
```

```shell
docker run -d \
--name gitlab \
--hostname 'gitlab.openhhh.com' \
--restart always \
--privileged=true \
-p 9797:80 \
-v $GITLAB_HOME/config:/etc/gitlab \
-v $GITLAB_HOME/logs:/var/log/gitlab \
-v $GITLAB_HOME/data:/var/opt/gitlab \
-e TIME_ZONE='Asia/Shanghai' \
ccr.ccs.tencentyun.com/huanghuanhui/gitlab:17.2.1-ce.0
```

初始化默认密码：

```shell
docker exec -it gitlab grep 'Password:' /etc/gitlab/initial_root_password
```

使用k8s的ingress暴露

```shell
mkdir -p ~/gitlab-yml

kubectl create ns gitlab
```

```shell
cat > ~/gitlab-yml/gitlab-endpoints.yml << 'EOF'
apiVersion: v1
kind: Endpoints
metadata:
  name: gitlab-service
  namespace: gitlab
subsets:
  - addresses:
      - ip: 192.168.1.10
    ports:
      - port: 9797
EOF
```

```shell
kubectl apply -f ~/gitlab-yml/gitlab-endpoints.yml
```

```shell
cat > ~/gitlab-yml/gitlab-Service.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: gitlab-service
  namespace: gitlab
spec:
  ports:
    - protocol: TCP
      port: 80
      targetPort: 9797
EOF
```

```shell
kubectl apply -f ~/gitlab-yml/gitlab-Service.yml
```

```shell
cat > ~/gitlab-yml/gitlab-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gitlab-ingress
  namespace: gitlab
  annotations:
    cert-manager.io/cluster-issuer: prod-issuer 
    acme.cert-manager.io/http01-edit-in-place: "true" 
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: gitlab.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: gitlab-service
            port:
              number: 80

  tls:
  - hosts:
    - gitlab.openhhh.com
    secretName: gitlab-ingress-tls
EOF
```

```shell
kubectl create secret -n gitlab \
tls gitlab-ingress-tls \
--key=/root/ssl/openhhh.com.key \
--cert=/root/ssl/openhhh.com.pem
```

```shell
kubectl apply -f ~/gitlab-yml/gitlab-Ingress.yml
```

> 访问地址：https://gitlab.openhhh.com
>
> 设置账号密码为：root、huanghuanhui@2024

###### 计划任务备份

```shell
[root@gitlab ~]# crontab -l
0 0 * * * sync && echo 3 > /proc/sys/vm/drop_caches
0 0 * * * docker exec -t gitlab gitlab-backup create
```

