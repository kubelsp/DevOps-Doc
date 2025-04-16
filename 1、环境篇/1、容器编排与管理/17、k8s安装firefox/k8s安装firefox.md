###### k8s安装firefox

`````shell
cat > firefox.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: firefox
  namespace: firefox
spec:
  replicas: 1
  selector:
    matchLabels:
      app: firefox
  template:
    metadata:
      labels:
        app: firefox
    spec:
      containers:
      - name: firefox
        #image: jlesage/firefox:v24.11.1
        #image: ccr.ccs.tencentyun.com/huanghuanhui/firefox:v24.11.1
        image: registry.cn-hangzhou.aliyuncs.com/jingsocial/firefox:v24.11.1
        ports:
        - containerPort: 5800
        env:
        - name: TZ
          value: Asia/Shanghai
        - name: LANG
          value: zh_CN.UTF-8
        - name: VNC_PASSWORD
          value: Admin@2024

---
apiVersion: v1
kind: Service
metadata:
  name: firefox-svc
  namespace: firefox
spec:
  selector:
    app: firefox
  ports:
    - protocol: TCP
      port: 5800
      targetPort: 5800
      nodePort: 30798
  type: NodePort
EOF
`````

````shell

 docker run -d \
    --name=firefox \
    -p 5800:5800 \
     -e LANG=zh_CN.UTF-8 \
     -e ENABLE_CJK_FONT=1 \
 -e TZ=Asia/Shanghai \
 -e VNC_PASSWORD=Admin@2024 \
ccr.ccs.tencentyun.com/huanghuanhui/firefox:v24.11.1

 docker run -d \
    --name=firefox \
    -p 5800:5800 \
     -e LANG=zh_CN.UTF-8 \
 -e TZ=Asia/Shanghai \
 -e VNC_PASSWORD=Admin@2024 \
ccr.ccs.tencentyun.com/huanghuanhui/firefox:v24.11.1

fc-list | grep Noto
````

```shell
docker run -d --name firefox 
-e TZ=Asia/Shanghai 
-e DISPLAY_WIDTH=1920 -e DISPLAY_HEIGHT=1080
-e KEEP_APP_RUNNING=1 
-e ENABLE_CJK_FONT=1  -e VNC_PASSWORD=admin  -p 5800:5800 -p 5900:5900 -v /data/firefox/config:/config:rw --shm-size 2g jlesage/firefox


-e TZ=Asia/Hong_Kong ##这个是设置地区。
 
-e DISPLAY_WIDTH=1920
 
-e DISPLAY_HEIGHT=1080 ##设置显示的高宽
 
-e KEEP_APP_RUNNING=1 ##关闭了之后会自动重启，不然所有标签页关闭了，浏览器也就关了。
 
-e ENABLE_CJK_FONT=1 ##一定要加这个，不然中文显示乱码
 
-e SECURE_CONNECTION=1 ##启用 HTTPS，再绑定域名，安全一点点
 
-e VNC_PASSWORD=xxxxxxxx ##访问密码，不然谁打开都能用了
 
-p 5800:5800 -p 5900:5900 ##端口映射
 
-v /www/firefox:/config:rw ##数据，包括下载的东西，不然不好找。
 
–shm-size 2g ##内存使用，单位m或是g，建议是2g
```



