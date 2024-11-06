### 0、k8s集群（k8s-1.30.0）

[TOC]

containerd-1.6.31 + k8s-1.30.0（最新）（kubeadm方式）（containerd容器运行时版）

> kubeadm方式安装最新版k8s-1.30.0（containerd容器运行时）
>
> containerd-1.6.31 + k8s-1.30.0（最新）（kubeadm方式）

> containerd-1.6.31
>
> k8s-1.30.0

> - k8s-master（centos-7.9）（4c8g-200g）
> - k8s-node1（centos-7.9）（8c16g-200g）
> - k8s-node2（rocky-9.3）（8c16g-200g）
> - k8s-node3（rocky-9.3）（8c16g-200g）

### 0、环境准备（centos-7.9、rocky-9.3 环境配置+调优）

```shell
# 颜色
echo "PS1='\[\033[35m\][\[\033[00m\]\[\033[31m\]\u\[\033[33m\]\[\033[33m\]@\[\033[03m\]\[\033[35m\]\h\[\033[00m\] \[\033[5;32m\]\w\[\033[00m\]\[\033[35m\]]\[\033[00m\]\[\033[5;31m\]\\$\[\033[00m\] '" >> ~/.bashrc && source ~/.bashrc

echo 'PS1="[\[\e[33m\]\u\[\e[0m\]\[\e[31m\]@\[\e[0m\]\[\e[35m\]\h\[\e[0m\]:\[\e[32m\]\w\[\e[0m\]] \[\e[33m\]\t\[\e[0m\] \[\e[31m\]Power\[\e[0m\]=\[\e[32m\]\!\[\e[0m\] \[\e[35m\]^0^\[\e[0m\]\n\[\e[95m\]公主请输命令^0^\[\e[0m\] \[\e[36m\]\\$\[\e[0m\] "' >> ~/.bashrc && source ~/.bashrc

# 0、centos7 环境配置
# 安装 vim
yum -y install vim wget net-tools

# 行号
echo "set nu" >> /root/.vimrc

# 搜索关键字高亮
sed -i "8calias grep='grep --color'" /root/.bashrc

# 腾讯源
cp /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo-bak
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.cloud.tencent.com/repo/centos7_base.repo
wget -O /etc/yum.repos.d/CentOS-Epel.repo http://mirrors.cloud.tencent.com/repo/epel-7.repo

yum clean all
yum makecache
```

```shell
# 1、设置主机名
hostnamectl set-hostname k8s-master && su -
hostnamectl set-hostname k8s-node1 && su -
hostnamectl set-hostname k8s-node2 && su -
hostnamectl set-hostname k8s-node3 && su -
```

```shell
# 2、添加hosts解析
cat >> /etc/hosts << EOF
192.168.1.10 k8s-master
192.168.1.11 k8s-node1
192.168.1.12 k8s-node2
192.168.1.13 k8s-node3
EOF
```

```shell
# 3、同步时间
yum -y install ntp

systemctl enable ntpd --now
```

```shell
# 4、永久关闭seLinux(需重启系统生效)
setenforce 0
sed -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
```

```shell
# 5、永久关闭swap(需重启系统生效)
swapoff -a  # 临时关闭
sed -i 's/.*swap.*/#&/g' /etc/fstab # 永久关闭
```

```shell
# 6、升级内核为5.4版本(需重启系统生效)
# https://elrepo.org/tiki/kernel-lt
# https://elrepo.org/linux/kernel/el7/x86_64/RPMS/

rpm -Uvh http://www.elrepo.org/elrepo-release-7.0-6.el7.elrepo.noarch.rpm

yum --disablerepo="*" --enablerepo="elrepo-kernel" list available

yum --enablerepo=elrepo-kernel install -y kernel-lt

grub2-set-default 0
```

```shell
wget https://gitee.com/kubelsp/upload/raw/master/kernel-lt/5.4/kernel-lt-5.4.274-1.el7.elrepo.x86_64.rpm

yum -y install kernel-lt-5.4.274-1.el7.elrepo.x86_64.rpm

grub2-set-default 0
```

```shell
# 这里先重启再继续
# reboot
```

```shell
# 7、关闭防火墙、清空iptables规则
systemctl disable firewalld && systemctl stop firewalld

iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X && iptables -P FORWARD ACCEPT
```

```shell
# 8、关闭 NetworkManager
systemctl disable NetworkManager && systemctl stop NetworkManager
```

