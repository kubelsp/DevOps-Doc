### Velero + minio（备份容灾）

Velero结合minio实现kubernetes业务数据备份与恢复

备份容灾到 minio 上（k8s、gitlab、jenkins）

minio

```shell
# docker pull minio/minio:RELEASE.2024-04-18T19-09-19Z

docker pull ccr.ccs.tencentyun.com/huanghuanhui/minio:RELEASE.2024-04-18T19-09-19Z
```

```shell
docker run -d \
--name minio \
--restart always \
--privileged=true \
-p 9000:9000 \
-p 5000:5000 \
-v ~/minio-data/data:/data \
-e "MINIO_ROOT_USER=admin" \
-e "MINIO_ROOT_PASSWORD=Admin@2024" \
-v /etc/localtime:/etc/localtime \
-v /etc/timezone:/etc/timezone \
ccr.ccs.tencentyun.com/huanghuanhui/minio:RELEASE.2024-04-18T19-09-19Z \
server /data --console-address ":5000"
```

> web访问地址：http://192.168.1.10:5000
>
> 账号密码: admin、Admin@2024

> 创建访问秘钥：Access Keys ==》Create Access Key
>
> Access Key：xyL2RgM3dkCjkS6WfRzD
>
> Secret Key：CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD

```shell
# docker pull minio/mc:RELEASE.2024-04-18T16-45-29Z

docker pull ccr.ccs.tencentyun.com/huanghuanhui/minio:mc-RELEASE.2024-04-18T16-45-29Z
```

0、创建 velero-k8s 桶

```shell
docker run --rm -it --entrypoint=/bin/sh \
ccr.ccs.tencentyun.com/huanghuanhui/minio:mc-RELEASE.2024-04-18T16-45-29Z -c \
"mc alias set minio http://192.168.1.10:9000 \
xyL2RgM3dkCjkS6WfRzD CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD \

mc mb minio/velero-k8s"
```

1、创建 gitlab 桶

```shell
docker run --rm -it --entrypoint=/bin/sh \
ccr.ccs.tencentyun.com/huanghuanhui/minio:mc-RELEASE.2024-04-18T16-45-29Z -c \
"mc alias set minio http://192.168.1.10:9000 \
xyL2RgM3dkCjkS6WfRzD CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD \

mc mb minio/gitlab"
```

2、创建 jenkins 桶

```shell
docker run --rm -it --entrypoint=/bin/sh \
ccr.ccs.tencentyun.com/huanghuanhui/minio:mc-RELEASE.2024-04-18T16-45-29Z -c \
"mc alias set minio http://192.168.1.10:9000 \
xyL2RgM3dkCjkS6WfRzD CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD \

mc mb minio/jenkins"
```

**0、k8s（容灾备份）**

velero（集群 A 和 集群 B）

1、安装

```shell
wget https://github.com/vmware-tanzu/velero/releases/download/v1.15.2/velero-v1.15.2-linux-amd64.tar.gz
```

```shell
tar xf ~/velero-v1.15.2-linux-amd64.tar.gz

cp ~/velero-v1.15.2-linux-amd64/velero /usr/local/sbin
```

```shell
mkdir -p ~/velero

cat > ~/velero/velero-auth.txt << 'EOF'
# 创建访问minio的认证文件
[default]
aws_access_key_id = admin
aws_secret_access_key = Admin@2024
EOF
```

```shell
velero install --help |grep Image

(default "velero/velero:v1.15.2")
```

```shell
velero/velero-plugin-for-aws:v1.11.1 ==> ccr.ccs.tencentyun.com/huanghuanhui/velero-plugin-for-aws:v1.11.1

velero/velero:v1.13.2 ==> ccr.ccs.tencentyun.com/huanghuanhui/velero:v1.15.2
```

```shell
# 安装
velero --kubeconfig /root/.kube/config \
  install \
    --provider aws \
    --plugins ccr.ccs.tencentyun.com/huanghuanhui/velero-plugin-for-aws:v1.11.1 \
    --bucket velero-k8s \
    --secret-file ~/velero/velero-auth.txt \
    --use-volume-snapshots=false \
    --uploader-type=restic \
    --use-node-agent \
    --image=ccr.ccs.tencentyun.com/huanghuanhui/velero:v1.15.2 \
    --namespace velero-system \
    --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://192.168.1.10:9000
```

