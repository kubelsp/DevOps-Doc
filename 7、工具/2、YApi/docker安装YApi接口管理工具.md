# Docker 部署 YApi



`1、MongoDB`

> 版本：mongo-7.0.8

```shell
docker run -d \
--name yapi-mongodb \
--restart always \
--privileged=true \
-p 27017:27017 \
-v ~/yapi-mongodb-data/mongo:/data/db \
-e MONGO_INITDB_DATABASE=yapi \
-e MONGO_INITDB_ROOT_USERNAME=yapi \
-e MONGO_INITDB_ROOT_PASSWORD=yapi@2024 \
mongo:7.0.8-rc0 --auth
```

```shell
mongosh -u yapi -p yapi@2024 --authenticationDatabase admin mongodb://127.0.0.1:27017/yapi
```

`2、YApi`

```shell
docker run -d \
--name yapi \
--restart=always \
--privileged=true \
-p 3000:3000 \
-e YAPI_ADMIN_ACCOUNT=admin@qq.com \
-e YAPI_ADMIN_PASSWORD=Admin@2024 \
-e YAPI_CLOSE_REGISTER=true \
-e YAPI_DB_SERVERNAME=192.168.1.200 \
-e YAPI_DB_PORT=27017 \
-e YAPI_DB_DATABASE=yapi \
-e YAPI_DB_USER=yapi \
-e YAPI_DB_PASS=yapi@2024 \
-e YAPI_DB_AUTH_SOURCE=admin \
-e YAPI_MAIL_ENABLE=false \
-e YAPI_PLUGINS=[] \
jayfong/yapi:1.10.2
```

> 访问地址：192.168.1.200:3000
>
> 账号名："admin@qq.com"，密码："Admin@2024"
