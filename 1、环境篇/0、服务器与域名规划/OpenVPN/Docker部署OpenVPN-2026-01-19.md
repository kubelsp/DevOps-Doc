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

