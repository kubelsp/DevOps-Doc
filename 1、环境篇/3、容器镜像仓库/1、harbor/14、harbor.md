### 14、harbor

> 2c4g、400g
>
> harbor（centos-7.9）（4c8g-400g）
>
> docker-compose安装harbor-v2.10.2

```shell
echo "PS1='\[\033[35m\][\[\033[00m\]\[\033[31m\]\u\[\033[33m\]\[\033[33m\]@\[\033[03m\]\[\033[35m\]\h\[\033[00m\] \[\033[5;32m\]\w\[\033[00m\]\[\033[35m\]]\[\033[00m\]\[\033[5;31m\]\\$\[\033[00m\] '" >> ~/.bashrc && source ~/.bashrc

hostnamectl set-hostname harbor && su -
```

###### 1、安装 docker（脚本）一键部署指定版本 docker

```shell
curl -sSL https://get.docker.com | sh
```

```shell
systemctl enable docker --now
```

###### 2、安装 docker-compose

官方文档：https://docs.docker.com/compose/install/

github：https://github.com/docker/compose/releases/

```shell
wget -O /usr/local/sbin/docker-compose https://github.com/docker/compose/releases/download/v2.26.1/docker-compose-linux-x86_64

chmod +x /usr/local/sbin/docker-compose
```

###### 3、安装 harbor

https://github.com/goharbor/harbor/releases （离线下载上传）

```shell
wget https://github.com/goharbor/harbor/releases/download/v2.10.2/harbor-offline-installer-v2.10.2.tgz
```

```shell
cd && tar xf harbor-offline-installer-v2.10.2.tgz -C /usr/local/
```

```shell
ls -la /usr/local/harbor/

cp /usr/local/harbor/harbor.yml.tmpl /usr/local/harbor/harbor.yml
```

```shell
修改配置文件:
#  harbor.yml
1、改成本机ip（域名）
hostname: harbor.openhhh.com

2、修改https协议证书位置
https:
  port: 443
  certificate: /root/ssl/openhhh.com.pem
  private_key: /root/ssl/openhhh.com.key

3、修改登录密码（生产环境一定要修改）
harbor_admin_password: Admin@2024
```

```shell
sed -i.bak 's/reg\.mydomain\.com/harbor.openhhh.com/g' /usr/local/harbor/harbor.yml

sed -i 's#certificate: .*#certificate: /root/ssl/openhhh.com.pem#g' /usr/local/harbor/harbor.yml

sed -i 's#private_key: .*#private_key: /root/ssl/openhhh.com.key#g' /usr/local/harbor/harbor.yml

sed -i 's/Harbor12345/Admin@2024/g' /usr/local/harbor/harbor.yml
```

```shell
# ./install.sh（执行安装脚本）
/usr/local/harbor/install.sh
```

```shell
docker ps |grep harbor
```

> 访问地址：https://harbor.openhhh.com
>
> 账号密码：admin、Admin@2024

```shell
docker login harbor.openhhh.com --username=admin

Admin@2024
```

```shell
docker pull nginx:1.25.3-alpine

docker tag nginx:1.25.3-alpine harbor.openhhh.com/nginx/nginx:1.25.3-alpine

docker push harbor.openhhh.com/nginx/nginx:1.25.3-alpine
```

