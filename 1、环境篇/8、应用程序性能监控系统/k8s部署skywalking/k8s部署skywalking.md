## k8s部署skywalking

> k8s版本：v1.30.0
>
> skywalking-helm：v4.6.0
>
> es版本：7.17.3
>
> skywalking版本：10.0.0
>
> https://github.com/apache/skywalking-helm

````shell
mkdir -p ~/skywalking-yml

kubectl create ns skywalking
````

`````shell
cat > ~/skywalking-yml/skywalking-values.yml << 'EOF'
oap:
  image:
    tag: 10.0.0-java21
  storageType: elasticsearch
  replicas: 1
  env: 
    SW_CORE_RECORD_DATA_TTL: "10" # 设置记录数据的保留时间
    SW_CORE_METRICS_DATA_TTL: "10" # 经过聚合处理的指标数据的保留时间
    SW_TELEMETRY: "prometheus"
    SW_HEALTH_CHECKER: "default"
    SW_ENABLE_UPDATE_UI_TEMPLATE: "true"
  readinessProbe:
    tcpSocket:
      port: 12800
    initialDelaySeconds: 50
    periodSeconds: 10
    failureThreshold: 30
  resources:
    requests:
      memory: 2Gi

ui:
  image:
    tag: 10.0.0-java21

elasticsearch:
  enabled: true
  replicas: 1
  minimumMasterNodes: 1
  nodeGroup: "single-node"
  persistence: 
    enabled: true
  initResources:
    requests:
      memory: 1.5Gi
  clusterHealthCheckParams: "wait_for_status=yellow&timeout=1s"
  volumeClaimTemplate:
    accessModes: [ "ReadWriteOnce" ]
    storageClassName: nfs-storage
    resources:
      requests:
        storage: 2Ti
EOF
`````

```shell
# helm chat 的版本
export SKYWALKING_RELEASE_VERSION=4.6.0
# helm 的 release name
export SKYWALKING_RELEASE_NAME=skywalking
# k8s 的命名空间
export SKYWALKING_RELEASE_NAMESPACE=skywalking

# 部署
helm install "${SKYWALKING_RELEASE_NAME}" \
oci://registry-1.docker.io/apache/skywalking-helm \
--version "${SKYWALKING_RELEASE_VERSION}" \
-n "${SKYWALKING_RELEASE_NAMESPACE}" -f ~/skywalking-yml/skywalking-values.yml
```

````shell
cat > ~/skywalking-yml/skywalking-Ingress.yml << 'EOF'
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
  - host: skywalking.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: skywalking-skywalking-helm-ui
            port:
              number: 80
  tls:
  - hosts:
    - skywalking.openhhh.com
    secretName: skywalking-ui-ingress-tls
EOF
````

````shell
kubectl create secret -n skywalking \
tls skywalking-ui-ingress-tls \
--key=/root/ssl/openhhh.com.key \
--cert=/root/ssl/openhhh.com.pem
````

````shell
kubectl apply -f ~/skywalking-yml/skywalking-Ingress.yml
````

> 访问地址：https://skywalking.openhhh.com

###### 部署 kibana

````shell
cat > ~/skywalking-yml/skywalking-kibana.yml << 'EOF'
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
              value: "http://elasticsearch-single-node-headless:9200"
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
````

````shell
kubectl apply -f ~/skywalking-yml/skywalking-kibana.yml
````

````shell
cat > ~/skywalking-yml/skywalking-kibana-Ingress.yml << 'EOF'
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
  - host: skywalking-kibana.openhhh.com
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
    - skywalking-kibana.openhhh.com
    secretName: skywalking-kibana-ingress-tls
EOF
````

````shell
yum -y install httpd-tools

cd ~/skywalking-yml && htpasswd -bc auth admin Admin@2024

kubectl create secret generic kibana-auth-secret --from-file=auth -n skywalking
````

`````shell
kubectl create secret -n skywalking \
tls skywalking-kibana-ingress-tls \
--key=/root/ssl/openhhh.com.key \
--cert=/root/ssl/openhhh.com.pem
`````

`````shell
kubectl apply -f ~/skywalking-yml/skywalking-kibana-Ingress.yml
`````

> 访问地址：https://skywalking-kibana.openhhh.com
>
> 账号密码：admin、Admin@2024

===

###### 修复操作

````shell
# 如果skywalking-oap有问题，可以重新init（修复操作）
cat > ~/skywalking-yml/skywalking-es-init.yml << 'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  annotations:
    helm.sh/hook: post-install,post-upgrade,post-rollback
    helm.sh/hook-weight: "1"
  generation: 1
  labels:
    app: skywalking
    chart: skywalking-helm-4.5.0
    component: skywalking-skywalking-helm-job
    heritage: Helm
    release: skywalking
  name: skywalking-skywalking-helm-oap-init
  namespace: skywalking
spec:
  backoffLimit: 6
  completionMode: NonIndexed
  completions: 1
  manualSelector: false
  parallelism: 1
  podReplacementPolicy: TerminatingOrFailed
  selector:
    matchLabels:
  suspend: false
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: skywalking
        batch.kubernetes.io/job-name: skywalking-skywalking-helm-oap-init
        component: skywalking-skywalking-helm-job
        job-name: skywalking-skywalking-helm-oap-init
        release: skywalking
      name: skywalking-oap-init
    spec:
      containers:
      - env:
        - name: JAVA_OPTS
          value: -Xmx2g -Xms2g -Dmode=init
        - name: SW_STORAGE
          value: elasticsearch
        - name: SW_STORAGE_ES_CLUSTER_NODES
          value: elasticsearch-single-node:9200
        - name: SW_CORE_METRICS_DATA_TTL
          value: "10"
        - name: SW_CORE_RECORD_DATA_TTL
          value: "10"
        - name: SW_ENABLE_UPDATE_UI_TEMPLATE
          value: "true"
        - name: SW_HEALTH_CHECKER
          value: default
        - name: SW_TELEMETRY
          value: prometheus
        image: skywalking.docker.scarf.sh/apache/skywalking-oap-server:9.7.0
        imagePullPolicy: IfNotPresent
        name: oap
        resources:
          requests:
            memory: 2Gi
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      dnsPolicy: ClusterFirst
      initContainers:
      - command:
        - sh
        - -c
        - for i in $(seq 1 60); do nc -z -w3 elasticsearch-single-node 9200 && exit
          0 || sleep 5; done; exit 1
        image: busybox:1.30
        imagePullPolicy: IfNotPresent
        name: wait-for-elasticsearch
        resources: {}
        terminationMessagePath: /dev/termination-log
        terminationMessagePolicy: File
      restartPolicy: Never
      schedulerName: default-scheduler
      securityContext: {}
      serviceAccount: skywalking-skywalking-helm-oap
      serviceAccountName: skywalking-skywalking-helm-oap
      terminationGracePeriodSeconds: 30
EOF
````

###### 卸载方式

````shell
helm delete skywalking -n skywalking
````

````shell
kubectl delete jobs skywalking-skywalking-helm-oap-init

kubectl delete pvc elasticsearch-single-node-elasticsearch-single-node-0 --force

kubectl delete ns skywalking
````

