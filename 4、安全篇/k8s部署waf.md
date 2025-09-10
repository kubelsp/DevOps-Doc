k8s 部署 雷池 WAF（开源waf）

> https://waf-ce.chaitin.cn/
>
> https://github.com/chaitin/SafeLine
>
> https://help.waf-ce.chaitin.cn/node/01973fc6-e12f-789f-a8ff-e81d383c80bc

`````shell
cat > waf-postgresql.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: waf-postgres
  namespace: waf
spec:
  serviceName: waf-postgres-headless
  replicas: 1
  selector:
    matchLabels:
      app: waf-postgres
  template:
    metadata:
      labels:
        app: waf-postgres
    spec:
      containers:
      - name: waf-postgres
        image: swr.cn-east-3.myhuaweicloud.com/chaitin-safeline/safeline-postgres:15.2
        env:
        - name: TZ
          value: Asia/Shanghai
        - name: POSTGRES_PASSWORD
          value: Admin@2025
        - name: POSTGRES_USER
          value: postgres
        - name: POSTGRES_DB
          value: waf
        - name: POSTGRES_EXTENSION
          value: 'pg_trgm,btree_gist'
        ports:
        - containerPort: 5432
          name: tcp-postgres
          protocol: TCP
        volumeMounts:
        - name: waf-postgres-data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: waf-postgres-data
    spec:
      storageClassName: nfs-storage
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 2Ti
---
apiVersion: v1
kind: Service
metadata:
  name: waf-postgres-headless
  namespace: waf
  labels:
    app: waf-postgres
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - name: waf-postgres
    port: 5432
    protocol: TCP
    targetPort: tcp-postgres
  selector:
    app: waf-postgres
EOF
`````

```shell
PGPASSWORD='Admin@2025' psql -h waf-postgres-headless -p 5432  -U postgres -d waf
```

````shell
cat > waf-detect.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: waf-detect
  namespace: waf
spec:
  replicas: 1
  selector:
    matchLabels:
      app: waf-detect
  template:
    metadata:
      labels:
        app: waf-detect
    spec:
      tolerations:
      - effect: NoSchedule
        key: dolphinscheduler
        operator: Equal
        value: dolphinscheduler
      containers:
      - name: waf-detect
        image: swr.cn-east-3.myhuaweicloud.com/chaitin-safeline/safeline-detector:latest
        ports:
        - name: snserver
          containerPort: 8001
        - name: koopa
          containerPort: 7777
        env:
        - name: TCD_SNSERVER
          value: "safeline-fvm:80"
        - name: MGT_ADDR
          value: "waf-mgt:1443"
        - name: LOG_DIR
          value: "/logs/detector"
        volumeMounts:
        - mountPath: /resources/detector
          name: detect-resources
        - mountPath: /logs/detector
          name: detect-logs
      volumes:
      - name: detect-resources
        emptyDir: {}
      - name: detect-logs
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: safeline-detector
  namespace: waf
spec:
  ports:
  - name: snserver
    port: 8001
    targetPort: 8001
  - name: koopa
    port: 7777
    targetPort: 7777
  selector:
    app: waf-detect
EOF
````

```shell
cat > waf-luigi.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: waf-luigi
  namespace: waf
spec:
  replicas: 1
  selector:
    matchLabels:
      app: waf-luigi
  template:
    metadata:
      labels:
        app: waf-luigi
    spec:
      tolerations:
      - effect: NoSchedule
        key: dolphinscheduler
        operator: Equal
        value: dolphinscheduler
      containers:
      - name: waf-luigi
        image: swr.cn-east-3.myhuaweicloud.com/chaitin-safeline/safeline-luigi:latest
        env:
        - name: MGT_IP
          value: "waf-mgt.waf.svc.cluster.local"
        - name: LUIGI_PG
          value: "postgres://postgres:Admin@2025@waf-postgres-headless/waf?sslmode=disable"
        volumeMounts:
        - mountPath: /app/data
          name: luigi-data
      volumes:
      - name: luigi-data
        emptyDir: {}
EOF
```

