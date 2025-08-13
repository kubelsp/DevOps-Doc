### ELKFK

###### (Elastic Cloud on Kubernetes)（ECK）

> k8s-v1.30.0
>
> elastic-operator版本：2.12.1
>
> elasticsearch版本：8.13.3
>
> kibana版本：8.13.3
>
> kafka版本：3.7.0
>
> logstash版本：8.13.3
>
> filebeat版本：8.13.3
>
> https://github.com/elastic/cloud-on-k8s

ES/Kibana   <--- Logstash  <---  Kafka   <---  Filebeat

部署顺序：

0、elastic-operator

1、elasticsearch

2、kibana

3、kafka

4、logstash

5、filebeat

###### 0、elastic-operator（Elastic Cloud on Kubernetes）（ECK）

> https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-installing-eck.html
>
> https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-deploy-eck.html

```shell
mkdir -p ~/elk-yml && cd ~/elk-yml
```

```shell
cd ~/elk-yml && wget https://download.elastic.co/downloads/eck/2.12.1/crds.yaml
```

```shell
kubectl apply -f  ~/elk-yml/crds.yaml
```

```shell
cd ~/elk-yml && wget https://download.elastic.co/downloads/eck/2.12.1/operator.yaml
```

```shell
kubectl apply -f  ~/elk-yml/operator.yaml
```

```shell
kubectl -n elastic-system logs -f statefulset.apps/elastic-operator
```

###### 1、elasticsearch

````shell
cat > ~/elk-yml/es.yml << 'EOF'
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: elasticsearch
  namespace: elastic-system
spec:
  version: 8.13.3
  http:
    tls:
      selfSignedCertificate:  
        ## 取消默认的tls
        disabled: true
  nodeSets:
  - name: master-nodes
    count: 3
    config:
      node.roles: ["master", "remote_cluster_client"]
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 2Ti
        storageClassName: nfs-storage
  - name: data-nodes
    count: 3
    config:
      node.roles: ["master", "data", "ingest", "remote_cluster_client"]
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 2Ti
        storageClassName: nfs-storage
EOF
````

````shell
kubectl apply -f ~/elk-yml/es.yml
````

S3存储库配置

https://www.elastic.co/docs/deploy-manage/tools/snapshot-and-restore/cloud-on-k8s#k8s-s3-compatible

````shell
kubectl -n elastic-system create secret generic snapshot-settings \
   --from-literal=s3.client.default.access_key=$YOUR_ACCESS_KEY \
   --from-literal=s3.client.default.secret_key=$YOUR_SECRET_ACCESS_KEY
````

```shell
# 如果aksk变了，重载配置，不需要重启es

POST _nodes/reload_secure_settings
{
  "secure_settings_password": ""
}
```

````shell
cat > ~/elk-yml/es.yml << 'EOF'
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: elasticsearch
  namespace: elastic-system
spec:
  version: 8.13.3
  secureSettings:
  - secretName: snapshot-settings
  http:
    tls:
      selfSignedCertificate:  
        ## 取消默认的tls
        disabled: true
  nodeSets:
  - name: master-nodes
    count: 3
    config:
      node.roles: ["master", "remote_cluster_client"]
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 2Ti
        storageClassName: nfs-storage
  - name: data-nodes
    count: 3
    config:
      node.roles: ["master", "data", "ingest", "remote_cluster_client"]
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 2Ti
        storageClassName: nfs-storage
EOF
````

````shell
kubectl apply -f ~/elk-yml/es.yml
````

验证

```shell
kubectl  get secret elasticsearch-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode
```

````shell
curl -u "elastic:nq48A2zW4x0H1OxTv426Ae2K" 10.105.47.218:9200/_cat/health

curl -u "elastic:nq48A2zW4x0H1OxTv426Ae2K" 10.105.47.218:9200/_cat/nodes
````

###### 2、kibana

````shell
cat > ~/elk-yml/kibana.yml << 'EOF'
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: kibana
  namespace: elastic-system
spec:
  version: 8.13.3
  http:
    tls:
      selfSignedCertificate:  
        ## 取消默认的tls
        disabled: true
  count: 1
  elasticsearchRef:
    name: elasticsearch
    namespace: elastic-system
  config:
    monitoring.ui.ccs.enabled: true
EOF
````

`````shell
kubectl apply -f ~/elk-yml/kibana.yml
`````

````shell
kubectl patch svc/kibana-kb-http -n elastic-system --patch '{"spec":
{"type":"NodePort"}}'

kubectl patch svc/kibana-kb-http -n elastic-system --type='json' -p '[{"op": "replace", "path": "/spec/ports/0/nodePort", "value":30999}]'
````

```shell
cat >  ~/elk-yml/kibana-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kibana-ingress
  namespace: elastic-system
  annotations:
    cert-manager.io/cluster-issuer: prod-issuer 
    acme.cert-manager.io/http01-edit-in-place: "true" 
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: kibana.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kibana-kb-http
            port:
              number: 5601
  tls:
  - hosts:
    - kibana.openhhh.com
    secretName: kibana-ingress-tls
EOF
```

