###### k8s手撕yml方式

> 适合开发、测试、生产环境

````shell
mkdir -p ~/minio-yml

kubectl create ns minio
````

````shell
cat > ~/minio-yml/minio-StatefulSet.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: minio
  namespace: minio
  labels:
    app: minio
spec:
  serviceName: "minio-headless"
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
    spec:
      containers:
      - name: minio
        image: ccr.ccs.tencentyun.com/huanghuanhui/minio:RELEASE.2024-08-03T04-33-23Z
        imagePullPolicy: IfNotPresent
        command:
        - /bin/bash
        - -c
        args: 
        - minio server /data --console-address :9001
        env:
        - name: MINIO_ROOT_USER
          value: "admin"
        - name: MINIO_ROOT_PASSWORD
          value: "Admin@2024"
        ports:
        - name: http
          containerPort: 9000
          protocol: TCP
        - name: console
          containerPort: 9001
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /minio/health/live
            port: 9000
          initialDelaySeconds: 30
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /minio/health/ready
            port: 9000
          initialDelaySeconds: 30
          periodSeconds: 10
        volumeMounts:
        - name: minio-data-pvc
          mountPath: /data
        - name: localtime
          mountPath: /etc/localtime
          readOnly: true
      volumes:
      - name: localtime
        hostPath:
          path: /etc/localtime 
  volumeClaimTemplates:
  - metadata:
      name: minio-data-pvc
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "nfs-storage"
      resources:
        requests:
          storage: 2Ti
EOF
````

````shell
kubectl apply -f ~/minio-yml/minio-StatefulSet.yml
````

````shell
cat > ~/minio-yml/minio-Service.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: minio-headless
  namespace: minio
  labels:
    app: minio
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - name: http
    port: 9000
    targetPort: 9000
    protocol: TCP
  - name: console
    port: 9001
    targetPort: 9001
    protocol: TCP
  selector:
    app: minio

---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: minio
spec:
  type: NodePort
  ports:
  - name: http
    port: 9000
    targetPort: 9000
    protocol: TCP
    nodePort: 30090
  - name: console
    port: 9001
    targetPort: 9001
    protocol: TCP
    nodePort: 30091
  selector:
    app: minio
EOF
````

```shell
kubectl apply -f ~/minio-yml/minio-Service.yml
```

````shell
cat > ~/minio-yml/minio-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minio-console-ingress
  namespace: minio
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: minio-console.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: minio
            port:
              number: 9001
  - host: minio-api.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: minio
            port:
              number: 9000

  tls:
  - hosts:
    - minio-console.openhhh.com
    secretName: minio-ingress-tls
EOF
````

```shell
kubectl create secret -n minio \
tls minio-ingress-tls \
--key=/root/ssl/openhhh.com.key \
--cert=/root/ssl/openhhh.com.crt
```

```shell
kubectl apply -f ~/minio-yml/minio-Ingress.yml
```

> 控制台访问地址：minio-console.openhhh.com
>
> 账号密码：admin、Admin@2024
>
> 数据访问地址：minio.openhhh.com、webstatic.openhhh.com、uploadstatic.openhhh.com