```shell
# 9、加载IPVS模块
yum -y install ipset ipvsadm

mkdir -p /etc/sysconfig/modules
cat > /etc/sysconfig/modules/ipvs.modules <<EOF
modprobe -- ip_vs
modprobe -- ip_vs_rr
modprobe -- ip_vs_wrr
modprobe -- ip_vs_sh
modprobe -- nf_conntrack
EOF

modprobe -- nf_conntrack

chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules && lsmod | grep -e ip_vs -e nf_conntrack
```

```shell
# 10、开启br_netfilter、ipv4 路由转发
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

# 设置所需的 sysctl 参数，参数在重新启动后保持不变
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# 应用 sysctl 参数而不重新启动
sudo sysctl --system

# 查看是否生效
lsmod | grep br_netfilter
lsmod | grep overlay

sysctl net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables net.ipv4.ip_forward
```

```shell
# 11、内核调优
cat > /etc/sysctl.d/99-sysctl.conf << 'EOF'
# sysctl settings are defined through files in
# /usr/lib/sysctl.d/, /run/sysctl.d/, and /etc/sysctl.d/.
#
# Vendors settings live in /usr/lib/sysctl.d/.
# To override a whole file, create a new file with the same in
# /etc/sysctl.d/ and put new settings there. To override
# only specific settings, add a file with a lexically later
# name in /etc/sysctl.d/ and put new settings there.
#
# For more information, see sysctl.conf(5) and sysctl.d(5).

# Controls IP packet forwarding

# Controls source route verification
net.ipv4.conf.default.rp_filter = 1

# Do not accept source routing
net.ipv4.conf.default.accept_source_route = 0

# Controls the System Request debugging functionality of the kernel

# Controls whether core dumps will append the PID to the core filename.
# Useful for debugging multi-threaded applications.
kernel.core_uses_pid = 1

# Controls the use of TCP syncookies
net.ipv4.tcp_syncookies = 1

# Controls the maximum size of a message, in bytes
kernel.msgmnb = 65536

# Controls the default maxmimum size of a mesage queue
kernel.msgmax = 65536

net.ipv4.conf.all.promote_secondaries = 1
net.ipv4.conf.default.promote_secondaries = 1
net.ipv6.neigh.default.gc_thresh3 = 4096

kernel.sysrq = 1
net.ipv6.conf.all.disable_ipv6=0
net.ipv6.conf.default.disable_ipv6=0
net.ipv6.conf.lo.disable_ipv6=0
kernel.numa_balancing = 0
kernel.shmmax = 68719476736
kernel.printk = 5
net.core.rps_sock_flow_entries=8192
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_local_reserved_ports=60001,60002
net.core.rmem_max=16777216
fs.inotify.max_user_watches=524288
kernel.core_pattern=core
net.core.dev_weight_tx_bias=1
net.ipv4.tcp_max_orphans=32768
kernel.pid_max=4194304
kernel.softlockup_panic=1
fs.file-max=3355443
net.core.bpf_jit_harden=1
net.ipv4.tcp_max_tw_buckets=32768
fs.inotify.max_user_instances=8192
net.core.bpf_jit_kallsyms=1
vm.max_map_count=262144
kernel.threads-max=262144
net.core.bpf_jit_enable=1
net.ipv4.tcp_keepalive_time=600
net.ipv4.tcp_wmem=4096 12582912    16777216
net.core.wmem_max=16777216
net.ipv4.neigh.default.gc_thresh1=2048
net.core.somaxconn=32768
net.ipv4.neigh.default.gc_thresh3=8192
net.ipv4.ip_forward=1
net.ipv4.neigh.default.gc_thresh2=4096
net.ipv4.tcp_max_syn_backlog=8096
net.bridge.bridge-nf-call-iptables=1
net.ipv4.tcp_rmem=4096  12582912        16777216
EOF

# 应用 sysctl 参数而不重新启动
sudo sysctl --system
```

```shell
# 12、设置资源配置文件
cat >> /etc/security/limits.conf << 'EOF'
* soft nofile 100001
* hard nofile 100002
root soft nofile 100001
root hard nofile 100002
* soft memlock unlimited
* hard memlock unlimited
* soft nproc 254554
* hard nproc 254554
* soft sigpending 254554
* hard sigpending 254554
EOF
 
grep -vE "^\s*#" /etc/security/limits.conf
 
ulimit -a
```

