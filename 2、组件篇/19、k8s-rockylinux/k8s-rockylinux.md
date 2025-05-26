k8s-rockylinux

````shell
mkdir -p ~/k8s-rockylinux-yml

kubectl create ns rockylinux
````

```shell
cat > ~/k8s-rockylinux-yml/k8s-rockylinux.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: k8s-rockylinux
  namespace: rockylinux
spec:
  replicas: 1
  selector:
    matchLabels:
      app: k8s-rockylinux
  template:
    metadata:
      labels:
        app: k8s-rockylinux
    spec:
      containers:
      - name: k8s-rockylinux
        #image: rockylinux/rockylinux:9.5
        image: ccr.ccs.tencentyun.com/huanghuanhui/rockylinux:9.5
        command: ["/bin/bash", "-c", "sleep infinity"]
EOF
```

```shell
kubectl apply -f ~/k8s-rockylinux-yml/k8s-rockylinux.yml
```

