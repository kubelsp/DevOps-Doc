###### k8s 部署 cert-manager

> https://github.com/cert-manager/cert-manager
>
> k8s版本：k8s-v1.30.3

`````shell
mkdir -p  ~/cert-manager-yml

kubectl create ns cert-manager
`````

````shell
# wget https://github.com/cert-manager/cert-manager/releases/download/v1.16.1/cert-manager.yaml
 
wget https://ghp.ci/https://github.com/cert-manager/cert-manager/releases/download/v1.16.1/cert-manager.yaml
````

```shell
kubectl apply -f ~/cert-manager-yml/cert-manager.yaml
```

###### 基于 HTTP-01 校验方式签发证书

> 前提：
>
> 1、域名解析公网
>
> 2、ingress-nginx 配合校验，添加上 cert-manager 的相关注解即可
>
> 
>
> `Issuer` 是命名空间级别的资源，用于在命名空间内颁发证书
>
> `ClusterIssuer` 是集群级别的资源，用于在整个集群内颁发证书

````shell
cat > ~/cert-manager-yml/prod-issuer.yml << 'EOF'
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: prod-issuer
spec:
  acme:
    email: hhh@qq.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: prod-issuer-account-key
    solvers:
    - http01:
       ingress:
         class: nginx
EOF
````

`ingress-nginx 配合校验，添加上 cert-manager 的相关注解即可`

````shell
cat > ~/nginx-yml/nginx-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: nginx
  annotations:
    cert-manager.io/cluster-issuer: prod-issuer 
    acme.cert-manager.io/http01-edit-in-place: "true" 
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
````

