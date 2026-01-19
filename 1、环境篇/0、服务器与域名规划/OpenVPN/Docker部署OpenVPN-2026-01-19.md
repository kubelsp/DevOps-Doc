```shell
cat > Dockerfile << 'EOF'
FROM alpine:3.23.0

# 更换为腾讯源
RUN echo "https://mirrors.cloud.tencent.com/alpine/v3.23/main/" > /etc/apk/repositories && \
    echo "https://mirrors.cloud.tencent.com/alpine/v3.23/community/" >> /etc/apk/repositories

# 安装所需的软件包
RUN apk update && \
    apk add --no-cache \
    openvpn easy-rsa && \
    ln -s /usr/share/easy-rsa/easyrsa /bin/easyrsa && \
    cd /etc/openvpn && \
    easyrsa --batch init-pki && \
    easyrsa --batch build-ca nopass && \
    easyrsa --batch --days=36500 build-server-full server nopass && \
    easyrsa --batch --days=36500 build-client-full client nopass && \
    easyrsa --batch --days=36500 gen-crl

# 设置工作目录
WORKDIR /etc/openvpn

# 启动 OpenVPN
CMD ["openvpn", "--config", "/etc/openvpn/openvpn.conf", "--client-config-dir", "/etc/openvpn/ccd", "--crl-verify", "/etc/openvpn/crl.pem"]
EOF
```

```shell
docker build -t ccr.ccs.tencentyun.com/huanghuanhui/openvpn:2.6.16 .
```

```shell
docker run -d \
--name openvpn \
--restart always \
--privileged=true \
-p 1194:1194/udp \
--cap-add=NET_ADMIN \
ccr.ccs.tencentyun.com/huanghuanhui/openvpn:2.6.16
```

https://github.com/OpenVPN/openvpn/issues/307

```shell
iptables -t nat -A POSTROUTING -s 10.172.192.0/24 -d 192.168.2.0/24 -j SNAT --to-source 192.168.2.99
```

> 1、其中10.172.192.0/24是我openvpn分配所给客户端的网段，只要你连接openvpn时，openvpn服务端就会给你的客户端分配一个10.172.192.*随机的一个地址。
>
> 2、192.168.2.0/24 是你访问内网的IP端
>
> 3、192.168.2.99是你将openvpn客户端的地址转化为内网的地址，我这里填写的就是openvpn服务端的内网地址。
>
> 4、添加完成后就可以访问了。命令是在openvpn服务器上命令行打

