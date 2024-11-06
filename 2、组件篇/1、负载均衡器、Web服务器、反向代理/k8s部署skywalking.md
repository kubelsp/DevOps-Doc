## k8s部署skywalking

> k8s版本：v1.29.1
>
> es版本：7.17.3
>
> skywalking版本：9.2.0

添加helm源

````shell
helm repo add skywalking https://apache.jfrog.io/artifactory/skywalking-helm

helm search repo skywalking

helm pull skywalking/skywalking --version 4.3.0 --untar
````

`````shell
kubectl create ns skywalking
`````

自定义values文件es

`````shell
cd ~/skywalking/charts/elasticsearch
`````

```shell
cat > values-prod.yaml << 'EOF'
image: "docker.elastic.co/elasticsearch/elasticsearch"
imageTag: "7.17.3"
imagePullPolicy: IfNotPresent
replicas: 3
esConfig:
 elasticsearch.yml: |
    network.host: 0.0.0.0
    cluster.name: "elasticsearch"
    xpack.security.enabled: false
resources:
  requests:
    cpu: 2
    memory: 4Gi
  limits:
    cpu: 2
    memory: 4Gi
readinessProbe:
  failureThreshold: 3
  initialDelaySeconds: 60
  periodSeconds: 10
  successThreshold: 3
  timeoutSeconds: 5

volumeClaimTemplate:
  storageClassName: "nfs-storage"
  accessModes: [ "ReadWriteOnce" ]
  resources:
    requests:
      storage: 2Ti
EOF
```

部署es

```shell
#k8s-v1.29.1版本 把policy/v1beta1换成policy/v1
find templates -type f -exec sed -i 's/policy\/v1beta1/policy\/v1/g' {} \;
```

```shell
helm upgrade --install -n skywalking skywalking-es -f ./values-prod.yaml .
```

自定义values文件-skywalking

```shell
cd ~/skywalking
```

```shell
cat > values-prod.yaml << 'EOF'
elasticsearch:
  enabled: false
  config:
    host: elasticsearch-master-headless
    port:
      http: 9200

oap:
  antiAffinity: soft
  image:
    pullPolicy: IfNotPresent
    repository: apache/skywalking-oap-server
    tag: 9.2.0
  javaOpts: -Xmx2g -Xms2g
  name: oap
  replicas: 2
  storageType: elasticsearch

ui:
  image:
    pullPolicy: IfNotPresent
    repository: apache/skywalking-ui
    tag: 9.2.0
  name: ui
  replicas: 1
  service:
    type: NodePort
    port: 80
    nodePort: 30888
EOF
```

把就绪、存活探针时间调大一点

```shell
sed -i 's/15/60/g' ~/skywalking/templates/oap-deployment.yaml
```

部署skywalking

```shell
helm upgrade --install --namespace skywalking skywalking -f ./values-prod.yaml .
```

> 访问地址：ip+30888

```shell
cat > ~/skywalking/skywalking-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: skywalking-ingress
  namespace: skywalking
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: skywalking.huanghuanhui.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: skywalking-ui
            port:
              number: 80
  tls:
  - hosts:
    - skywalking.huanghuanhui.cloud
    secretName: skywalking-ui-ingress-tls
EOF
```

```shell
kubectl create secret -n skywalking \
tls skywalking-ui-ingress-tls \
--key=/root/ssl/huanghuanhui.cloud.key \
--cert=/root/ssl/huanghuanhui.cloud.crt
```

```shell
kubectl apply -f ~/skywalking/skywalking-Ingress.yml
```

> 访问地址：skywalking.huanghuanhui.cloud
>

===

卸载方式

```shell
helm delete skywalking -n skywalking
```

````shell
helm delete skywalking-es -n skywalking

kubectl delete pvc elasticsearch-master-elasticsearch-master-0 -n skywalking
kubectl delete pvc elasticsearch-master-elasticsearch-master-1 -n skywalking
kubectl delete pvc elasticsearch-master-elasticsearch-master-2 -n skywalking
````

部署 kibana