```shell
# 卸载
velero uninstall --namespace velero-system --kubeconfig /root/.kube/config
```

2、备份

1、手动备份

**备份不带 pv 的 pod**

```shell
DATE=`date +%F-%H-%M-%S`
k8s_ns=ingress-nginx

velero backup create ${k8s_ns}-backup-${DATE} \
--include-namespaces ${k8s_ns} \
--kubeconfig=/root/.kube/config \
--namespace velero-system
```

```shell
velero backup get --kubeconfig=/root/.kube/config --namespace velero-system
```

```shell
DATE=`date +%F-%H-%M-%S`
k8s_ns=redis-2

velero backup create ${k8s_ns}-backup-${DATE} \
--include-namespaces ${k8s_ns} \
--kubeconfig=/root/.kube/config \
--namespace velero-system

# Velero可以将资源还原到与其备份来源不同的命名空间中。为此，请使用--namespace-mappings标志
# 例如下面将 redis 命名空间资源恢复到 redis-bak 下面
kubectl create ns redis-bak

velero restore create --from-backup "redis-2-backup-2024-11-07-22-47-17" --namespace-mappings redis:redis-bak --wait --kubeconfig=/root/.kube/config --namespace velero-system
```

**备份带 pv 的 pod**

例子1、kuboard（备份、还原）

```shell
DATE=`date +%F-%H-%M-%S`
k8s_ns=kuboard

velero backup create ${k8s_ns}-backup-${DATE} \
--include-namespaces ${k8s_ns} \
--default-volumes-to-fs-backup \
--kubeconfig=/root/.kube/config \
--namespace velero-system
```

```shell
velero backup get --kubeconfig=/root/.kube/config --namespace velero-system

"kuboard-backup-2024-04-21-09-41-09"
```

模拟还原

```shell
kubectl delete ns kuboard
```

> 直接删掉kuboard的命名空间

```shell
velero restore create --from-backup "kuboard-backup-2024-04-21-09-41-09" --wait --kubeconfig=/root/.kube/config --namespace velero-system
```

例子2、jenkins（备份、还原）

```shell
DATE=`date +%F-%H-%M-%S`
k8s_ns=jenkins-prod

velero backup create ${k8s_ns}-backup-${DATE} \
--include-namespaces ${k8s_ns} \
--default-volumes-to-fs-backup \
--kubeconfig=/root/.kube/config \
--namespace velero-system
```

```shell
velero backup get --kubeconfig=/root/.kube/config --namespace velero-system

"jenkins-prod-backup-2024-11-08-13-05-31"
```

```shell
velero restore create --from-backup "jenkins-prod-backup-2024-11-08-13-05-31" --wait --kubeconfig=/root/.kube/config --namespace velero-system
```

2、自动备份

生产：每天0分备份，备份保留7天

生产：每小时备份，备份保留7天

```shell
# 创建备份计划（保留备份数据 7 天）
k8s_ns=jenkins-prod

velero schedule create ${k8s_ns}-backup \
--schedule="0 0 * * *" \
--ttl 168h0m0s \
--include-namespaces ${k8s_ns} \
--default-volumes-to-fs-backup \
--kubeconfig=/root/.kube/config \
--namespace velero-system
```

生产：每小时备份，备份保留7天

```shell
# 创建备份计划（保留备份数据 7 天）
k8s_ns=kube-system

velero schedule create ${k8s_ns}-backup \
--schedule="0 * * * *" \
--ttl 168h0m0s \
--include-namespaces ${k8s_ns} \
--kubeconfig=/root/.kube/config \
--namespace velero-system
```

```shell
# 查看备份计划
velero schedule get --kubeconfig=/root/.kube/config --namespace velero-system
```

```shell
# 查看备份结果
velero backup get --kubeconfig=/root/.kube/config --namespace velero-system
```

```shell
# 删除备份结果
velero backup delete kube-system-backup-2024-11-07-13-50-34 --kubeconfig=/root/.kube/config --namespace velero-system
```

```shell
# 删除备份计划
k8s_ns=jenkins-prod

velero schedule delete ${k8s_ns}-backup --kubeconfig=/root/.kube/config --namespace velero-system
```

