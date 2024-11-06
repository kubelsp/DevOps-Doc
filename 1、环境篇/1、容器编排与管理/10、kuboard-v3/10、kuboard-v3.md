### 10、kuboard-v3

```shell
mkdir -p ~/kuboard-v3-yml

cat > ~/kuboard-v3-yml/kuboard-v3.yaml << 'EOF'
---
apiVersion: v1
kind: Namespace
metadata:
  name: kuboard
 
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: kuboard-v3-config
  namespace: kuboard
data:
  KUBOARD_ENDPOINT: 'http://192.168.1.200:30080'
  KUBOARD_AGENT_SERVER_TCP_PORT: '30081'

---
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    deployment.kubernetes.io/revision: '9'
    k8s.kuboard.cn/ingress: 'false'
    k8s.kuboard.cn/service: NodePort
    k8s.kuboard.cn/workload: kuboard-v3
  labels:
    k8s.kuboard.cn/name: kuboard-v3
  name: kuboard-v3
  namespace: kuboard
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s.kuboard.cn/name: kuboard-v3
  template:
    metadata:
      labels:
        k8s.kuboard.cn/name: kuboard-v3
    spec:
      containers:
        - envFrom:
            - configMapRef:
                name: kuboard-v3-config
          image: 'swr.cn-east-2.myhuaweicloud.com/kuboard/kuboard:v3'
          imagePullPolicy: IfNotPresent
          name: kuboard
          volumeMounts:
            - name: kuboard-data
              mountPath: /data
            - name: localtime
              mountPath: /etc/localtime
      volumes:
        - name: kuboard-data
          persistentVolumeClaim:
            claimName: kuboard-data
        - name: localtime
          hostPath:
            path: /etc/localtime


---
apiVersion: v1
kind:  PersistentVolumeClaim
metadata:
  name: kuboard-data
  namespace: kuboard
spec:
  storageClassName: "nfs-storage"
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 2Ti
---
apiVersion: v1
kind: Service
metadata:
  annotations:
    k8s.kuboard.cn/workload: kuboard-v3
  labels:
    k8s.kuboard.cn/name: kuboard-v3
  name: kuboard-v3
  namespace: kuboard
spec:
  ports:
    - name: webui
      nodePort: 30080
      port: 80
      protocol: TCP
      targetPort: 80
    - name: agentservertcp
      nodePort: 30081
      port: 10081
      protocol: TCP
      targetPort: 10081
    - name: agentserverudp
      nodePort: 30081
      port: 10081
      protocol: UDP
      targetPort: 10081
  selector:
    k8s.kuboard.cn/name: kuboard-v3
  sessionAffinity: None
  type: NodePort
EOF
```

```shell
 kubectl apply -f ~/kuboard-v3-yml/kuboard-v3.yaml
```

```shell
cat > ~/kuboard-v3-yml/kuboard-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kuboard-ingress
  namespace: kuboard
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: kuboard.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kuboard-v3
            port:
              number: 80

  tls:
  - hosts:
    - kuboard.openhhh.com
    secretName: kuboard-ingress-tls
EOF
```

```shell
kubectl create secret -n kuboard \
tls kuboard-ingress-tls \
--key=/root/ssl/openhhh.com.key \
--cert=/root/ssl/openhhh.com.pem
```

```shell
 kubectl apply -f ~/kuboard-v3-yml/kuboard-Ingress.yml
```

> 访问地址：https://kuboard.openhhh.com
>
> 用户密码：admin、Kuboard123