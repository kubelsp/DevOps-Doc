```shell
export AppName=prod-gateway
export Port=9999

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
      - command:
        - java
        - -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=5005
        - -Xss512k
        - -XX:+UseG1GC
        - -XX:InitialRAMPercentage=25.0
        - -XX:MaxRAMPercentage=80.0
        - -XX:NewRatio=4
        - -XX:-UseAdaptiveSizePolicy
        - -XX:+PrintGCDetails
        - -XX:+PrintGCDateStamps
        - -XX:+PrintTenuringDistribution
        - -XX:+PrintHeapAtGC
        - -XX:+PrintReferenceGC
        - -XX:+PrintGCApplicationStoppedTime
        - -Xloggc:/var/logs/gc-%t.log
        - -XX:+HeapDumpOnOutOfMemoryError
        - -XX:HeapDumpPath=/var/logs/dump-$(date '+%s').hprof
        - -XX:+UseGCLogFileRotation
        - -XX:NumberOfGCLogFiles=15
        - -XX:GCLogFileSize=50M
        - -jar
        - /usr/local/src/${AppName}.jar
        - --spring.profiles.active=live
        image: ccr.ccs.tencentyun.com/huanghuanhui/${AppName}:8f897fd-1
        imagePullPolicy: IfNotPresent
        name: ${AppName}
        ports:
        - containerPort: ${Port}
          name: http
          protocol: TCP
        livenessProbe:
          failureThreshold: 3
          httpGet:
            scheme: HTTP
            port: ${Port}
            path: /actuator/health
          initialDelaySeconds: 180
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 1
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /actuator/health
            scheme: HTTP
            port: ${Port}
          initialDelaySeconds: 180
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 1
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
    cert-manager.io/cluster-issuer: prod-issuer 
    acme.cert-manager.io/http01-edit-in-place: "true" 
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: api.openhhh.com
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