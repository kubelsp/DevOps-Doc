k8s-rockylinux

```shell
cat > k8s-rockylinux.yml << 'EOF'
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
        image: centos:7
        command: ["/bin/bash", "-c", "sleep infinity"]
EOF
```

