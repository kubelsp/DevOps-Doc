```shell
kubectl create secret -n prod \
tls openhhh.com-ingress-tls \
--key=/root/ssl/openhhh.com.key \
--cert=/root/ssl/openhhh.com.pem
```