```shell
cat > ~/skywalking/kibana.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  namespace: skywalking
  name: kibana-config
  labels:
    app: kibana
data:
  kibana.yml: |-
    server.host: 0.0.0.0
    elasticsearch:
      hosts: ${ELASTICSEARCH_HOSTS}
    i18n.locale: zh-CN                      #设置默认语言为中文
#     username: ${ELASTICSEARCH_USER}
#      password: ${ELASTICSEARCH_PASSWORD}
---
kind: Deployment
apiVersion: apps/v1
metadata:
  labels:
    app: kibana
  name: kibana
  namespace: skywalking
spec:
  replicas: 1
  revisionHistoryLimit: 3
  selector:
    matchLabels:
      app: kibana
  template:
    metadata:
      labels:
        app: kibana
    spec:
      containers:
        - name: kibana
          image: docker.elastic.co/kibana/kibana:7.17.3
          ports:
            - containerPort: 5601
              protocol: TCP
          env:
            - name: SERVER_PUBLICBASEURL
              value: "http://0.0.0.0:5601"
            - name: I18N.LOCALE
              value: zh-CN
            - name: ELASTICSEARCH_HOSTS
              value: "http://elasticsearch-master-headless:9200"
            - name: ELASTICSEARCH_USER
              value: "elastic"
#            - name: ELASTICSEARCH_PASSWORD
#              valueFrom:
#                secretKeyRef:
#                  name: elasticsearch-password
#                  key: password
            - name: xpack.encryptedSavedObjects.encryptionKey
              value: "min-32-byte-long-strong-encryption-key"

          volumeMounts:
          - name: kibana-config
            mountPath: /usr/share/kibana/config/kibana.yml
            readOnly: true
            subPath: kibana.yml
          - mountPath: /etc/localtime
            name: localtime
      volumes:
      - name: kibana-config
        configMap:
          name: kibana-config
      - hostPath:
          path: /etc/localtime
        name: localtime
---
kind: Service
apiVersion: v1
metadata:
  labels:
    app: kibana
  name: kibana-service
  namespace: skywalking
spec:
  ports:
  - port: 5601
    targetPort: 5601
    nodePort: 30011
  type: NodePort
  selector:
    app: kibana
EOF
```

```shell
kubectl apply -f ~/skywalking/kibana.yml
```

```shell
cat > ~/skywalking/skywalking-kibana-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: skywalking-kibana-ingress
  namespace: skywalking
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
    nginx.ingress.kubernetes.io/auth-type: basic
    nginx.ingress.kubernetes.io/auth-secret: kibana-auth-secret
    nginx.ingress.kubernetes.io/auth-realm: 'Authentication Required - admin'
spec:
  ingressClassName: nginx
  rules:
  - host: skywalking-kibana.huanghuanhui.cloud
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kibana-service
            port:
              number: 5601
  tls:
  - hosts:
    - skywalking-kibana.huanghuanhui.cloud
    secretName: skywalking-kibana-ingress-tls
EOF
```

```shell
yum -y install httpd-tools

cd ~/skywalking && htpasswd -bc auth admin Admin@2024

kubectl create secret generic kibana-auth-secret --from-file=auth -n skywalking
```

```shell
kubectl create secret -n skywalking \
tls skywalking-kibana-ingress-tls \
--key=/root/ssl/huanghuanhui.cloud.key \
--cert=/root/ssl/huanghuanhui.cloud.crt
```

```shell
kubectl apply -f ~/skywalking/skywalking-kibana-Ingress.yml
```

> 访问地址：skywalking-kibana.huanghuanhui.cloud
>
> 账号密码：admin、Admin@2024

===

###### 修复操作

```shell
# 如果skywalking-oap有问题，可以重新init（修复操作）
cat skywalking-es-init.yml
apiVersion: batch/v1
kind: Job
metadata:
  name: skywalking-es-init
  namespace: skywalking
spec:
  backoffLimit: 6
  completionMode: NonIndexed
  completions: 1
  parallelism: 1
  podReplacementPolicy: TerminatingOrFailed
  template:
    metadata:
      labels:
        app: skywalking
        component: skywalking-job
        job-name: skywalking-es-init
    spec:
      containers:
      - name: oap
        image: apache/skywalking-oap-server:9.2.0
        imagePullPolicy: IfNotPresent
        env:
        - name: JAVA_OPTS
          value: -Xmx2g -Xms2g -Dmode=init
        - name: SW_STORAGE
          value: elasticsearch
        - name: SW_STORAGE_ES_CLUSTER_NODES
          value: elasticsearch-master-headless:9200
        - name: SW_ES_USER
          value: xxx
        - name: SW_ES_PASSWORD
          value: xxx
      initContainers:
      - name: wait-for-elasticsearch
        image: busybox:1.30
        imagePullPolicy: IfNotPresent
        command:
        - sh
        - -c
        - for i in $(seq 1 60); do nc -z -w3 elasticsearch-master-headless 9200 &&
          exit 0 || sleep 5; done; exit 1
      restartPolicy: Never
      terminationGracePeriodSeconds: 30
      serviceAccountName: skywalking-oap
EOF
```

