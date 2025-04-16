### 12、k8s集群证书更新.md

````shell
# 检查证书是否过期

kubeadm certs check-expiration
````

```shell
# 手动更新所有证书

kubeadm certs renew all
```

```shell
# 移动文件间接重启静态pod
mv /etc/kubernetes/manifests/*yaml /tmp/

mv /tmp/*.yaml /etc/kubernetes/manifests/
```

````shell
# 更新 kubeconfig
cp /etc/kubernetes/admin.conf $HOME/.kube/config
````