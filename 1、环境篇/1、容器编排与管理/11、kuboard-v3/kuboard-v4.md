```shell
cat > kuboard-mysql.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kuboard-mysql
  namespace: kuboard
spec:
  serviceName: kuboard-mysql-headless
  replicas: 1
  selector:
    matchLabels:
      app: kuboard-mysql
  template:
    metadata:
      labels:
        app: kuboard-mysql
    spec:
      #nodeSelector:
        #nacos: nacos
      #tolerations:
      #- effect: NoSchedule
        #key: nacos
        #operator: Equal
        #value: nacos
      containers:
      - name: mysql
        image: mysql:8.0.44
        imagePullPolicy: IfNotPresent
        #resources:
          #limits:
            #cpu: "2"
            #memory: "4Gi"
          #requests:
            #cpu: "2"
            #memory: "4Gi"
        ports:
        - name: kuboard-mysql
          containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "Admin@2026"
        - name: MYSQL_DATABASE
          value: "kuboard"
        - name: MYSQL_USER
          value: "kuboard"
        - name: MYSQL_PASSWORD
          value: "kuboard@2026"
        volumeMounts:
        - name: kuboard-mysql-data-pvc
          mountPath: /var/lib/mysql
        - mountPath: /etc/localtime
          name: localtime
        securityContext:
          runAsGroup: 1000
          runAsUser: 1000
      volumes:
      - name: localtime
        hostPath:
          path: /etc/localtime
  volumeClaimTemplates:
  - metadata:
      name: kuboard-mysql-data-pvc
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: efs-sc
      resources:
        requests:
          storage: 2Ti

---
apiVersion: v1
kind: Service
metadata:
  name: kuboard-mysql-headless
  namespace: kuboard
  labels:
    app: kuboard-mysql
spec:
  clusterIP: None
  ports:
  - port: 3306
    name: kuboard-mysql
    targetPort: 3306
  selector:
    app: kuboard-mysql
EOF
```

```shell
cat > kuboard-v4.yml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: kuboard
  namespace: kuboard
spec:
  replicas: 1
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: kuboard
  template:
    metadata:
      labels:
        app: kuboard
    spec:
      containers:
        - name: kuboard
          image: swr.cn-east-2.myhuaweicloud.com/kuboard/kuboard:v4
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 80
          env:
            - name: TZ
              value: "Asia/Shanghai"
            - name: DB_DRIVER
              value: "com.mysql.cj.jdbc.Driver"
            - name: DB_URL
              value: "jdbc:mysql://kuboard-mysql-headless:3306/kuboard?serverTimezone=Asia/Shanghai&useSSL=false&characterEncoding=utf8&allowPublicKeyRetrieval=true"
            - name: DB_USERNAME
              value: "kuboard"
            - name: DB_PASSWORD
              value: "kuboard@2026"
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause:
            duration: 30s
        - setWeight: 50
        - pause:
            duration: 60s
        - setWeight: 100
---
apiVersion: v1
kind: Service
metadata:
  name: kuboard
  namespace: kuboard
spec:
  type: ClusterIP
  selector:
    app: kuboard
  ports:
    - port: 80
      targetPort: 80
EOF
```

```shell
cat > kuboard-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kuboard-ingress
  namespace: kuboard
  annotations:
    cert-manager.io/cluster-issuer: prod-issuer 
    acme.cert-manager.io/http01-edit-in-place: "true" 
    nginx.ingress.kubernetes.io/ssl-redirect: 'false'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: kuboard-idn.transafe.co
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kuboard
            port:
              number: 80

  tls:
  - hosts:
    - kuboard-idn.transafe.co
    secretName: kuboard-ingress-tls
EOF
```

