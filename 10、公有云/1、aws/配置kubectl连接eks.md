1、eks-devops

```shell
aws sts get-caller-identity

aws eks update-kubeconfig --region ap-southeast-1 --name eks-devops
```

2、prod-eks

```shell
aws sts get-caller-identity

aws eks update-kubeconfig --region ap-southeast-1 --name prod-eks
```

```shell
aws sts get-caller-identity

aws eks update-kubeconfig --region ap-southeast-3 --name eks-idn
```



3、

```shell
aws sts get-caller-identity

aws eks update-kubeconfig --region sa-east-1 --name eks-br-bp
```

4、

```shell
aws sts get-caller-identity

aws eks update-kubeconfig --region sa-east-1 --name eks-br-tr
```

5、

````shell
aws sts get-caller-identity

aws eks update-kubeconfig --region sa-east-1 --name eks-br-mh
````



```helll
git commit -m "2025-11-03"

git push origin main
```

```shell
rocketmq-broker-idn-bp-master-pvc-rocketmq-broker-idn-bp-master-0 
```

```shell
cat > ~/.aws/config << 'EOF'
[default]
region = ap-southeast-1
output = json
EOF

cat > ~/.aws/credentials << 'EOF'
[default]
aws_access_key_id = xxxxxxxxxxxxx
aws_secret_access_key = xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
EOF
```