### 1、安装containerd-1.6.31（官方源）(centos-7.9、rocky-9.3 )

```shell
wget -O /etc/yum.repos.d/docker-ce.repo https://download.docker.com/linux/centos/docker-ce.repo

yum makecache
```

```shell
yum list containerd.io --showduplicates | sort -r
```

```shell
yum -y install containerd.io-1.6.31
```

```shell
containerd config default | sudo tee /etc/containerd/config.toml

# 修改cgroup Driver为systemd
sed -ri 's#SystemdCgroup = false#SystemdCgroup = true#' /etc/containerd/config.toml

# 更改sandbox_image
sed -ri 's#registry.k8s.io\/pause:3.6#registry.aliyuncs.com\/google_containers\/pause:3.9#' /etc/containerd/config.toml

# 添加镜像加速
# https://github.com/DaoCloud/public-image-mirror
# 1、指定配置文件目录
sed -i 's/config_path = ""/config_path = "\/etc\/containerd\/certs.d\/"/g' /etc/containerd/config.toml
# 2、配置加速
# docker.io 镜像加速
mkdir -p /etc/containerd/certs.d/docker.io
cat > /etc/containerd/certs.d/docker.io/hosts.toml << 'EOF'
server = "https://docker.io" # 源镜像地址

[host."https://xk9ak4u9.mirror.aliyuncs.com"] # 阿里-镜像加速地址
  capabilities = ["pull","resolve"]

[host."https://docker.m.daocloud.io"] # 道客-镜像加速地址
  capabilities = ["pull","resolve"]

[host."https://dockerproxy.com"] # 镜像加速地址
  capabilities = ["pull", "resolve"]

[host."https://docker.mirrors.sjtug.sjtu.edu.cn"] # 上海交大-镜像加速地址
  capabilities = ["pull","resolve"]

[host."https://docker.mirrors.ustc.edu.cn"] # 中科大-镜像加速地址
  capabilities = ["pull","resolve"]

[host."https://docker.nju.edu.cn"] # 南京大学-镜像加速地址
  capabilities = ["pull","resolve"]

[host."https://registry-1.docker.io"]
  capabilities = ["pull","resolve","push"]
EOF

# registry.k8s.io 镜像加速
mkdir -p /etc/containerd/certs.d/registry.k8s.io
cat > /etc/containerd/certs.d/registry.k8s.io/hosts.toml << 'EOF'
server = "https://registry.k8s.io"

[host."https://k8s.m.daocloud.io"]
  capabilities = ["pull", "resolve", "push"]
EOF

# quay.io 镜像加速
mkdir -p /etc/containerd/certs.d/quay.io
cat > /etc/containerd/certs.d/quay.io/hosts.toml << 'EOF'
server = "https://quay.io"

[host."https://quay.m.daocloud.io"]
  capabilities = ["pull", "resolve", "push"]
EOF

# docker.elastic.co镜像加速
mkdir -p /etc/containerd/certs.d/docker.elastic.co
tee /etc/containerd/certs.d/docker.elastic.co/hosts.toml << 'EOF'
server = "https://docker.elastic.co"

[host."https://elastic.m.daocloud.io"]
  capabilities = ["pull", "resolve", "push"]
EOF

systemctl daemon-reload

systemctl enable containerd --now

systemctl restart containerd
systemctl status containerd
```

> 镜像加速配置无需重启服务，即可生效

```shell
#设置crictl
cat << EOF >> /etc/crictl.yaml
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 10
debug: false
EOF
```

### 2、安装k8s（kubeadm-1.30.0、kubelet-1.30.0、kubectl-1.30.0）（官方源）(centos-7.9、rocky-9.3 )

```shell
cat > /etc/yum.repos.d/kubernetes.repo << 'EOF'
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.30/rpm/
enabled=1
gpgcheck=0
EOF

yum makecache

yum -y install kubeadm-1.30.0 kubelet-1.30.0 kubectl-1.30.0

systemctl enable --now kubelet
```

### 3、初始化 k8s-1.30.0 集群

