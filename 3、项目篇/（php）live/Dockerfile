cat > Dockerfile << 'EOF'
FROM php:8.3-fpm-alpine

# 添加 PHP 扩展安装脚本
ADD --chmod=0755 https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

# 安装 PHP 扩展
RUN install-php-extensions \
        gd-2.1.0 \
        zip-1.22.3 \
        imagick/imagick@master \
        redis-6.1.0 \
        event-3.1.4 \
        swoole-5.1.5 \
        xlswriter-1.5.7 \
        mcrypt-1.0.7 \
        mongodb-1.20.0 \
        yaf-3.3.6 \
        @composer-2.8.1

# 安装 Nginx
RUN apk add --no-cache nginx=1.26.2-r0

# 复制 Nginx 配置文件（根据需要添加自己的配置）
COPY default.conf /etc/nginx/http.d/default.conf

# 暴露 Nginx 和 PHP-FPM 端口
EXPOSE 80 9000

# 启动 Nginx 和 PHP-FPM
CMD ["sh", "-c", "nginx && php-fpm"]
EOF