3、恢复

```shell
# 查看备份结果
velero backup get --kubeconfig=/root/.kube/config --namespace velero-system
```

```shell
velero restore create --from-backup kube-system-backup-2024-11-07-13-50-34 --wait --kubeconfig=/root/.kube/config --namespace velero-system
```

> 恢复带 pv 的 pod，当前集群可以直接恢复，跨集群迁移（集群A、集群B）两个集群的 StorageClass 要保持一致

4、迁移

集群 A 和 集群 B 都需要安装 Velero 实例（1.5版本以上），并且共用同一个对象存储 COS 存储桶作为 Velero 后端存储

```shell
# 集群 A（备份）

# 集群 B（还原）
velero restore create --from-backup kube-system-backup-2024-11-07-13-50-34 --wait --kubeconfig=/root/.kube/config --namespace velero-system
```

**1、Gitlab（容灾备份）**

备份 gitlab

```shell
docker exec -t gitlab gitlab-backup create
```

把 gitlab 备份上传到 minio 上的 gitlab 桶上

```shell
docker run --rm -it --entrypoint=/bin/sh -v ~/gitlab/data/backups:/data minio/mc -c "
mc config host add minio http://192.168.1.10:9000 xyL2RgM3dkCjkS6WfRzD CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD
mc cp -r /data/ minio/gitlab"
```

````shell
docker run --rm -it --entrypoint=/bin/sh -v ~/gitlab/config/gitlab.rb:/data/gitlab.rb minio/mc -c "
mc config host add minio http://192.168.1.10:9000 xyL2RgM3dkCjkS6WfRzD CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD
mc cp /data/gitlab.rb minio/gitlab/gitlab.rb-$(date +%Y-%m-%d_%H:%M:%S)"
````

```shell
docker run --rm -it --entrypoint=/bin/sh -v ~/gitlab/config/gitlab-secrets.json:/data/gitlab-secrets.json minio/mc -c "
mc config host add minio http://192.168.1.10:9000 xyL2RgM3dkCjkS6WfRzD CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD
mc cp /data/gitlab-secrets.json minio/gitlab/gitlab-secrets.json-$(date +%Y-%m-%d_%H:%M:%S)"
```

**2、Jenkins（容灾备份）**

把 jenkins 备份上传到 minio 上的 jenkins 桶上

```shell
docker run --rm -it --entrypoint=/bin/sh -v /data/k8s/jenkins-prod-jenkins-home-prod-pvc-69144358-4a0c-489f-a8f0-089fe28eed21/jobs:/jobs minio/mc -c "
mc config host add minio http://192.168.1.10:9000 xyL2RgM3dkCjkS6WfRzD CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD
mc cp -r /jobs/ minio/jenkins/jobs-$(date +%Y-%m-%d_%H:%M:%S)"
```

```shell
docker run --rm -it --entrypoint=/bin/sh -v /data/k8s/jenkins-prod-jenkins-home-prod-pvc-69144358-4a0c-489f-a8f0-089fe28eed21/config.xml:/jobs/config.xml minio/mc -c "
mc config host add minio http://192.168.1.201:9000 xyL2RgM3dkCjkS6WfRzD CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD
mc cp /jobs/config.xml minio/jenkins/config.xml-$(date +%Y-%m-%d_%H:%M:%S)"
```

===

计划任务

