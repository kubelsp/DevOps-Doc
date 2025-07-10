k8s部署kafka-ui

````shell
cat > ~/elk-yml/kafka-ui.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: kafka-ui
  namespace: elk
  labels:
    app: kafka-ui
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kafka-ui
  template:
    metadata:
      labels:
        app: kafka-ui
    spec:
      containers:
      - name: kafka-ui
        #image: provectuslabs/kafka-ui:v0.7.2
        image: ccr.ccs.tencentyun.com/huanghuanhui/kafka-ui:v0.7.2
        imagePullPolicy: IfNotPresent
        env:
        - name: KAFKA_CLUSTERS_0_NAME
          value: 'kafka-elk'
        - name: KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS
          value: 'kafka-headless:9092'
        - name: DYNAMIC_CONFIG_ENABLED
          value: "true"
        - name: AUTH_TYPE # https://docs.kafka-ui.provectus.io/configuration/authentication/basic-authentication
          value: "LOGIN_FORM"
        - name: SPRING_SECURITY_USER_NAME
          value: "admin"    
        - name: SPRING_SECURITY_USER_PASSWORD
          value: "Admin@2025"
        ports:
        - name: web
          containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: kafka-ui
  namespace: elk
spec:
  selector:
    app: kafka-ui
  type: NodePort
  ports:
  - name: web
    port: 8080
    targetPort: 8080
    nodePort: 30988
EOF
````

