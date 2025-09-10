```shell
export AppName=prod-vue
export Port=80

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
  name: ${AppName}-svc-canary
  namespace: prod
  labels:
    app: ${AppName}
spec:
  type: ClusterIP
  ports:
  - name: web
    port: ${Port}
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
    port: ${Port}
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