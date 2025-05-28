k8s-shadowsocks

```shell
mkdir -p ~/k8s-shadowsocks

kubectl create ns shadowsocks
```

````shell
cat > ~/k8s-shadowsocks/shadowsocks.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: shadowsocks
  namespace: shadowsocks
  labels:
    app: shadowsocks
spec:
  replicas: 1
  selector:
    matchLabels:
      app: shadowsocks
  template:
    metadata:
      labels:
        app: shadowsocks
    spec:
      containers:
        - name: shadowsocks-libev
          #image: shadowsocks/shadowsocks-libev:edge
          image: ccr.ccs.tencentyun.com/huanghuanhui/shadowsocks:edge
          env:
            - name: PASSWORD
              value: "rx2EjV4AsjgJJcqu"
          ports:
            - containerPort: 8388
              protocol: TCP
            - containerPort: 8388
              protocol: UDP
---
apiVersion: v1
kind: Service
metadata:
  name: shadowsocks
  namespace: shadowsocks
spec:
  selector:
    app: shadowsocks
  ports:
    - name: tcp
      protocol: TCP
      port: 8388
      targetPort: 8388
    - name: udp
      protocol: UDP
      port: 8388
      targetPort: 8388
  type: NodePort
EOF
````

```shel
kubectl apply -f ~/k8s-shadowsocks/shadowsocks.yaml
```

