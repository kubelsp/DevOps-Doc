###### 

````shell
helm repo add traefik https://traefik.github.io/charts

````

```shell
cat > values-prod.yaml << EOF
deployment:
  replicas: 3
service:  
  enabled: true
  type: NodePort
metrics:
  addInternals: true
  prometheus:
    service:
      enabled: true
additionalArguments:
  - "--api.insecure"   # 添加此参数以启用API的非安全访问
EOF
```

```shell
kubectl create ns traefik

helm upgrade --install --namespace traefik traefik -f ./values-prod.yaml .
```