```shell
#kubectl create secret -n elastic-system \
#tls kibana-ingress-tls \
#--key=/root/ssl/openhhh.com.key \
#--cert=/root/ssl/openhhh.com.pem
```

```shell
kubectl apply -f ~/elk-yml/kibana-Ingress.yml
```

```shell
# 获取密码

kubectl get secret elasticsearch-es-elastic-user -o=jsonpath='{.data.elastic}' | base64 --decode
```

>访问地址：https://kibana.openhhh.com
>
>账号密码：elastic、nq48A2zW4x0H1OxTv426Ae2K

````shell
https://kibana.openhhh.com/app/dev_tools#/console

GET _cat/nodes

GET _cat/health

GET _cat/indices
````

###### 3、kafka（Kafka with KRaft）

```shell
cat > ~/elk-yml/kafka.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: kafka-headless
  labels:
    app: kafka
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - name: kafka-client
    port: 9092
    targetPort: kafka-client
  - name: controller
    port: 9093
    targetPort: controller   
  selector:
    app: kafka
---
#部署 Service，用于外部访问 Kafka
apiVersion: v1
kind: Service
metadata:
  name: kafka-service
  labels:
    app: kafka
spec:
  type: NodePort
  ports:
  - name: kafka-client
    port: 9092
    targetPort: kafka-client
    nodePort: 30992
  selector:
    app: kafka
---
# 分别在 StatefulSet 中的每个 Pod 中获取相应的序号作为 KAFKA_CFG_NODE_ID（只能是整数），然后再执行启动脚本
apiVersion: v1
kind: ConfigMap
metadata:
  name: ldc-kafka-scripts
data:
  setup.sh: |-
    #!/bin/bash
    export KAFKA_CFG_NODE_ID=${MY_POD_NAME##*-} 
    exec /opt/bitnami/scripts/kafka/entrypoint.sh /opt/bitnami/scripts/kafka/run.sh
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: kafka
  labels:
    app: kafka
spec:
  selector:
    matchLabels:
      app: kafka
  serviceName: kafka-headless
  podManagementPolicy: Parallel
  replicas: 3 # 部署完成后，将会创建 3 个 Kafka 副本
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: kafka
    spec:
      affinity:
        podAntiAffinity: # 工作负载反亲和
          preferredDuringSchedulingIgnoredDuringExecution: # 尽量满足如下条件
          - weight: 1
            podAffinityTerm:
              labelSelector: # 选择Pod的标签，与工作负载本身反亲和
                matchExpressions:
                  - key: "app"
                    operator: In
                    values:
                      - kafka
              topologyKey: "kubernetes.io/hostname"  # 在节点上起作用
      containers:
      - name: kafka
        #image: bitnami/kafka:3.4.1
        #image: bitnami/kafka:3.7.0
        image: ccr.ccs.tencentyun.com/huanghuanhui/bitnami-kafka:3.7.0
        imagePullPolicy: "IfNotPresent"
        command:
        - /opt/leaderchain/setup.sh
        env:
        - name: BITNAMI_DEBUG
          value: "true" # true 详细日志
        # KRaft settings 
        - name: MY_POD_NAME # 用于生成 KAFKA_CFG_NODE_ID
          valueFrom:
            fieldRef:
              fieldPath: metadata.name            
        - name: KAFKA_CFG_PROCESS_ROLES
          value: "controller,broker"
        - name: KAFKA_CFG_CONTROLLER_QUORUM_VOTERS
          value: "0@kafka-0.kafka-headless:9093,1@kafka-1.kafka-headless:9093,2@kafka-2.kafka-headless:9093"
        - name: KAFKA_KRAFT_CLUSTER_ID
          value: "Jc7hwCMorEyPprSI1Iw4sW"  
        # Listeners            
        - name: KAFKA_CFG_LISTENERS
          value: "PLAINTEXT://:9092,CONTROLLER://:9093"
        - name: KAFKA_CFG_ADVERTISED_LISTENERS
          value: "PLAINTEXT://:9092"
        - name: KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP
          value: "CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT"
        - name: KAFKA_CFG_CONTROLLER_LISTENER_NAMES
          value: "CONTROLLER"
        - name: KAFKA_CFG_INTER_BROKER_LISTENER_NAME
          value: "PLAINTEXT"
        ports:
        - containerPort: 9092
          name: kafka-client                  
        - containerPort: 9093
          name: controller
          protocol: TCP                     
        volumeMounts:
        - mountPath: /bitnami/kafka
          name: kafka-data
        - mountPath: /opt/leaderchain/setup.sh
          name: scripts
          subPath: setup.sh
          readOnly: true      
      securityContext:
        fsGroup: 1001
        runAsUser: 1001
      volumes:    
      - configMap:
          defaultMode: 493
          name: ldc-kafka-scripts
        name: scripts      
  volumeClaimTemplates:
  - metadata:
      name: kafka-data
    spec:
      storageClassName: nfs-storage
      accessModes: [ReadWriteOnce]
      resources:
        requests:
          storage: 2Ti
EOF
```