````shell
cat > waf-fvm.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: waf-fvm
  namespace: waf
spec:
  replicas: 1
  selector:
    matchLabels:
      app: waf-fvm
  template:
    metadata:
      labels:
        app: waf-fvm
    spec:
      containers:
      - name: waf-fvm
        image: swr.cn-east-3.myhuaweicloud.com/chaitin-safeline/safeline-fvm:latest
        ports:
        - name: http
          containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: safeline-fvm
  namespace: waf
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 80
    targetPort: http
  selector:
    app: waf-fvm
EOF
````

```shell
cat > waf-chaos.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: waf-chaos
  namespace: waf
spec:
  replicas: 1
  selector:
    matchLabels:
      app: waf-chaos
  template:
    metadata:
      labels:
        app: waf-chaos
    spec:
      tolerations:
      - effect: NoSchedule
        key: dolphinscheduler
        operator: Equal
        value: dolphinscheduler
      containers:
      - name: waf-chaos
        image: swr.cn-east-3.myhuaweicloud.com/chaitin-safeline/safeline-chaos:latest
        ports:
        - name: chaos-serve
          containerPort: 9000
        - name: challenge
          containerPort: 8080
        - name: auth
          containerPort: 8088
        env:
        - name: DB_ADDR
          value: "postgres://postgres:Admin@2025@waf-postgres-headless/waf?sslmode=disable"
        volumeMounts:
        - mountPath: /app/sock
          name: chaos-sock
        - mountPath: /app/chaos
          name: chaos-resources
      volumes:
      - name: chaos-sock
        emptyDir: {}
      - name: chaos-resources
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: safeline-chaos
  namespace: waf
spec:
  type: ClusterIP
  ports:
  - name: chaos-serve
    port: 9000
    targetPort: chaos-serve
  - name: challenge
    port: 8080
    targetPort: challenge
  - name: auth
    port: 8088
    targetPort: auth
  selector:
    app: waf-chaos
EOF
```

````shell
cat > waf-tengine.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: waf-tengine
  namespace: waf
spec:
  replicas: 1
  selector:
    matchLabels:
      app: waf-tengine
  template:
    metadata:
      labels:
        app: waf-tengine
    spec:
      tolerations:
      - effect: NoSchedule
        key: dolphinscheduler
        operator: Equal
        value: dolphinscheduler
      containers:
      - name: waf-tengine
        image: swr.cn-east-3.myhuaweicloud.com/chaitin-safeline/safeline-tengine:latest
        ports:
        - name: https
          containerPort: 65443
        env:
        - name: TCD_MGT_API
          value: "https://safeline-mgt.waf.svc.cluster.local:1443/api/open/publish/server"
        - name: TCD_SNSERVER
          value: "safeline-detect.waf.svc.cluster.local:8000"
        - name: CHAOS_ADDR
          value: "safeline-chaos.waf.svc.cluster.local"
        volumeMounts:
        - mountPath: /app/sock
          name: tengine-sock
      volumes:
      - name: tengine-sock
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: safeline-tengine
  namespace: waf
spec:
  type: NodePort
  selector:
    app: waf-tengine
  ports:
  - name: https
    port: 65443
    targetPort: 65443
    nodePort: 30443
EOF
````

````shell
cat > waf-mgt.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: waf-mgt
  namespace: waf
