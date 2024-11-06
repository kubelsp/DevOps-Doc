docker安装elk

1、es

````shell
mkdir -p /elk-data/es/{data,logs,plugins} && chmod 777 /elk-data/es/{data,logs,plugins}
````

````shell
docker run -d \
--restart=always \
--name es-single-node \
-p 9200:9200 \
-p 9300:9300 \
--privileged=true \
-v /elk-data/es/data:/usr/share/elasticsearch/data \
-v /elk-data/es/logs:/usr/share/elasticsearch/logs \
-v /elk-data/es/plugins:/usr/share/elasticsearch/plugins \
-v /etc/localtime:/etc/localtime \
-e "discovery.type=single-node" \
-e "ES_JAVA_OPTS=-Xms4096m -Xmx4096m" \
docker.elastic.co/elasticsearch/elasticsearch:8.15.0
````

````shell
curl -X GET "127.0.0.1:9200/_cat/health?v"
````

2、kibana

`````shell
docker run -d \
--restart=always \
--name kibana \
--privileged=true \
-p 5601:5601 \
-e ELASTICSEARCH_HOSTS=http://192.168.1.168:9200 \
-e I18N.LOCALE=zh-CN \
-v /etc/localtime:/etc/localtime \
docker.elastic.co/kibana/kibana:8.15.0
`````

3、kafka

````shell
docker run -d \
--name kafka \
-u root \
-e KAFKA_ENABLE_KRAFT=yes \
-e KAFKA_CFG_PROCESS_ROLES=broker,controller \
-e KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER \
-e KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093 \
-e KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT \
-e KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://192.168.1.168:9092 \
-e KAFKA_BROKER_ID=1 \
-e KAFKA_CFG_NODE_ID=1 \
-e KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@localhost:9093 \
-e ALLOW_PLAINTEXT_LISTENER=yes \
-v /elk-data/kafka:/bitnami/kafka:rw \
-p 9092:9092 \
-p 9093:9093 \
bitnami/kafka:3.8.0
````

`````shell
docker run -d \
--name kafka-ui \
--restart always \
--privileged=true \
-p 8899:8080 \
-e KAFKA_CLUSTERS_0_NAME=elk-kafka \
-e KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=192.168.1.168:9092 \
-v /etc/localtime:/etc/localtime \
provectuslabs/kafka-ui:v0.7.2
`````

4、logstash

````shell
docker run -d \
--restart=always \
--name logstash \
-p 9600:9600 \
-p 5044:5044 \
--privileged=true \
-v /elk-data/logstash/config/logstash.yml:/usr/share/logstash/config/logstash.yml \
-v /elk-data/logstash/config/logstash.conf:/usr/share/logstash/pipeline/logstash.conf \
-v /elk-data/logstash/logFile:/usr/share/logstash/logFile \
-v /etc/localtime:/etc/localtime \
docker.elastic.co/logstash/logstash:8.15.0
````

5、filebeat

`````shell
docker run -d --name filebeat --user=root \
-v /mnt/nfs/logs/:/mnt/nfs/logs/ \
-v /root/filebeat/config/filebeat.yml:/usr/share/filebeat/filebeat.yml \
elastic/filebeat:8.15.0
`````

````shell
cat > ~/filebeat/config/filebeat.yml << 'EOF'
# 日志输入配置（可配置多个）
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /mnt/nfs/logs/*/*/*.log
  tags: ["gateway"]
  fields:
    server: 49.235.249.203
  fields_under_root: true
#日志输出配置
output.kafka:
  enabled: true
  hosts: ["192.168.1.168:9092"]
  topic: "sit"
  partition.round_robin:
    reachable_only: false
  required_acks: 1
  compression: gzip
  max_message_bytes: 1000000
EOF
````

