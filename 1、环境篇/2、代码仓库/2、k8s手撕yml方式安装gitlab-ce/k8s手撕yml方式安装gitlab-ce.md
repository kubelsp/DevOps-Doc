### k8s手撕yml方式安装gitlab-ce



###### gitlab企业级-生产级别部署（支持大约1000用户）



###### 官方镜像方式安装gitlab-16.11.0（外接redis+postgresql）



> k8s-1.30.0
>
> redis-7.2.4
>
> postgresql-14.11
>
> gitlab-16.11.0

参考框架：

1000用户

https://docs.gitlab.com/ee/administration/reference_architectures/1k_users.html

2000用户

https://docs.gitlab.com/ee/administration/reference_architectures/2k_users.html

```powershell
mkdir -p ~/gitlab-yml

kubectl create ns gitlab
```

###### 1、redis

```yaml
cat > ~/gitlab-yml/gitlab-redis.yml << 'EOF'
kind: ConfigMap
apiVersion: v1
metadata:
  name: gitlab-redis-config-map
  namespace: gitlab
  labels:
    app: redis
data:
  redis.conf: |-
    dir /data
    port 6379
    bind 0.0.0.0
    appendonly yes
    protected-mode no
    requirepass Admin@2024
    pidfile /data/redis-6379.pid 
    save 900 1
    save 300 10
    save 60 10000
    appendfsync always
    
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: gitlab-redis
  namespace: gitlab
spec:
  replicas: 1
  serviceName: gitlab-redis
  selector:
    matchLabels:
      app: gitlab-redis
  template:
    metadata:
      name: gitlab-redis
      labels:
        app: gitlab-redis
    spec:
      containers:
      - name: gitlab-redis
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
            cpu: 1
            memory: 3.75Gi
          requests:
            cpu: 1
            memory: 3.75Gi
        volumeMounts:
          - name: gitlab-redis-data
            mountPath: /data
          - name: config
            mountPath: /etc/redis/redis.conf
            subPath: redis.conf
      volumes:
        - name: config
          configMap:
            name: gitlab-redis-config-map
  volumeClaimTemplates:
  - metadata:
      name: gitlab-redis-data
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
  name: gitlab-redis-headless
  namespace: gitlab
  labels:
    app: gitlab-redis
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - name: redis
    port: 6379
    protocol: TCP
    targetPort: tcp-redis
  selector:
    app: gitlab-redis
EOF
```

```shell
kubectl apply -f ~/gitlab-yml/gitlab-redis.yml
```

```powershell
kubectl run gitlab-redis-client --rm --tty -i --restart='Never' --image=ccr.ccs.tencentyun.com/huanghuanhui/redis:7.2.4-alpine --command -- sh

redis-cli -h gitlab-redis-headless -p 6379 -a Admin@2024
gitlab-redis-headless:6379> keys *	#第一次查看数据为空，请gitlab初始化完成，再次查看数据
```

###### 2、postgresql

```yaml
cat > ~/gitlab-yml/gitlab-postgres.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: gitlab-postgres
  namespace: gitlab
spec:
  replicas: 1
  serviceName: gitlab-postgres
  selector:
    matchLabels:
      app: gitlab-postgres
  template:
    metadata:
      labels:
        app: gitlab-postgres
    spec:
      containers:
      - name: gitlab-postgres
        image: ccr.ccs.tencentyun.com/huanghuanhui/postgres:14.11
        imagePullPolicy: IfNotPresent
        env:
        - name: TZ
          value: Asia/Shanghai
        - name: POSTGRES_PASSWORD
          value: Admin@2024
        - name: POSTGRES_USER
          value: postgresql
        - name:  POSTGRES_DB
          value: gitlab_production
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
        - name: gitlab-postgres-data
          mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
  - metadata:
      name: gitlab-postgres-data
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
  name: gitlab-postgres-headless
  namespace: gitlab
  labels:
    app: gitlab-postgres
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - name: gitlab-postgres
    port: 5432
    protocol: TCP
    targetPort: tcp-postgres
  selector:
    app: gitlab-postgres
EOF
```

```powershell
kubectl apply -f ~/gitlab-yml/gitlab-postgres.yml
```

```powershell
kubectl run gitlab-postgresql-client --rm --tty -i --restart='Never' --image=ccr.ccs.tencentyun.com/huanghuanhui/postgres:14.11 --command -- bash

PGPASSWORD=Admin@2024 psql -h gitlab-postgres-headless -U postgresql -d gitlab_production

gitlab_production=# \l
gitlab_production=# \d	#第一次查看数据为空，请gitlab初始化完成，再次查看数据
gitlab_production=# \q
```

###### 3、gitlab

```shell
gitlab/gitlab-ce:16.11.0-ce.0  ==>  ccr.ccs.tencentyun.com/huanghuanhui/gitlab:16.11.0-ce.0
```

```powershell
kubectl run test-gitlab --image=ccr.ccs.tencentyun.com/huanghuanhui/gitlab:16.11.0-ce.0

kubectl cp test-gitlab:/etc/gitlab/gitlab.rb ~/gitlab-yml/gitlab.rb
出现"tar: Removing leading `/' from member names"忽视即可