```shell
kubectl apply -f ~/elk-yml/kafka.yml
```

###### kafka-ui

````shell
cat > ~/elk-yml/kafka-ui.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-ui
  namespace: elastic-system
  labels:
    app: kafka-ui
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kafka-ui
  template:
    metadata:
      labels:
        app: kafka-ui
    spec:
      containers:
      - name: kafka-ui
        #image: provectuslabs/kafka-ui:v0.7.2
        image: ccr.ccs.tencentyun.com/huanghuanhui/kafka-ui:v0.7.2
        imagePullPolicy: IfNotPresent
        env:
        - name: KAFKA_CLUSTERS_0_NAME
          value: 'kafka-elk'
        - name: KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS
          value: 'kafka-headless:9092'
        - name: DYNAMIC_CONFIG_ENABLED
          value: "true"
        - name: AUTH_TYPE # https://docs.kafka-ui.provectus.io/configuration/authentication/basic-authentication
          value: "LOGIN_FORM"
        - name: SPRING_SECURITY_USER_NAME
          value: "admin"    
        - name: SPRING_SECURITY_USER_PASSWORD
          value: "Admin@2024"
        ports:
        - name: web
          containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: kafka-ui
  namespace: elastic-system
spec:
  selector:
    app: kafka-ui
  type: NodePort
  ports:
  - name: web
    port: 8080
    targetPort: 8080
    nodePort: 30088
EOF
````

```shell
kubectl apply -f ~/elk-yml/kafka-ui.yml
```

```shell
cat > ~/elk-yml/kafka-ui-Ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: kafka-ui-ingress
  namespace: elastic-system
  annotations:
    cert-manager.io/cluster-issuer: prod-issuer 
    acme.cert-manager.io/http01-edit-in-place: "true" 
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: kafka-ui.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: kafka-ui
            port:
              number: 8080
  tls:
  - hosts:
    - kafka-ui.openhhh.com
    secretName: kafka-ui-ingress-tls
EOF
```

```shell
#kubectl create secret -n elastic-system \
#tls kafka-ui-ingress-tls \
#--key=/root/ssl/openhhh.com.key \
#--cert=/root/ssl/openhhh.com.pem
```

```shell
kubectl apply -f ~/elk-yml/kafka-ui-Ingress.yml
```

> 访问地址：https://kafka-ui.openhhh.com
>
> 账号密码：admin、Admin@2024

###### 4、filebeat

```shell
cat > ~/elk-yml/filebeat.yml << 'EOF'
apiVersion: beat.k8s.elastic.co/v1beta1
kind: Beat
metadata:
  name: filebeat
  namespace: elastic-system
spec:
  type: filebeat
  version: 8.13.3
  config:
    filebeat.inputs:
    - type: container
      paths:
      - /var/log/containers/*.log
    output.kafka:
      hosts: ["kafka-headless.elastic-system.svc:9092"]
      topic: 'k8s-logs'
      group_id: 'k8s-logs'
  daemonSet:
    podTemplate:
      spec:
        dnsPolicy: ClusterFirstWithHostNet
        hostNetwork: true
        securityContext:
          runAsUser: 0
        containers:
        - name: filebeat
          volumeMounts:
          - name: varlogcontainers
            mountPath: /var/log/containers
          - name: varlogpods
            mountPath: /var/log/pods
          - name: varlibdockercontainers
            mountPath: /var/lib/docker/containers
        volumes:
        - name: varlogcontainers
          hostPath:
            path: /var/log/containers
        - name: varlogpods
          hostPath:
            path: /var/log/pods
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
EOF
```

```shell
kubectl apply -f ~/elk-yml/filebeat.yml
```

###### 5、logstash

```shell
cat > ~/elk-yml/logstash.yml << 'EOF'
apiVersion: logstash.k8s.elastic.co/v1alpha1
kind: Logstash
metadata:
  name: logstash
  namespace: elastic-system
spec:
  count: 3
  version: 8.13.3
  volumeClaimTemplates:
    - metadata:
        name: logstash-data
      spec:
        accessModes:
          - ReadWriteOnce
        resources:
          requests:
            storage: 2Ti
        storageClassName: nfs-storage
  pipelines:
    - pipeline.id: main
      config.string: |
        input {
          kafka {
            bootstrap_servers => ["kafka-headless.elastic-system.svc:9092"]
            topics => ["k8s-logs"]
            group_id => "k8s-logs"
          }
        }
        output {
          elasticsearch {
            hosts => ["elasticsearch-es-data-nodes:9200"]
            user => "elastic"
            password => "nq48A2zW4x0H1OxTv426Ae2K"
            ssl_certificate_verification => false
            index => "k8s-logs-%{+YYYY.MM.dd}"
          }
        }
EOF
```

> 记得改密码

```shell
kubectl apply -f ~/elk-yml/logstash.yml
```

实际业务日志收集到后面项目篇的时候会接上！这里是收集了k8s集群的日志！！！
