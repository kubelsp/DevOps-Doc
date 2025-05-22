```shell
mkdir -p ~/docker-dind-clash-yml

kubectl create ns docker
```

```shell
cat > ~/docker-dind-clash-yml/docker-dind-clash.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: docker-dind-clash
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
        env:
        - name: http_proxy
          value: "http://127.0.0.1:7890"
        - name: https_proxy
          value: "http://127.0.0.1:7890"
        - name: all_proxy
          value: "socks5://127.0.0.1:7890"
        volumeMounts:
        - name: docker-socket
          mountPath: /var/run
      - name: dockerd
        image: ccr.ccs.tencentyun.com/huanghuanhui/docker:27.1.1-dind
        imagePullPolicy: IfNotPresent
        securityContext:
          privileged: true
        env:
        - name: http_proxy
          value: "http://127.0.0.1:7890"
        - name: https_proxy
          value: "http://127.0.0.1:7890"
        - name: all_proxy
          value: "socks5://127.0.0.1:7890"
        volumeMounts:
        - name: docker-socket
          mountPath: /var/run
      - image: ccr.ccs.tencentyun.com/huanghuanhui/alpine:3.19.0-clash
        imagePullPolicy: Always
        name: clash
        ports:
        - containerPort: 7890
          protocol: TCP
        env:
        - name: http_proxy
          value: "http://127.0.0.1:7890"
        - name: https_proxy
          value: "http://127.0.0.1:7890"
        - name: all_proxy
          value: "socks5://127.0.0.1:7890"
        volumeMounts:
        - mountPath: /root/clash/config.yaml
          name: clash-config
          subPath: config.yaml
      volumes:
      - name: docker-socket
        emptyDir: {}
      - configMap:
          defaultMode: 420
          name: clash-configmap
        name: clash-config
EOF
```

```shell
# 文件名：clash-configmap.yml

kubectl create configmap clash-configmap --from-file=config.yaml=clash-configmap.yml
```

```shell
kubectl apply -f ~/docker-dind-clash-yml/docker-dind-clash.yml
```

````shell
cat > Dockerfile << 'EOF'
FROM ccr.ccs.tencentyun.com/huanghuanhui/alpine:3.19.0

RUN mkdir ~/clash && \
    sed -i 's/dl-cdn.alpinelinux.org/mirrors.cloud.tencent.com/g' /etc/apk/repositories && \
    apk update && \
    apk add curl

ADD clash /usr/local/bin/clash

ADD Country.mmdb /root/clash/Country.mmdb
# ADD config.yaml root/clash/config.yaml

CMD ["sh", "-c", "cd /root/clash && clash -d ."]
EOF
````

