rabbitmq

```shell
mkdir -p ~/rabbitmq-yml

kubectl create ns rabbitmq
```

```shell
cat > ~/rabbitmq-yml/rabbitmq-sts.yml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: rabbitmq
  namespace: rabbitmq
  labels:
    app: rabbitmq
spec:
  replicas: 1
  serviceName: rabbitmq
  selector:
    matchLabels:
      app: rabbitmq
  template:
    metadata:
      labels:
        app: rabbitmq
    spec:
      containers:
        - name: rabbitmq
          image: rabbitmq:3.6.16-management
          imagePullPolicy: IfNotPresent
          resources:
            requests:
              memory: "4Gi"
              cpu: "2000m"
            limits:
              memory: "4Gi"
              cpu: "2000m"
          env:
            - name: RABBITMQ_DEFAULT_USER
              value: guest
            - name: RABBITMQ_DEFAULT_PASS
              value: guest@2023
            - name: RABBITMQ_ERLANG_COOKIE
              value: ZmgwNVlkM0NzMmUxa1draFhxb3B1T0pZaTVIcHVnQVI=
            - name: RABBITMQ_DEFAULT_VHOST
              value: /
          ports:
            - name: epmd
              containerPort: 4369
            - name: amqp
              containerPort: 5672
            - name: dist
              containerPort: 25672
            - name: stats
              containerPort: 15672
          volumeMounts:
            - name: data
              mountPath: /var/lib/rabbitmq
            - mountPath: /etc/localtime
              name: localtime            
      volumes:
      - name: localtime
        hostPath:
          path: /etc/localtime

  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "nfs-storage"
      resources:
        requests:
          storage: 2Ti
EOF
```

```shell
kubectl apply -f ~/rabbitmq-yml/rabbitmq-sts.yml
```

```shell
cat > ~/rabbitmq-yml/rabbitmq-svc.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: rabbitmq
  namespace: rabbitmq
  labels:
    app: rabbitmq
spec:
  type: NodePort
  selector:
    app: rabbitmq
  ports:
    - name: epmd
      port: 4369
      nodePort: 30333
      targetPort: epmd
    - name: amqp
      port: 5672
      nodePort: 30334
      targetPort: amqp
    - name: dist
      port: 25672
      nodePort: 30335
      targetPort: dist
    - name: stats
      port: 15672
      nodePort: 30336
      targetPort: stats
EOF
```

```shell
kubectl apply -f ~/rabbitmq-yml/rabbitmq-svc.yml
```

> 1、web访问地址：http://192.168.1.213:30336
>
> 2、代码连接地址：ip：192.168.1.213、端口：30334(对应默认5672)
>
> 用户密码：guest、guest@2023
