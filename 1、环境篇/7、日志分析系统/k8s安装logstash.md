k8s安装logstash

````shell
cat > logstash.yml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: logstash-config
  namespace: elk
data:
  logstash.yml: |
    api.http.host: "0.0.0.0"
    pipeline.workers: 2
    xpack.monitoring.enabled: false
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: logstash-pipeline
  namespace: elk
data:
  logstash.conf: |
    input {
      kafka {
        bootstrap_servers => "kafka-headless:9092"
        group_id => "logstash"
        codec => "json"
        topics => [
          "k8s-logs"
        ]
      }
    }

    output {

      if [log_type] == "hhh" {
        elasticsearch {
          hosts => ["http://elasticsearch-headless:9200"]
          index => "k8s-%{[kubernetes][namespace]}-%{[kubernetes][container][name]}-%{+YYYY.MM}---%{+ww}"
          #user => ""
          #password => ""
        }
      }
      
      stdout {
        codec => rubydebug
      }
    }

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: logstash-hhh
  namespace: elk
spec:
  replicas: 1
  selector:
    matchLabels:
      app: logstash
  template:
    metadata:
      labels:
        app: logstash
    spec:
      containers:
        - name: logstash
          image: docker.elastic.co/logstash/logstash:9.0.3
          ports:
            - containerPort: 5044
          volumeMounts:
            - name: config
              mountPath: /usr/share/logstash/config/logstash.yml
              subPath: logstash.yml
            - name: pipeline
              mountPath: /usr/share/logstash/pipeline/logstash.conf
              subPath: logstash.conf
      volumes:
        - name: config
          configMap:
            name: logstash-config
        - name: pipeline
          configMap:
            name: logstash-pipeline
---
apiVersion: v1
kind: Service
metadata:
  name: logstash
  namespace: elk
spec:
  selector:
    app: logstash
  ports:
    - name: http-input
      protocol: TCP
      port: 5044
      targetPort: 5044
EOF
````





