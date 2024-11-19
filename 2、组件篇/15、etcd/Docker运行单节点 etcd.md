###### Docker运行单节点 etcd

````shell
export NODE1=192.168.1.10

docker run \
  -p 2379:2379 \
  -p 2380:2380 \
  -v ~/etcd-data:/etcd-data \
  --name etcd gcr.io/etcd-development/etcd:latest \
  /usr/local/bin/etcd \
  --data-dir=/etcd-data --name node1 \
  --initial-advertise-peer-urls http://${NODE1}:2380 --listen-peer-urls http://0.0.0.0:2380 \
  --advertise-client-urls http://${NODE1}:2379 --listen-client-urls http://0.0.0.0:2379 \
  --initial-cluster node1=http://${NODE1}:2380
````

列出集群成员：

````shell
etcdctl --endpoints=http://${NODE1}:2379 member list
````

