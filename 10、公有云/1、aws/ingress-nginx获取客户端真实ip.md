```shell
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress-nginx-controller
  namespace: ingress-nginx
  annotations:
    meta.helm.sh/release-name: ingress-nginx
    meta.helm.sh/release-namespace: ingress-nginx
  labels:
    app.kubernetes.io/component: controller
    app.kubernetes.io/instance: ingress-nginx
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
    app.kubernetes.io/version: 1.14.0
    helm.sh/chart: ingress-nginx-4.14.0
    nginx.ingress.kubernetes.io/compute-full-forwarded-for: "true"
    nginx.ingress.kubernetes.io/forwarded-for-header: X-Forwarded-For
    nginx.ingress.kubernetes.io/use-forwarded-headers: "true"
data:
  enable-underscores-in-headers: "true"
  compute-full-forwarded-for: "true"
  forwarded-for-header: X-Forwarded-For
  use-forwarded-headers: "true"

  # 自定义日志（你要的）
  log-format-upstream: '[$time_iso8601] "$request" $status $request_time $upstream_response_time $remote_addr $host $request_id "$http_user_agent"'
  error-log-level: warn
  generate-request-id: "true"
EOF
```

