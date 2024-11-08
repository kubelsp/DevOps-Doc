###### Docker部署OpenVPN

开路由转发，1是开启，0是关闭

```shell
echo 1 > /proc/sys/net/ipv4/ip_forward
```

```shell
docker pull chenji1506/openvpn:2.4.8

docker pull ccr.ccs.tencentyun.com/huanghuanhui/openvpn:2.4.8
```

```shell
mkdir -p ~/openvpn-data/conf
```

###### 生成配置文件

```shell
docker run -v ~/openvpn-data:/etc/openvpn --rm ccr.ccs.tencentyun.com/huanghuanhui/openvpn:2.4.8 ovpn_genconfig -u udp://1.15.172.119
```

> 1.15.172.119 是公网IP

###### 生成密钥文件

```shell
docker run -v ~/openvpn-data:/etc/openvpn --rm -it ccr.ccs.tencentyun.com/huanghuanhui/openvpn:2.4.8 ovpn_initpki

	Enter New CA Key Passphrase: 123456									# 输入私钥密码
	Re-Enter New CA Key Passphrase: 123456								# 重新输入一次密码
	Common Name (eg: your user,host,or server name) [Easy-RSA CA]: 		# 输入一个CA名称。可以不用输入，直接回车
	Enter pass phrase for /etc/openvpn/pki/private/ca.key: 123456		# 输入刚才设置的私钥密码
	Enter pass phrase for /etc/openvpn/pki/private/ca.key: 123456		# 输入刚才设置的私钥密码
```

###### 启动openvpn

```shell
docker run --name openvpn -v ~/openvpn-data:/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN ccr.ccs.tencentyun.com/huanghuanhui/openvpn:2.4.8
```

###### openvpn用户管理 -- 添加用户脚本

```shel
cat > add_user.sh << 'EOF'
#!/bin/bash
read -p "please your username: " NAME
docker run -v ~/openvpn-data:/etc/openvpn --rm -it ccr.ccs.tencentyun.com/huanghuanhui/openvpn:2.4.8 easyrsa build-client-full $NAME nopass
docker run -v ~/openvpn-data:/etc/openvpn --rm ccr.ccs.tencentyun.com/huanghuanhui/openvpn:2.4.8 ovpn_getclient $NAME > ~/openvpn-data/conf/"$NAME".ovpn
docker restart openvpn
EOF

chmod +x add_user.sh
```

```shell
./add_user.sh	# 输入要添加的用户名，回车后输入刚才创建的私钥密码

Enter pass phrase for /etc/openvpn/pki/private/ca.key: 123456		# 输入刚才设置的密码
```

###### openvpn用户管理 -- 删除用户脚本

```shell
cat > del_user.sh << 'EOF'
#!/bin/bash
read -p "Delete username: " DNAME
docker run -v ~/openvpn-data:/etc/openvpn --rm -it ccr.ccs.tencentyun.com/huanghuanhui/openvpn:2.4.8 easyrsa revoke $DNAME
docker run -v ~/openvpn-data:/etc/openvpn --rm -it ccr.ccs.tencentyun.com/huanghuanhui/openvpn:2.4.8 easyrsa gen-crl
docker run -v ~/openvpn-data:/etc/openvpn --rm -it ccr.ccs.tencentyun.com/huanghuanhui/openvpn:2.4.8 rm -f /etc/openvpn/pki/reqs/"DNAME".req
docker run -v ~/openvpn-data:/etc/openvpn --rm -it ccr.ccs.tencentyun.com/huanghuanhui/openvpn:2.4.8 rm -f /etc/openvpn/pki/private/"DNAME".key
docker run -v ~/openvpn-data:/etc/openvpn --rm -it ccr.ccs.tencentyun.com/huanghuanhui/openvpn:2.4.8 rm -f /etc/openvpn/pki/issued/"DNAME".crt
docker restart openvpn
EOF

chmod +x del_user.sh
```

```shell
./del_user.sh
```

