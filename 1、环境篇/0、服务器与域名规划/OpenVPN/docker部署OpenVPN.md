## docker部署openvpn

发布于 2023-07-22 11:15:31





# 拉取openvpn镜像

```javascript
docker pull chenji1506/openvpn:2.4.8
```

复制

# 创建目录

```javascript
mkdir -pv /data/openvpn/conf
```

复制

# 生成配置文件

*1.1.1.1是本机的*[*公网IP*](https://cloud.tencent.com/product/eip?from_column=20420&from=20420)*，按需改成自己的IP*

```javascript
docker run -v /data/openvpn:/etc/openvpn --rm chenji1506/openvpn:2.4.8 ovpn_genconfig -u udp://58.34.61.158
```

复制

# 生成密钥文件

*要求输入私钥密码*

```javascript
docker run -v /data/openvpn:/etc/openvpn --rm -it chenji1506/openvpn:2.4.8 ovpn_initpki
	Enter PEM pass phrase: 123456										# 输入私钥密码
	Verifying - Enter PEM pass phrase: 123456							# 重新输入一次密码
	Common Name (eg: your user,host,or server name) [Easy-RSA CA]: 		# 输入一个CA名称。可以不用输入，直接回车
	Enter pass phrase for /etc/openvpn/pki/private/ca.key: 123456		# 输入刚才设置的私钥密码，完成后在输入一次
```

复制

# 生成客户端证书

*chenji改成其他名字*

```javascript
docker run -v /data/openvpn:/etc/openvpn --rm -it chenji1506/openvpn:2.4.8 easyrsa build-client-full chenji nopass
	Enter pass phrase for /etc/openvpn/pki/private/ca.key: 123456		# 输入刚才设置的密码
```

复制

# 导出客户端配置

```javascript
docker run -v /data/openvpn:/etc/openvpn --rm chenji1506/openvpn:2.4.8 ovpn_getclient chenji > /data/openvpn/conf/chenji.ovpn
```

复制

# 启动openvpn

```javascript
docker run --name openvpn -v /data/openvpn:/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN chenji1506/openvpn:2.4.8
```

复制

# openvpn用户管理

## 添加用户脚本

*vim add_user.sh*

```javascript
#!/bin/bash
read -p "please your username: " NAME
docker run -v /data/openvpn:/etc/openvpn --rm -it chenji1506/openvpn:2.4.8 easyrsa build-client-full $NAME nopass
docker run -v /data/openvpn:/etc/openvpn --rm chenji1506/openvpn:2.4.8 ovpn_getclient $NAME > /data/openvpn/conf/"$NAME".ovpn
docker restart openvpn
```

复制

## 删除用户脚本

*vim del_user.sh*

```javascript
#!/bin/bash
read -p "Delete username: " DNAME
docker run -v /data/openvpn:/etc/openvpn --rm -it chenji1506/openvpn:2.4.8 easyrsa revoke $DNAME
docker run -v /data/openvpn:/etc/openvpn --rm -it chenji1506/openvpn:2.4.8 easyrsa gen-crl
docker run -v /data/openvpn:/etc/openvpn --rm -it chenji1506/openvpn:2.4.8 rm -f /etc/openvpn/pki/reqs/"DNAME".req
docker run -v /data/openvpn:/etc/openvpn --rm -it chenji1506/openvpn:2.4.8 rm -f /etc/openvpn/pki/private/"DNAME".key
docker run -v /data/openvpn:/etc/openvpn --rm -it chenji1506/openvpn:2.4.8 rm -f /etc/openvpn/pki/issued/"DNAME".crt
docker restart openvpn
```

复制

# 添加用户

```javascript
./add_user.sh	# 输入要添加的用户名，回车后输入刚才创建的私钥密码
```

复制

*创建的证书在/data/openvpn/conf/目录下*

