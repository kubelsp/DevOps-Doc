### 升级 k8s 集群（kubeadm）

1、master

````shell
kubeadm upgrade plan
````

````shell
# 执行升级命令先把kubeadm升级
# yum -y install kubeadm-1.30.3

kubeadm upgrade apply v1.30.3
````

```shell
# yum -y install kubelet-1.30.3 kubectl-1.30.3

systemctl restart kubelet
```

2、node

````shell
# 执行升级命令先把kubeadm升级
# yum -y install kubeadm-1.30.3

kubeadm upgrade node
````

````shell
# yum -y install kubelet-1.30.3 kubectl-1.30.3

systemctl restart kubelet
````

3、网络插件

```shell
# 升级k8s 集群网络（calico）
```



```shell
# 官方源
cat > /etc/yum.repos.d/kubernetes.repo << 'EOF'
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=0
EOF
```

```shell
# 腾讯源
cat > /etc/yum.repos.d/kubernetes.repo << 'EOF'
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.cloud.tencent.com/kubernetes_new/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=0
EOF
```

