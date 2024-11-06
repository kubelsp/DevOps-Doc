### k8s手撕yml方式安装sonarqube

> k8s-v1.30.0
>
> postgres:16.2
>
> sonarqube:9.9.4-community
>
> 
>
> https://hub.docker.com/_/postgres/tags
>
> https://hub.docker.com/_/sonarqube/tags

```shell
mkdir -p ~/sonarqube-yml

kubectl create ns sonarqube
```

```shell
cat > ~/sonarqube-yml/sonarqube-postgres.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: sonarqube-postgres
  namespace: sonarqube
spec:
  replicas: 1
  serviceName: sonarqube-postgres
  selector:
    matchLabels:
      app: sonarqube-postgres
  template:
    metadata:
      labels:
        app: sonarqube-postgres
    spec:
      containers:
      - name: sonarqube-postgres
        #image: postgres:16.2
        image: ccr.ccs.tencentyun.com/huanghuanhui/postgres:16.2
        imagePullPolicy: IfNotPresent
        env:
        - name: TZ
          value: Asia/Shanghai
        - name: POSTGRES_PASSWORD
          value: "sonarqube@2024"
        - name: POSTGRES_USER
          value: "sonarqube"
        - name:  POSTGRES_DB
          value: "sonarDB"
        - name: POSTGRES_EXTENSION
          value: 'pg_trgm,btree_gist'
        ports:
        - containerPort: 5432
          name: tcp-postgres
          protocol: TCP
        resources:
          requests:
            cpu: 0.5
            memory: 2Gi
          limits:
            cpu: 2
            memory: 4Gi
        volumeMounts:
        - name: sonarqube-postgres-data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: sonarqube-postgres-data
    spec:
      storageClassName: "nfs-storage"
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 2Ti
          
---
apiVersion: v1
kind: Service
metadata:
  name: sonarqube-postgres-headless
  namespace: sonarqube
  labels:
    app: sonarqube-postgres
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - name: sonarqube-postgres
    port: 5432
    protocol: TCP
    targetPort: tcp-postgres
  selector:
    app: sonarqube-postgres
EOF
```

```shell
kubectl apply -f ~/sonarqube-yml/sonarqube-postgres.yml
```

```shell
kubectl run sonarqube-postgresql-client --rm --tty -i --restart='Never' --image=ccr.ccs.tencentyun.com/huanghuanhui/postgres:16.2 --command -- bash

PGPASSWORD=sonarqube@2024 psql -h sonarqube-postgres-headless -U sonarqube -d sonarDB

gitlab_production=# \l
gitlab_production=# \d	#第一次查看数据为空，请sonarqube初始化完成，再次查看数据
gitlab_production=# \q
```

```shell
cat > ~/sonarqube-yml/sonarqube.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sonarqube
  namespace: sonarqube
  labels:
    app: sonarqube
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sonarqube
  template:
    metadata:
      labels:
        app: sonarqube
    spec:
      containers:
      - name: sonarqube
        #image: sonarqube:9.9.4-community
        image: ccr.ccs.tencentyun.com/huanghuanhui/sonarqube:9.9.4-community
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9000
        env:
        - name: SONAR_JDBC_USERNAME
          value: "sonarqube"
        - name: SONAR_JDBC_PASSWORD
          value: "sonarqube@2024"
        - name: SONAR_JDBC_URL
          value: "jdbc:postgresql://sonarqube-postgres-headless:5432/sonarDB"
        livenessProbe:
          httpGet:
            path: /sessions/new
            port: 9000
          initialDelaySeconds: 60
          periodSeconds: 30
        readinessProbe:
          httpGet:
            path: /sessions/new
            port: 9000
          initialDelaySeconds: 60
          periodSeconds: 30
          failureThreshold: 6
        volumeMounts:
        - mountPath: /opt/sonarqube/conf
          name: data
        - mountPath: /opt/sonarqube/data
          name: data
        - mountPath: /opt/sonarqube/extensions
          name: data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: sonarqube-data 

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sonarqube-data
  namespace: sonarqube
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: "nfs-storage"
  resources:
    requests:
      storage: 2Ti
      
---
apiVersion: v1
kind: Service
metadata:
  name: sonarqube-service
  namespace: sonarqube
  labels:
    app: sonarqube
spec:
  type: NodePort
  ports:
  - name: sonarqube
    nodePort: 30009
    port: 9000
    targetPort: 9000
    protocol: TCP
  selector:
    app: sonarqube
EOF
```

> https://docs.sonarsource.com/sonarqube/latest/setup-and-upgrade/configure-and-operate-a-server/environment-variables/

```shell
kubectl apply -f ~/sonarqube-yml/sonarqube.yml
```

```shell
cat > ~/sonarqube-yml/sonarqube-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: sonarqube-ingress
  namespace: sonarqube
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: sonarqube.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: sonarqube-service
            port:
              number: 9000

  tls:
  - hosts:
    - sonarqube.openhhh.com
    secretName: sonarqube-ingress-tls
EOF
```

```shell
kubectl create secret -n sonarqube \
tls sonarqube-ingress-tls \
--key=/root/ssl/openhhh.com.key \
--cert=/root/ssl/openhhh.com.pem
```

```shell
kubectl apply -f ~/sonarqube-yml/sonarqube-Ingress.yml
```

> 访问地址：https://sonarqube.openhhh.com
>
> 用户密码：admin、admin（初始化密码）、Admin@2024
