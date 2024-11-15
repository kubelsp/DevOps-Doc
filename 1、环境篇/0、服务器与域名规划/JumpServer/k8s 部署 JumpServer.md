# k8s 部署 JumpServer

`1、MySQL`

> 版本：mysql-8.0.28

```shell
mkdir -p ~/jumpserver-yml

kubectl create ns jumpserver
```

```shell
cat > ~/jumpserver-yml/jumpserver-mysql.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql-config
  namespace: jumpserver
data:
  my.cnf: |
    [mysqld]
    pid-file        = /var/run/mysqld/mysqld.pid
    socket          = /var/run/mysqld/mysqld.sock
    datadir         = /var/lib/mysql
    secure-file-priv= NULL

    # Custom config should go here
    !includedir /etc/mysql/conf.d/

    # 优化配置
    # 设置最大连接数为 2500
    max_connections = 2500
    # 设置字符集为 UTF-8
    character-set-server=utf8mb4
    collation-server=utf8mb4_general_ci
    # 设置 InnoDB 引擎的缓冲区大小(InnoDB 缓冲池设置为内存的50%-75%)
    innodb_buffer_pool_size=4G

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: jumpserver-mysql
  namespace: jumpserver
spec:
  serviceName: mysql-headless
  replicas: 1
  selector:
    matchLabels:
      app: mysql
  template:
    metadata:
      labels:
        app: mysql
    spec:
      containers:
      - name: mysql
        #image: mysql:8.0.28
        image: ccr.ccs.tencentyun.com/huanghuanhui/mysql:8.0.28
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            cpu: "2"
            memory: "4Gi"
          requests:
            cpu: "0.5"
            memory: "2Gi"
        ports:
        - name: mysql
          containerPort: 3306
        env:
        - name: MYSQL_ROOT_PASSWORD
          value: "Admin@2024"
        - name: MYSQL_DATABASE
          value: "jumpserver"
        - name: MYSQL_USER
          value: "jumpserver"
        - name: MYSQL_PASSWORD
          value: "jumpserver@2024"
        volumeMounts:
        - name: jumpserver-mysql-data-pvc
          mountPath: /var/lib/mysql
        - mountPath: /etc/localtime
          name: localtime
      volumes:
      - name: localtime
        hostPath:
          path: /etc/localtime
  volumeClaimTemplates:
  - metadata:
      name: jumpserver-mysql-data-pvc
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: nfs-storage
      resources:
        requests:
          storage: 2Ti

---
apiVersion: v1
kind: Service
metadata:
  name: mysql-headless
  namespace: jumpserver
  labels:
    app: mysql
spec:
  clusterIP: None
  ports:
  - port: 3306
    name: mysql
    targetPort: 3306
  selector:
    app: mysql
EOF
```

```shell
kubectl apply -f ~/jumpserver-yml/jumpserver-mysql.yml
```

`2、Redis`

````shell
cat > ~/jumpserver-yml/jumpserver-redis.yml << 'EOF'
kind: ConfigMap
apiVersion: v1
metadata:
  name: redis-cm
  namespace: jumpserver
  labels:
    app: redis
data:
  redis.conf: |-
    dir /data
    port 6379
    bind 0.0.0.0
    appendonly yes
    protected-mode no
    requirepass jumpserver@2024
    pidfile /data/redis-6379.pid 
    save 900 1
    save 300 10
    save 60 10000
    appendfsync always

---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: jumpserver-redis
  namespace: jumpserver
spec:
  replicas: 1
  serviceName: redis-headless
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      name: redis
      labels:
        app: redis
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: redis
              topologyKey: kubernetes.io/hostname
      containers:
      - name: redis
        #image: redis:7.2.4-alpine
        image: ccr.ccs.tencentyun.com/huanghuanhui/redis:7.2.4-alpine
        imagePullPolicy: IfNotPresent
        env:
        - name: TZ
          value: Asia/Shanghai
        command:
          - "sh"
          - "-c"
          - "redis-server /etc/redis/redis.conf"
        ports:
        - containerPort: 6379
          name: tcp-redis
          protocol: TCP
        resources:
          limits:
            cpu: "2"
            memory: "4Gi"
          requests:
            cpu: "1"
            memory: "2Gi"
        volumeMounts:
          - name: redis-data
            mountPath: /data
          - name: config
            mountPath: /etc/redis/redis.conf
            subPath: redis.conf
      volumes:
        - name: config
          configMap:
            name: redis-cm
  volumeClaimTemplates:
  - metadata:
      name: redis-data
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
  name: redis-headless
  namespace: jumpserver
  labels:
    app: redis
spec:
  clusterIP: None
  ports:
  - port: 6379
    name: redis
    targetPort: 6379
  selector:
    app: redis
EOF
````

````shell
kubectl apply -f ~/jumpserver-yml/jumpserver-redis.yml
````

### 生成随机加密密钥

````shell
if [ "$SECRET_KEY" = "" ];then SECRET_KEY=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 50`;echo "SECRET_KEY=$SECRET_KEY" >> ~/.bashrc; echo $SECRET_KEY;else echo $SECRET_KEY; fi

OHSqLMn0boJvri4Kvp7fLt51YBl2kb1mo2pYMMR4GfW0FW1kE2
````

`````shell
if [ "$BOOTSTRAP_TOKEN" = "" ]; then BOOTSTRAP_TOKEN=`cat /dev/urandom | tr -dc A-Za-z0-9 | head -c 16`;echo "BOOTSTRAP_TOKEN=$BOOTSTRAP_TOKEN" >> ~/.bashrc;echo $BOOTSTRAP_TOKEN; else echo $BOOTSTRAP_TOKEN; fi

