###### helm安装traefik

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

````shell
cat > traefik-dashboard-svc.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: traefik-dashboard
  namespace: traefik
spec:
  ports:
  - name: traefik
    port: 8080
    protocol: TCP
    targetPort: traefik
  selector:
    app.kubernetes.io/instance: traefik-traefik
    app.kubernetes.io/name: traefik
  type: NodePort
EOF
````

