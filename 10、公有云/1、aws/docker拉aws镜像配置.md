  docker拉aws镜像配置

```shell
mkdir -p ~/.aws

cat > ~/.aws/config << 'EOF'
[default]
region = ap-southeast-1
output = json
EOF

cat > ~/.aws/credentials << 'EOF'
[default]
aws_access_key_id = xxxxxxxxxxx
aws_secret_access_key = xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EOF
```

```shell
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin xxxxxxxxxxx.dkr.ecr.ap-southeast-1.amazonaws.com
```