spec:
  replicas: 1
  selector:
    matchLabels:
      app: waf-mgt
  template:
    metadata:
      labels:
        app: waf-mgt
    spec:
      tolerations:
      - effect: NoSchedule
        key: dolphinscheduler
        operator: Equal
        value: dolphinscheduler
      containers:
      - name: waf-mgt
        image: swr.cn-east-3.myhuaweicloud.com/chaitin-safeline/safeline-mgt:latest
        ports:
        - name: http
          containerPort: 80
        - name: https
          containerPort: 1443
        - name: api
          containerPort: 8000
        - name: metrics
          containerPort: 6060
        env:
        - name: MGT_PG
          value: "postgres://postgres:Admin@2025@waf-postgres-headless/waf?sslmode=disable"
        - name: POSTGRES_PASSWORD
          value: "Admin@2025"
        - name: MGT_PROXY
          value: "0"
        readinessProbe:
          httpGet:
            path: /api/open/health
            port: 1443
            scheme: HTTPS
          initialDelaySeconds: 10
          periodSeconds: 10
        volumeMounts:
        - mountPath: /app/data
          name: mgt-data
      volumes:
      - name: mgt-data
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: safeline-mgt
  namespace: waf
spec:
  type: NodePort
  ports:
  - name: https
    port: 1443
    targetPort: 1443
    nodePort: 32443
  - name: http
    port: 80
    targetPort: 80
  - name: api
    port: 8000
    targetPort: 8000
  - name: metrics
    port: 6060
    targetPort: 6060
  selector:
    app: waf-mgt
EOF
````

```shell
cat > waf-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: waf-ingress
  namespace: waf
  annotations:
    cert-manager.io/cluster-issuer: prod-issuer 
    acme.cert-manager.io/http01-edit-in-place: "true" 
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"  # 告诉 Ingress 用 HTTPS 访问后端
    # 如后端是自签名证书，可加下面这行（不推荐生产）
    # nginx.ingress.kubernetes.io/proxy-ssl-verify: "off"
spec:
  ingressClassName: nginx
  rules:
  - host: waf.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: safeline-mgt
            port:
              number: 1443  # 你的 HTTPS 服务端口
  tls:
  - hosts:
    - waf.openhhh.com
    secretName: waf-ingress-tls
EOF
```

````shell
resetadmin（在safeline-mgt -- pod运行重新初始化密码）

waf.openhhh.com admin、NZv5dq4v
````

````shell
[root@k8s-master ~/waf-yml]# kubens waf
Context "kubernetes-admin@kubernetes" modified.
Active namespace is "waf".
[root@k8s-master ~/waf-yml]# po
NAME                           READY   STATUS    RESTARTS      AGE
waf-chaos-75f5488f9b-nc95c     1/1     Running   0             48m
waf-detect-684866f78-dcxcm     1/1     Running   0             48m
waf-fvm-cdf9d7fd-jmw8l         1/1     Running   0             48m
waf-luigi-84d47f8f-dvfqw       1/1     Running   1 (47m ago)   48m
waf-mgt-94675856f-x5hfp        1/1     Running   1 (47m ago)   48m
waf-postgres-0                 1/1     Running   0             49m
waf-tengine-5cd757f8fd-wgsql   1/1     Running   0             48m
[root@k8s-master ~/waf-yml]# svc
NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                                                     AGE
safeline-chaos          ClusterIP   10.106.189.21   <none>        9000/TCP,8080/TCP,8088/TCP                                  48m
safeline-detector       ClusterIP   10.111.16.140   <none>        8001/TCP,7777/TCP                                           48m
safeline-fvm            ClusterIP   10.98.179.187   <none>        80/TCP                                                      48m
safeline-mgt            NodePort    10.99.127.158   <none>        1443:32443/TCP,80:32314/TCP,8000:30157/TCP,6060:32126/TCP   48m
safeline-tengine        NodePort    10.97.203.87    <none>        65443:30443/TCP                                             48m
waf-postgres-headless   ClusterIP   None            <none>        5432/TCP                                                    49m
[root@k8s-master ~/waf-yml]# ingress 
NAME          CLASS   HOSTS            ADDRESS    PORTS     AGE
waf-ingress   nginx   waf.openhhh.com   10.1.8.4   80, 443   41m
[root@k8s-doris ~/waf-yml]# 
````