```shell
cat > minio-bak.sh << 'EOF'
# === 1、gitlab ===#
# 备份 gitlab
docker exec -t gitlab gitlab-backup create

# 把 gitlab 备份上传到 minio 上的 gitlab 桶上
docker run --rm --entrypoint=/bin/sh -v /root/gitlab/data/backups:/data minio/mc -c "
mc config host add minio http://192.168.1.10:9000 xyL2RgM3dkCjkS6WfRzD CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD
mc cp -r /data/ minio/gitlab"

docker run --rm --entrypoint=/bin/sh -v /root/gitlab/config/gitlab.rb:/data/gitlab.rb minio/mc -c "
mc config host add minio http://192.168.1.10:9000 xyL2RgM3dkCjkS6WfRzD CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD
mc cp /data/gitlab.rb minio/gitlab/gitlab.rb-$(date +%Y-%m-%d_%H:%M:%S)"

docker run --rm --entrypoint=/bin/sh -v /root/gitlab/config/gitlab-secrets.json:/data/gitlab-secrets.json minio/mc -c "
mc config host add minio http://192.168.1.10:9000 xyL2RgM3dkCjkS6WfRzD CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD
mc cp /data/gitlab-secrets.json minio/gitlab/gitlab-secrets.json-$(date +%Y-%m-%d_%H:%M:%S)"

# === 2、jenkins ===#
# 把 jenkins 备份上传到 minio 上的 jenkins 桶上
docker run --rm --entrypoint=/bin/sh -v /data/k8s/jenkins-prod-jenkins-home-prod-pvc-69144358-4a0c-489f-a8f0-089fe28eed21/jobs:/jobs minio/mc -c "
mc config host add minio http://192.168.1.10:9000 xyL2RgM3dkCjkS6WfRzD CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD
mc cp -r /jobs/ minio/jenkins/jobs-$(date +%Y-%m-%d_%H:%M:%S)"

docker run --rm --entrypoint=/bin/sh -v /data/k8s/jenkins-prod-jenkins-home-prod-pvc-69144358-4a0c-489f-a8f0-089fe28eed21/config.xml:/jobs/config.xml minio/mc -c "
mc config host add minio http://192.168.1.10:9000 xyL2RgM3dkCjkS6WfRzD CzcpzWbV82YUImM4Go2V3bKSOsY3sfVfkquvg1JD
mc cp /jobs/config.xml minio/jenkins/config.xml-$(date +%Y-%m-%d_%H:%M:%S)"
EOF
```

设置每天晚上2点的计划任务

```shell
# crontab -l
0 2 * * * sh /root/minio-bak.sh >> /root/minio-bak.log 2>&1
```

**etcd 客户端 etcdctl 方式备份整个集群**

计划任务备份 k8s-etcd

```shell
wget https://github.com/etcd-io/etcd/releases/download/v3.5.13/etcd-v3.5.13-linux-amd64.tar.gz

tar xf etcd-v3.5.13-linux-amd64.tar.gz

cp etcd-v3.5.13-linux-amd64/etcdctl /usr/local/sbin
```

```shell
ETCDCTL_API=3 etcdctl \
--write-out=table \
--cert="/etc/kubernetes/pki/etcd/server.crt"  \
--key="/etc/kubernetes/pki/etcd/server.key"  \
--cacert="/etc/kubernetes/pki/etcd/ca.crt" \
--endpoints 127.0.0.1:2379 \
endpoint health
```

```shell
mkdir -p ~/crontab
mkdir -p /data/k8s-etcd-backup

cat > ~/crontab/k8s-etcd-pod.sh << 'EOF'
#!/bin/bash
# 每天凌晨0点备份（k8s-etcd-pod）
# 0 0 * * * /bin/sh /root/crontab/k8s-etcd-pod.sh

k8s_etcd_DATE=`date +%F-%H-%M-%S`

ETCDCTL_API=3 /usr/local/sbin/etcdctl \
--write-out=table \
--cert="/etc/kubernetes/pki/etcd/server.crt"  \
--key="/etc/kubernetes/pki/etcd/server.key"  \
--cacert="/etc/kubernetes/pki/etcd/ca.crt" \
--endpoints 127.0.0.1:2379 \
snapshot save /data/k8s-etcd-backup/${k8s_etcd_DATE}-snapshot.bak

# 备份保留7天
find /data/k8s-etcd-backup -name "*.bak" -mtime +7 -exec rm -rf {} \;
EOF

[root@master ~]# crontab -l
0 0 * * * sh /root/crontab/k8s-etcd-pod.sh

[root@master ~]# crontab -l
* * * * * sh /root/crontab/k8s-etcd-pod.sh
```

```shell
tail -f /var/spool/mail/root
```

```shell
# 备份保留7天
find /data/k8s-etcd-backup -name "*.bak"

find /data/k8s-etcd-backup -name "*.bak" -mtime +7 -exec rm -rf {} \;
```

```shell
# 备份保留7分钟
find /data/k8s-etcd-backup -name "*.bak"

find /data/k8s-etcd-backup -name "*.bak" -mmin +7 -exec rm -rf {} \;
```