```shell
mkdir ~/kubeadm_init && cd ~/kubeadm_init

kubeadm config print init-defaults > kubeadm-init.yaml

cat > ~/kubeadm_init/kubeadm-init.yaml << EOF
apiVersion: kubeadm.k8s.io/v1beta3
bootstrapTokens:
- groups:
  - system:bootstrappers:kubeadm:default-node-token
  token: abcdef.0123456789abcdef
  ttl: 24h0m0s
  usages:
  - signing
  - authentication
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: 192.168.1.10 # 修改自己的ip
  bindPort: 6443
nodeRegistration:
  criSocket: unix:///var/run/containerd/containerd.sock
  imagePullPolicy: IfNotPresent
  name: k8s-master
  taints:
  - effect: NoSchedule
    key: node-role.kubernetes.io/k8s-master
---
apiServer:
  timeoutForControlPlane: 4m0s
apiVersion: kubeadm.k8s.io/v1beta3
certificatesDir: /etc/kubernetes/pki
clusterName: kubernetes
controllerManager: {}
dns: {}
etcd:
  local:
    dataDir: /var/lib/etcd
imageRepository: registry.aliyuncs.com/google_containers
kind: ClusterConfiguration
kubernetesVersion: v1.30.0
networking:
  dnsDomain: cluster.local
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
scheduler: {}
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: systemd
EOF
```

```shell
# 查看所需镜像列表
kubeadm config images list --config kubeadm-init.yaml

kubeadm config images list --kubernetes-version=v1.30.0 --image-repository registry.aliyuncs.com/google_containers
```

```shell
# 预拉取镜像
kubeadm config images pull --config kubeadm-init.yaml

kubeadm config images pull --kubernetes-version=v1.30.0 --image-repository registry.aliyuncs.com/google_containers
```

```shell
# 初始化
kubeadm init --config=kubeadm-init.yaml | tee kubeadm-init.log
```

```shell
# 配置 kubectl
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
```

### 4、安装 k8s 集群网络（calico）

查看calico与k8s的版本对应关系

> https://docs.tigera.io/calico/3.27/getting-started/kubernetes/requirements
>
> https://github.com/projectcalico/calico

> 这里k8s-1.30.0，所以使用calico-v3.27.3版本（版本对应很关键）

```shell
# mkdir -p ~/calico-yml

# cd ~/calico-yml && wget https://github.com/projectcalico/calico/raw/v3.27.3/manifests/calico.yaml
```

```shell
mkdir -p ~/calico-yml

cd ~/calico-yml && wget https://gitee.com/kubelsp/upload/raw/master/calico/v3.27.3/calico.yaml
```

```shell
1 修改CIDR
- name: CALICO_IPV4POOL_CIDR
  value: "10.244.0.0/16"

2 指定网卡
# Cluster type to identify the deployment type
  - name: CLUSTER_TYPE
  value: "k8s,bgp"
# 下面添加
  - name: IP_AUTODETECTION_METHOD
    value: "interface=ens33,ens160"
    # ens33为本地网卡名字（自己机器啥网卡就改啥）
```

```shell
# 1 修改CIDR
sed -i 's/192\.168/10\.244/g' calico.yaml

sed -i 's/# \(- name: CALICO_IPV4POOL_CIDR\)/\1/' calico.yaml
sed -i 's/# \(\s*value: "10.244.0.0\/16"\)/\1/' calico.yaml
```

```shell
# 2 指定网卡（ens33为本地网卡名字（自己机器啥网卡就改啥））
sed -i '/value: "k8s,bgp"/a \            - name: IP_AUTODETECTION_METHOD' \calico.yaml

sed -i '/- name: IP_AUTODETECTION_METHOD/a \              value: "interface=ens33,ens160"' \calico.yaml
```

```shell
kubectl apply -f ~/calico-yml/calico.yaml
```

### 5、coredns 解析测试是否正常

```shell
[root@k8s-master ~]# kubectl run -it --rm dns-test --image=busybox:1.36.1 sh
If you don't see a command prompt, try pressing enter.
/ # nslookup kubernetes
Server:    10.96.0.10
Address 1: 10.96.0.10 kube-dns.kube-system.svc.cluster.local   # 看到这个说明dns解析正常

Name:      kubernetes
Address 1: 10.96.0.1 kubernetes.default.svc.cluster.local
/ #
```

```shell
kubectl run -it --rm dns-test --image=busybox:1.36.1 sh

kubectl run -it --rm dns-test --image=ccr.ccs.tencentyun.com/huanghuanhui/busybox:1.36.1 sh
```

```shell
nslookup kubernetes.default.svc.cluster.local
```

### 6、k8s-node节点后期的加入命令（按照上面操作安装好containerd、kubeadm、kubelet、kubectl）

```shell
kubeadm token list

kubeadm token create --print-join-command
```

