### helm、kubens、kubectl补全

helm

> https://github.com/helm/helm

```powershell
cd && wget https://repo.huaweicloud.com/helm/v3.15.3/helm-v3.15.3-linux-amd64.tar.gz

tar xf ~/helm-v3.15.3-linux-amd64.tar.gz

cp ~/linux-amd64/helm /usr/local/sbin/helm

rm -rf ~/helm-v3.15.3-linux-amd64.tar.gz && rm -rf ~/linux-amd64

helm version
```

kubectx、kubens

```powershell
# wget -O /usr/local/sbin/kubens https://github.com/ahmetb/kubectx/raw/v0.9.5/kubens 

# chmod +x /usr/local/sbin/kubens

# wget -O /usr/local/sbin/kubectx https://github.com/ahmetb/kubectx/raw/v0.9.5/kubectx

# chmod +x /usr/local/sbin/kubectx
```

```powershell
wget -O /usr/local/sbin/kubens https://gitee.com/kubelsp/upload/raw/master/kubens/v0.9.5/kubens 

chmod +x /usr/local/sbin/kubens

wget -O /usr/local/sbin/kubectx https://gitee.com/kubelsp/upload/raw/master/kubens/v0.9.5/kubectx

# chmod +x /usr/local/sbin/kubectx
```

kubectl 补全

```powershell
yum -y install bash-completion

source /etc/profile.d/bash_completion.sh

echo "source <(crictl completion bash)" >> ~/.bashrc
echo "source <(kubectl completion bash)" >> ~/.bashrc
echo "source <(helm completion bash)" >> ~/.bashrc

source ~/.bashrc && su -
```

别名

```shell
cat >> ~/.bashrc << 'EOF'
alias pod='kubectl get pod'
alias po='kubectl get pod'
alias svc='kubectl get svc'
alias ns='kubectl get ns'
alias pvc='kubectl get pvc'
alias pv='kubectl get pv'
alias sc='kubectl get sc'
alias cm='kubectl get cm'
alias sa='kubectl get sa'
alias kn='kubectl get node'
alias ingress='kubectl get ingress'
alias all='kubectl get all'
alias deployment='kubectl get deployments'
alias daemonset='kubectl get daemonsets'
alias sts='kubectl get statefulsets'
alias vs='kubectl get vs'
alias gateway='kubectl get gateway'
EOF

source ~/.bashrc
```

