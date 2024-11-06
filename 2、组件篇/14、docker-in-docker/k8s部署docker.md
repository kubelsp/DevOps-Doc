```shell
mkdir -p ~/docker-dind-yml

kubectl create ns docker
```

```shell
cat > ~/docker-dind-yml/docker-dind.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: docker-dind
  namespace: docker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: docker-dind
  template:
    metadata:
      labels:
        app: docker-dind
    spec:
      containers:
      - name: docker
        image: ccr.ccs.tencentyun.com/huanghuanhui/docker:27.1.1
        imagePullPolicy: IfNotPresent
        readinessProbe:
          exec:
            command: [sh, -c, "ls -S /var/run/docker.sock"]
        command:
        - sleep
        args:
        - 99d
        volumeMounts:
        - name: docker-socket
          mountPath: /var/run
      - name: dockerd
        image: ccr.ccs.tencentyun.com/huanghuanhui/docker:27.1.1-dind
        imagePullPolicy: IfNotPresent
        securityContext:
          privileged: true
        volumeMounts:
        - name: docker-socket
          mountPath: /var/run
      volumes:
      - name: docker-socket
        emptyDir: {}
EOF
```

```shell
cat > ~/docker-dind-yml/docker-dind.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: docker-dind
  namespace: docker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: docker-dind
  template:
    metadata:
      labels:
        app: docker-dind
    spec:
      containers:
      - name: docker-dind
        #image: docker:27.1.1
        image: ccr.ccs.tencentyun.com/huanghuanhui/docker:27.1.1-dind
        securityContext:
          privileged: true
EOF
```

```shell
kubectl apply -f ~/docker-dind-yml/docker-dind.yml
```

```shell
sed -i 's/dl-cdn.alpinelinux.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apk/repositories
```

```shell
apk update && apk search openjdk && apk add openjdk8

apk update && apk search kubectl && apk add kubectl
```