kubectl delete pod test-gitlab
```

```powershell
cat > ~/gitlab-yml/connet-redis.sh << 'EOF'
    redis['enable'] = false
    gitlab_rails['redis_host'] = "gitlab-redis-headless"
    gitlab_rails['redis_port'] = 6379
    gitlab_rails['redis_password'] = "Admin@2024"
EOF
```

```powershell
cat > ~/gitlab-yml/connet-postgres.sh << 'EOF'
    postgresql['enable'] = false
    gitlab_rails['db_adapter'] = "postgresql"
    gitlab_rails['db_encoding'] = "utf8"
    gitlab_rails['db_database'] = "gitlab_production"
    gitlab_rails['db_username'] = "postgresql"
    gitlab_rails['db_password'] = "Admin@2024"
    gitlab_rails['db_host'] = "gitlab-postgres-headless"
    gitlab_rails['db_port'] = "5432"
EOF
```

```powershell
sed -i '744 r connet-redis.sh' gitlab.rb

sed -i '731 r connet-postgres.sh' gitlab.rb

egrep -v '^$|#' ~/gitlab-yml/gitlab.rb
```

```powershell
kubectl create configmap gitlab-config-map -n gitlab --from-file=/root/gitlab-yml/gitlab.rb
```

```yaml
cat > ~/gitlab-yml/gitlab-StatefulSet.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: gitlab
  namespace: gitlab
spec:
  replicas: 1
  serviceName: gitlab
  selector:
    matchLabels:
      app: gitlab
  template:
    metadata:
      name: gitlab
      labels:
        app: gitlab
    spec:
      containers:
      - name: gitlab
        image: ccr.ccs.tencentyun.com/huanghuanhui/gitlab:16.11.0-ce.0
        imagePullPolicy: IfNotPresent
        env:
        - name: TZ
          value: Asia/Shanghai
        - name: GITLAB_ROOT_PASSWORD
          value: huanghuanhui@2024
        ports:
        - name: http
          containerPort: 80
        - name: ssh
          containerPort: 22
        resources:
          requests:
            cpu: 1
            memory: 2Gi
          limits:
            cpu: 2
            memory: 8Gi
        volumeMounts:
        - name: gitlab-config
          mountPath: /etc/gitlab
        - name: gitlab-logs
          mountPath: /var/log/gitlab
        - name: gitlab-data
          mountPath: /var/opt/gitlab
        - name: gitlab-rb
          mountPath: /etc/gitlab/gitlab.rb
          subPath: gitlab.rb
      volumes:
      - name: gitlab-config
        emptyDir: {}
      - name: gitlab-logs
        emptyDir: {}
      - name: gitlab-rb
        configMap:
          name: gitlab-config-map
  volumeClaimTemplates:
  - metadata:
      name: gitlab-data
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
  name: gitlab
  namespace: gitlab
  labels:
    name: gitlab
spec:
  type: NodePort
  ports:
    - name: http
      nodePort: 31888
      port: 80
      targetPort: http
    - name: ssh
      port: 22
      targetPort: ssh
  selector:
    app: gitlab
EOF
```

```powershell
kubectl apply -f ~/gitlab-yml/gitlab-StatefulSet.yml
```

```shell
# 等待两三分钟、初始化完就可访问

kubectl logs -f gitlab-0 -n gitlab
```

```shell
cat > ~/gitlab-yml/gitlab-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gitlab-ingress
  namespace: gitlab
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: gitlab.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: gitlab
            port:
              number: 80

  tls:
  - hosts:
    - gitlab.openhhh.com
    secretName: gitlab-ingress-tls
EOF
```

```shell
kubectl create secret -n gitlab \
tls gitlab-ingress-tls \
--key=/root/ssl/openhhh.com.key \
--cert=/root/ssl/openhhh.com.pem
```

```shell
kubectl apply -f ~/gitlab-yml/gitlab-Ingress.yml
```

> 访问地址：https://gitlab.openhhh.com
>
> 设置账号密码为：root、huanghuanhui@2024

```powershell
等待gitlab初始化完成，再次查看redis+postgresql的数据
gitlab的数据确定已经外接redis+postgres后，搭建完成、即可访问


[root@master ~]# kubectl exec -it gitlab-0 -n gitlab -- bash
root@gitlab-0:/# gitlab-ctl status
root@gitlab-0:/# gitlab-ctl status
run: alertmanager: (pid 1182) 160s; run: log: (pid 1025) 188s
run: gitaly: (pid 1170) 161s; run: log: (pid 555) 253s
run: gitlab-exporter: (pid 1144) 162s; run: log: (pid 911) 201s
run: gitlab-kas: (pid 1120) 163s; run: log: (pid 657) 247s
run: gitlab-workhorse: (pid 1133) 163s; run: log: (pid 763) 211s
run: grafana: (pid 1270) 160s; run: log: (pid 1101) 164s
run: logrotate: (pid 492) 262s; run: log: (pid 506) 259s
run: nginx: (pid 774) 210s; run: log: (pid 802) 207s
run: prometheus: (pid 1146) 161s; run: log: (pid 989) 194s
run: puma: (pid 694) 224s; run: log: (pid 701) 223s
run: sidekiq: (pid 710) 218s; run: log: (pid 725) 217s
run: sshd: (pid 33) 272s; run: log: (pid 32) 272s
root@gitlab-0:/#
可以看到gitlab容器中，没有内置redis+postgresql
```



