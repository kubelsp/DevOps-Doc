### Docker 安装Nexus3 快速搭建Maven私有仓库

```shell
docker pull sonatype/nexus3:3.67.1-java11

docker pull ccr.ccs.tencentyun.com/huanghuanhui/nexus3:3.67.1-java11
```

```shell
mkdir -p ~/nexus-data && chown -R 200 ~/nexus-data
```

````shell
docker run -d \
--name nexus3 \
--restart always \
--privileged=true \
-p 8081:8081 \
-v ~/nexus-data:/nexus-data \
ccr.ccs.tencentyun.com/huanghuanhui/nexus3:3.67.1-java11
````

```shell
docker exec -it nexus3 cat /nexus-data/admin.password

23c43bb1-b4da-4408-a53d-03025deabe46
```

> 访问地址：http://192.168.1.11:8081
>
> 用户：admin
>
> 密码：Admin@2024
