```shell
export AppName=prod-gateway
export Port=9999

cat > ${AppName}.yml << EOF
# 1、Rollout
# 2、Service
# 3、VirtualService
# 4、Gateway
---
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: ${AppName}
  namespace: prod
spec:
  replicas: 3
  strategy:
    canary:
      steps:
      - setWeight: 20
      - pause: {} # 人工卡点
      - setWeight: 40
      - pause: {duration: 10}
      - setWeight: 60
      - pause: {duration: 10}
      - setWeight: 80
      - pause: {duration: 10}
      - setWeight: 100
      - pause: {} # 人工卡点
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: ${AppName}
  template:
    metadata:
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
        image: ccr.ccs.tencentyun.com/huanghuanhui/${AppName}:8f897fd-2
        imagePullPolicy: IfNotPresent
        name: ${AppName}
        ports:
        - containerPort: ${Port}
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
  name: ${AppName}-svc-canary
  namespace: prod
  labels:
    app: ${AppName}
spec:
  type: ClusterIP
  ports:
  - name: web
    port: 9090
    targetPort: http
  selector:
    app: ${AppName}
    # This selector will be updated with the pod-template-hash of the canary ReplicaSet. e.g.:
    # rollouts-pod-template-hash: 7bf84f9696

---
apiVersion: v1
kind: Service
metadata:
  name: ${AppName}-svc-stable
  namespace: prod
  labels:
    app: ${AppName}
spec:
  type: ClusterIP
  ports:
  - name: web
    port: 9090
    targetPort: http
  selector:
    app: ${AppName}
    # This selector will be updated with the pod-template-hash of the canary ReplicaSet. e.g.:
    # rollouts-pod-template-hash: 789746c88d

---
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: ${AppName}-vs
  namespace: prod
spec:
  gateways:
  - ${AppName}-gateway
  hosts:
  - "*"
  http:
  - name: primary
    match:
    - headers:
        x-canary:
          exact: test-user
      uri:
        prefix: /
    route:
    - destination:
        host: ${AppName}-svc-stable
      weight: 0
    - destination:
        host: ${AppName}-svc-canary
      weight: 100
  - route:
    - destination:
        host: ${AppName}-svc-stable
      weight: 100

---
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: ${AppName}-gateway
  namespace: prod
spec:
  selector:
    istio: ingressgateway # 默认创建的 istio ingressgateway pod 有这个 Label
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "gateway.openhhh.com" # 匹配 host
EOF
```