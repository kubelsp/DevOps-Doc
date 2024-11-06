### Docker 安装 Elasticsearch

> https://www.docker.elastic.co/r/elasticsearch?show_snapshots=false&ordering=-created_at

````shell
mkdir -p ~/es/{data,logs,plugins} && chmod 777 ~/es/{data,logs,plugins}
````

````shell
# docker pull docker.elastic.co/elasticsearch/elasticsearch:8.15.0

docker pull ccr.ccs.tencentyun.com/huanghuanhui/elasticsearch:8.15.0
````

````shell
docker run -d \
--restart=always \
--name es-single-node \
-p 9200:9200 \
-p 9300:9300 \
--privileged=true \
-v ~/es/data:/usr/share/elasticsearch/data \
-v ~/es/logs:/usr/share/elasticsearch/logs \
-v ~/es/plugins:/usr/share/elasticsearch/plugins \
-e "discovery.type=single-node" \
-e "ES_JAVA_OPTS=-Xms4096m -Xmx4096m" \
ccr.ccs.tencentyun.com/huanghuanhui/elasticsearch:8.15.0
````

````shell
docker exec -t es-single-node sh -c 'sed -i "s/xpack.security.enabled: true/xpack.security.enabled: false/" /usr/share/elasticsearch/config/elasticsearch.yml'
````

````shell
docker restart es-single-node
````

````shell
# 查看集群健康
curl -X GET "127.0.0.1:9200/_cat/health?v"

# 查看节点信息
curl -X GET "127.0.0.1:9200/_cat/nodes?v"

# 查看索引信息
curl -X GET "127.0.0.1:9200/_cat/indices?v"
````