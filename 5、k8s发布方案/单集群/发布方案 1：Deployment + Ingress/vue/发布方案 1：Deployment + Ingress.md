```shell
export AppName=prod-vue
export Port=80

cat > ${AppName}.yml << EOF
# 1、Deployment
# 2、Service
# 3、Ingress
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${AppName}
  namespace: prod
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ${AppName}
  template:
    metadata:
      annotations:
        prometheus.io/prod-java: "true"
        prometheus.io/path: /metrics
        prometheus.io/port: "${Port}"
      labels:
        app: ${AppName}
    spec:
      imagePullSecrets:
        - name: image-secret
      containers:
      - name: ${AppName}
        image: ccr.ccs.tencentyun.com/huanghuanhui/${AppName}:8f897fd-1
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: ${Port}
          name: http
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /
            port: ${Port}
          initialDelaySeconds: 15
          periodSeconds: 20
          timeoutSeconds: 5
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /
            port: ${Port}
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        resources:
          requests:
            cpu: "0.5"
            memory: 2Gi
          limits:
            cpu: "1"
            memory: 4Gi
        volumeMounts:
        - name: localtime
          mountPath: /etc/localtime
        - name: nfs
          mountPath: /nfs
      volumes:
      - name: localtime
        hostPath:
          path: /etc/localtime
      - name: nfs
        persistentVolumeClaim:
          claimName: nfs-pvc
          
---
apiVersion: v1
kind: Service
metadata:
  name: ${AppName}-svc
  namespace: prod
  labels:
    app: ${AppName}
spec:
  selector:
    app: ${AppName}
  type: ClusterIP
  ports:
  - name: http
    port: ${Port}
    targetPort: http

---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${AppName}-ingress
  namespace: prod
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: www.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ${AppName}-svc
            port:
              number: ${Port}
  tls:
  - hosts:
    - api.openhhh.com
    secretName: openhhh.com-ingress-tls
EOF
```