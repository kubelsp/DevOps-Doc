### 9、nfs-subdir-external-provisioner

k8s（pv 与 pvc）动态存储 StorageClass

k8s-1.30.0 持久化存储（nfs动态存储）

1、部署nfs

nfs 服务端（k8s-master）

```shell
# 所有服务端节点安装nfs
yum -y install nfs-utils

systemctl enable nfs-server rpcbind --now

# 创建nfs共享目录、授权
mkdir -p /data/k8s && chmod -R 777 /data/k8s

# 写入exports
cat > /etc/exports << EOF
/data/k8s 192.168.1.0/24(rw,sync,no_root_squash)
EOF
 
systemctl reload nfs-server
 
使用如下命令进行验证
# showmount -e 192.168.1.10
Export list for 192.168.1.10:
/data/k8s 192.168.1.0/24
```

nfs 客户端（k8s-node）

```shell
yum -y install nfs-utils
 
systemctl enable rpcbind --now
 
使用如下命令进行验证
# showmount -e 192.168.1.10
Export list for 192.168.1.10:
/data/k8s 192.168.1.0/24
```

备份

```shell
mkdir -p /data/k8s && chmod -R 777 /data/k8s

rsync -avzP /data/k8s root@192.168.1.203:/data

00 2 * * * rsync -avz /data/k8s root@192.168.1.203:/data &>/dev/null
```

2、动态创建 NFS存储（动态存储）

> https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner

```shell
mkdir ~/nfs-subdir-external-provisioner-4.0.18 && cd ~/nfs-subdir-external-provisioner-4.0.18
```

> 版本：nfs-subdir-external-provisioner-4.0.18
>
> https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/tree/nfs-subdir-external-provisioner-4.0.18/deploy

```shell
# wget https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/raw/nfs-subdir-external-provisioner-4.0.18/deploy/deployment.yaml
 
# wget https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/raw/nfs-subdir-external-provisioner-4.0.18/deploy/rbac.yaml
 
# wget https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner/raw/nfs-subdir-external-provisioner-4.0.18/deploy/class.yaml
```

```shell
wget https://gitee.com/kubelsp/upload/raw/master/nfs-storage/v4.0.18/deployment.yaml
 
wget https://gitee.com/kubelsp/upload/raw/master/nfs-storage/v4.0.18/rbac.yaml
 
wget https://gitee.com/kubelsp/upload/raw/master/nfs-storage/v4.0.18/class.yaml
```

```shell
# 1、修改镜像（默认谷歌k8s.gcr.io）
sed -i 's#registry.k8s.io/sig-storage/nfs-subdir-external-provisioner:v4.0.2#ccr.ccs.tencentyun.com/huanghuanhui/nfs-storage:v4.0.2#g' deployment.yaml
# 2、修改nfs服务端地址
sed -i 's/10.3.243.101/192.168.1.10/g' deployment.yaml
# 3、修改存储地址（/data/k8s）
sed -i 's#\/ifs\/kubernetes#\/data\/k8s#g' deployment.yaml

sed -i 's#nfs-client#nfs-storage#g' class.yaml

sed -i 's/namespace: default/namespace: nfs-storage/g' rbac.yaml deployment.yaml
```

> 使用这个镜像：ccr.ccs.tencentyun.com/huanghuanhui/nfs-storage:v4.0.2 

```shell
kubectl create ns nfs-storage

kubectl -n nfs-storage apply -f .

kubectl get pods -n nfs-storage -l app=nfs-client-provisioner

kubectl get storageclass
```

```shell
# 将 StorageClass 标记为默认

kubectl patch storageclass nfs-storage -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```
