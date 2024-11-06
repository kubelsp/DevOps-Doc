## k8s部署YApi

```shell
cat > yapi-mongo.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mongodb
  namespace: yapi
spec:
  replicas: 1
  serviceName: mongodb-headless
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: mongodb
              topologyKey: kubernetes.io/hostname
      containers:
      - name: mongodb
        image: mongo:7.0.3-rc1
        imagePullPolicy: IfNotPresent
        env:
          - name: MONGO_INITDB_ROOT_USERNAME
            value: yapi
          - name: MONGO_INITDB_ROOT_PASSWORD
            value: 'yapi@2024'
          - name: MONGO_INITDB_DATABASE
            value: "yapi"
        ports:
          - containerPort: 27017
        volumeMounts:
          - name: mongo-data
            mountPath: /data/db
          - mountPath: /etc/localtime
            name: localtime
      volumes:
        - name: mongo-data
          persistentVolumeClaim:
            claimName: mongodb-pvc
        - name: localtime
          hostPath:
            path: /etc/localtime
  volumeClaimTemplates:
  - metadata:
      name: mongo-data
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
  name: mongodb-headless
  namespace: yapi
  labels:
    app: mongodb
spec:
  clusterIP: None
  ports:
    - port: 27017
      name: mongodb
      targetPort: 27017
  selector:
    app: mongodb
EOF
```

```shell
cat > yapi.yml << 'EOF'
kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    app: yapi
  name: yapi
spec:
  selector:
    matchLabels:
      app: yapi
  template:
    metadata:
      labels:
        app: yapi
    spec:
      restartPolicy: Always
      containers:
        - image: jayfong/yapi:1.10.2
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 3000
          name: yapi
          env:
            #管理员账号,禁止注册,默认密码： ymfe.org 登录请修改
            - name: YAPI_ADMIN_ACCOUNT
              value: "admin@qq.com"
            - name: YAPI_ADMIN_PASSWORD
              value: "Admin@2024"
            - name: YAPI_CLOSE_REGISTER
              value: "true"
            #mongodb 配置
            - name: YAPI_DB_SERVERNAME
              value: "mongodb-headless.yapi.svc.cluster.local"
            - name: YAPI_DB_PORT
              value: "27017"
            - name: YAPI_DB_DATABASE
              value: "yapi"
            - name: YAPI_DB_USER
              value: "yapi"
            - name: YAPI_DB_PASS
              value: "yapi@2024"
            - name: YAPI_DB_AUTH_SOURCE
              value: "admin"
            #mail 邮件功能
            - name: YAPI_MAIL_ENABLE
              value: "true"
            - name: YAPI_MAIL_HOST
              value: "smtp.exmail.qq.com"
            - name: YAPI_MAIL_PORT
              value: "465"
            - name: YAPI_MAIL_FROM
              value: "admin@qq.com"
            - name: YAPI_MAIL_AUTH_USER
              value: "your_mail_username" # Replace with your mail username
            - name: YAPI_MAIL_AUTH_PASS
              value: "your_mail_password" # Replace with your mail password
            #ldap 功能
            - name: YAPI_LDAP_LOGIN_ENABLE
              value: "false"
      initContainers:
      - name: init-mongo
        image: busybox
        imagePullPolicy: IfNotPresent
        command: ['sh', '-c', 'until nslookup mongodb-headless.yapi.svc.cluster.local; do echo waiting for mongo; sleep 2; done;']

---
apiVersion: v1
kind: Service
metadata:
  name: yapi
spec:
  type: NodePort
  selector:
    app: yapi
  ports:
  - protocol: TCP
    port: 3000
    nodePort: 30003
EOF
```

> 访问地址：192.168.1.200:30003
>
> 账号名："admin@qq.com"，密码："Admin@2024"