8ULdOhmMmOtAxr5g
`````

`3、jumpserver`

```shell
cat > ~/jumpserver-yml/jumpserver.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jumpserver
  namespace: jumpserver
  labels:
    app.kubernetes.io/instance: jumpserver
    app.kubernetes.io/name: jumpserver
spec:
    replicas: 1
    strategy:
      rollingUpdate:
        maxSurge: 1
        maxUnavailable: 0
      type: RollingUpdate
    selector:
      matchLabels:
        app.kubernetes.io/instance: jumpserver
        app.kubernetes.io/name: jumpserver
    template:
      metadata:
        labels:
          app.kubernetes.io/instance: jumpserver
          app.kubernetes.io/name: jumpserver
      spec:
        containers:
        - env:
          - name: SECRET_KEY
            value: "veDMhBkZHdfjlsafdjaslfbfiewfbiabjfdakwiafndiawbfjwZ"
          - name: BOOTSTRAP_TOKEN
            value: "F9HUa5nfksd532ndsaR"
          - name: DB_ENGINE
            value: "mysql"
          - name: DB_HOST
            value: "mysql-headless.jumpserver.svc.cluster.local"
          - name: DB_PORT
            value: "3306"
          - name: DB_USER
            value: "jumpserver"
          - name: "DB_PASSWORD"
            value: "jumpserver@2024"
          - name: DB_NAME
            value: "jumpserver"
          - name: REDIS_HOST
            value: "redis-headless.jumpserver.svc.cluster.local"
          - name: REDIS_PORT
            value: "6379"
          - name: REDIS_PASSWORD
            value: "jumpserver@2024"
          #image: jumpserver/jms_all:v3.10.8
          image: ccr.ccs.tencentyun.com/huanghuanhui/jumpserver:v3.10.8
          imagePullPolicy: IfNotPresent
          name: jumpserver
          ports:
          - containerPort: 80
            name: http
            protocol: TCP
          - containerPort: 2222
            name: ssh
            protocol: TCP
          volumeMounts:
          - mountPath: /opt/jumpserver/data/media
            name: datadir
        volumes:
        - name: datadir
          persistentVolumeClaim:
            claimName: jumpserver-datadir

---
apiVersion: v1
kind:  PersistentVolumeClaim
metadata:
  name: jumpserver-datadir
  namespace: jumpserver
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
  name: jumpserver
  namespace: jumpserver
  labels:
    app.kubernetes.io/instance: jumpserver
    app.kubernetes.io/name: jumpserver
spec:
  type: NodePort
  ports:
  - name: http
    nodePort: 30099
    port: 80
    targetPort: 80
    protocol: TCP
  - name: ssh
    nodePort: 30222
    port: 2222
    targetPort: 2222
    protocol: TCP
  selector:
    app.kubernetes.io/instance: jumpserver
    app.kubernetes.io/name: jumpserver
EOF
```

`````shell
kubectl apply -f ~/jumpserver-yml/jumpserver.yml
`````

注意

> 1.将相应的环境变量的值替换成自己的
> 2.SECRET_KEY和BOOTSTRAP_TOKEN的值可以通过jumpserver官网给的脚步生成
> 3.数据库和redis的密码不要使用特殊符号，使用特殊符号在初始化的时候配置文件回不正常，导致初始化失败

`````shell
cat > ~/jumpserver-yml/jumpserver-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jumpserver-ingress
  namespace: jumpserver
  annotations:
    cert-manager.io/cluster-issuer: prod-issuer 
    acme.cert-manager.io/http01-edit-in-place: "true" 
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: jumpserver.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: jumpserver
            port:
              number: 80
  tls:
  - hosts:
    - jumpserver.openhhh.com
    secretName: jumpserver-ingress-tls
EOF
`````

`````shell
#kubectl create secret -n jumpserver \
#tls jumpserver-ingress-tls \
#--key=/root/ssl/openhhh.com.key \
#--cert=/root/ssl/openhhh.com.pem
`````

`````shell
kubectl apply -f ~/jumpserver-yml/jumpserver-Ingress.yml 
`````

> 访问地址：jumpserver.openhhh.com
>
> 用户名：admin
> 设置账号密码为：admin 、Admin@2024

![image-20240419225413784](https://gitee.com/kubelsp/upload/raw/master/img/image-20240419225413784.png)

**1、创建用户**

> 创建管理用户

**2、创建资产**

> 资产管理==》资产列表==》创建==》主机==》Linux ==》
>
> 名称：k8s-master
>
> IP/主机：192.168.1.10
>
>
>
> 创建系统用户（用户名和密码请填写自己服务器的用户密码，之后我们会选择这个系统用户连接服务器）
>
> 账号：用户名和密码请填写自己服务器的用户密码：root、123

**3、权限管理**

> 权限管理==》资产授权==》创建==》
>
> 名称：k8s-master

**4、测试连接**

> 工作台-->web终端
