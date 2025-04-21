### Jenkins（Argo-Rollout）

k8s手撕yml方式部署最新版 Jenkins-2.506（jdk-21版）（Jenkins）

> https://github.com/jenkinsci/jenkins
>
>https://hub.docker.com/r/jenkins/jenkins/
>
> k8s-v1.31.2
>
> Jenkins-2.506

```shell
mkdir -p ~/jenkins-yml

kubectl create ns jenkins
```

```shell
# kubectl label node k8s-jenkins jenkins=jenkins

kubectl label node k8s-node1 jenkins=jenkins
```

```shell
cat > ~/jenkins-yml/jenkins-rbac.yml << 'EOF'
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-admin
  namespace: jenkins

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: jenkins-admin
rules:
  - apiGroups: [""]
    resources: ["*"]
    verbs: ["*"]

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: jenkins-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: jenkins-admin
subjects:
- kind: ServiceAccount
  name: jenkins-admin
  namespace: jenkins
EOF
```

```shell
kubectl apply -f ~/jenkins-yml/jenkins-rbac.yml
```

```shell
cat > ~/jenkins-yml/jenkins-svc-stable.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: jenkins-svc-stable
  namespace: jenkins
  labels:
    app: jenkins
spec:
  selector:
    app: jenkins
  type: NodePort
  ports:
  - name: web
    nodePort: 30798
    port: 8080
    targetPort: web
  - name: agent
    nodePort: 30897
    port: 50000
    targetPort: agent
EOF
```

```shell
cat > ~/jenkins-yml/jenkins-svc-canary.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: jenkins-svc-canary
  namespace: jenkins
  labels:
    app: jenkins
spec:
  selector:
    app: jenkins
  type: NodePort
  ports:
  - name: web
    nodePort: 30456
    port: 8080
    targetPort: web
  - name: agent
    nodePort: 30654
    port: 50000
    targetPort: agent
EOF
```

```shell
kubectl apply -f ~/jenkins-yml/jenkins-svc-stable.yml

kubectl apply -f ~/jenkins-yml/jenkins-svc-canary.yml
```

```shell
cat > ~/jenkins-yml/jenkins-pvc.yml << 'EOF'
apiVersion: v1
kind:  PersistentVolumeClaim
metadata:
  name: jenkins-pvc
  namespace: jenkins
spec:
  storageClassName: "nfs-storage"
  accessModes: [ReadWriteMany]
  resources:
    requests:
      storage: 2Ti
EOF
```

````shell
kubectl apply -f ~/jenkins-yml/jenkins-pvc.yml
````

```shell
cat > ~/jenkins-yml/jenkins-rollout.yml << 'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: jenkins
  namespace: jenkins
spec:
  replicas: 1
  strategy:
    canary:
      canaryService: jenkins-svc-canary
      stableService: jenkins-svc-stable
      steps:
      - setWeight: 20
      - pause: {duration: 10}
      - setWeight: 40
      - pause: {duration: 10}
      - setWeight: 60
      - pause: {duration: 10}
      - setWeight: 80
      - pause: {} # 人工卡点
      - setWeight: 100
      - pause: {duration: 10}
  revisionHistoryLimit: 2
  selector:
    matchLabels:
      app: jenkins
  template:
    metadata:
      labels:
        app: jenkins
    spec:
      tolerations:
      - effect: NoSchedule
        key: no-pod
        operator: Exists
      nodeSelector:
        jenkins: jenkins
      serviceAccountName: jenkins-admin
      securityContext:
        fsGroup: 0
      containers:
      - name: jenkins
        #image: jenkins/jenkins:2.506-jdk21
        image: ccr.ccs.tencentyun.com/huanghuanhui/jenkins:2.506-jdk21
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
          name: web
          protocol: TCP
        - containerPort: 50000
          name: agent
          protocol: TCP
        resources:
          limits:
            cpu: "2"
            memory: "4Gi"
          requests:
            cpu: "1"
            memory: "2Gi"
        env:
        - name: LIMITS_MEMORY
          valueFrom:
            resourceFieldRef:
              resource: limits.memory
              divisor: 1Mi
        - name: JAVA_OPTS
          value: -Dhudson.security.csrf.GlobalCrumbIssuerConfiguration.DISABLE_CSRF_PROTECTION=true
        volumeMounts:
        - name: jenkins-home
          mountPath: /var/jenkins_home
        - mountPath: /etc/localtime
          name: localtime
      volumes:
      - name: jenkins-home
        persistentVolumeClaim:
          claimName: jenkins-pvc
      - name: localtime
        hostPath:
          path: /etc/localtime
EOF
```

```shell
kubectl apply -f ~/jenkins-yml/jenkins-rollout.yml
```

```shell
cat > ~/jenkins-yml/jenkins-ingress.yml << 'EOF'
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jenkins-ingress
  namespace: jenkins
  annotations:
    cert-manager.io/cluster-issuer: prod-issuer 
    acme.cert-manager.io/http01-edit-in-place: "true" 
    nginx.ingress.kubernetes.io/ssl-redirect: 'true'
    nginx.ingress.kubernetes.io/proxy-body-size: '4G'
spec:
  ingressClassName: nginx
  rules:
  - host: jenkins.openhhh.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: jenkins # 将所有请求发送到 jenkins 服务的 8080 端口
            port:
              number: 8080
  tls:
  - hosts:
    - jenkins.openhhh.com
    secretName: jenkins-ingress-tls
EOF
```

```shell
#kubectl create secret -n jenkins \
#tls jenkins-ingress-tls \
#--key=/root/ssl/openhhh.com.key \
#--cert=/root/ssl/openhhh.com.pem
```

```shell
kubectl apply -f ~/jenkins-yml/jenkins-ingress.yml
```

> 访问地址：https://jenkins.openhhh.com
>
> 设置账号密码为：admin、Admin@2024

```shell
# 插件
1、Localization: Chinese (Simplified)
2、Pipeline
3、Kubernetes
4、Git
5、Git Parameter
6、GitLab				   # webhook 触发构建
7、Config FIle Provider		# 连接远程k8s集群
#8、Extended Choice Parameter
9、SSH Pipeline Steps		# Pipeline通过ssh远程执行命令
10、Pipeline: Stage View
11、Role-based Authorization Strategy
12、DingTalk				   # 钉钉机器人

http://jenkins.jenkins:8080

https://updates.jenkins.io/update-center.json
https://mirrors.huaweicloud.com/jenkins/updates/update-center.json
```

```shell
cat > ~/jenkins-yml/jenkins-slave-maven-cache-pvc.yml << 'EOF'
apiVersion: v1
kind:  PersistentVolumeClaim
metadata:
  name: jenkins-slave-maven-cache-pvc
  namespace: jenkins
spec:
  storageClassName: "nfs-storage"
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 2Ti
EOF
```

```shell
cat > ~/jenkins-yml/jenkins-slave-node-cache-pvc.yml << 'EOF'
apiVersion: v1
kind:  PersistentVolumeClaim
metadata:
  name: jenkins-slave-node-cache-pvc
  namespace: jenkins
spec:
  storageClassName: "nfs-storage"
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 2Ti
EOF
```

```shell
cat > ~/jenkins-yml/jenkins-slave-golang-cache-pvc.yml << 'EOF'
apiVersion: v1
kind:  PersistentVolumeClaim
metadata:
  name: jenkins-slave-golang-cache-pvc
  namespace: jenkins
spec:
  storageClassName: "nfs-storage"
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 2Ti
EOF

cat > ~/jenkins-yml/jenkins-slave-go-build-cache-pvc.yml << 'EOF'
apiVersion: v1
kind:  PersistentVolumeClaim
metadata:
  name: jenkins-slave-go-build-cache-pvc
  namespace: jenkins
spec:
  storageClassName: "nfs-storage"
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 2Ti
EOF
```

Jenkins （jdk-21）（pipeline）

测试 docker、测试 maven、  测试 node、测试 golang、  测试 gcc、  测试 kubectl

```groovy
#!/usr/bin/env groovy

pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
metadata:
  name: jenkins-slave
  namespace: jenkins
spec:
  tolerations:
  - key: "no-pod"
    operator: "Exists"
    effect: "NoSchedule"
  containers:
  - name: docker
    #image: docker:27.1.1
    image: ccr.ccs.tencentyun.com/huanghuanhui/docker:27.1.1
    imagePullPolicy: IfNotPresent
    readinessProbe:
      exec:
        command: [sh, -c, "ls -S /var/run/docker.sock"]
    command:
    - sleep
    args:
    - 99d
    volumeMounts:
    - name: docker-socket
      mountPath: /var/run
  - name: docker-daemon
    #image: docker:27.1.1-dind
    image: ccr.ccs.tencentyun.com/huanghuanhui/docker:27.1.1-dind
    imagePullPolicy: IfNotPresent
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-socket
      mountPath: /var/run
  - name: maven
    #image: maven:3.8.1-jdk-8
    image: ccr.ccs.tencentyun.com/huanghuanhui/maven:3.8.1-jdk-8
    imagePullPolicy: IfNotPresent
    command:
    - sleep
    args:
    - 99d
    volumeMounts:
    - name: maven-cache
      mountPath: /root/.m2/repository
  - name: node
    #image: node:16.17.0-alpine
    image: ccr.ccs.tencentyun.com/huanghuanhui/node:16.17.0-alpine
    imagePullPolicy: IfNotPresent
    command:
    - sleep
    args:
    - 99d
    volumeMounts:
    - name: node-cache
      mountPath: /root/.npm
  - name: golang
    #image: golang:1.22.2
    image: ccr.ccs.tencentyun.com/huanghuanhui/golang:1.22.2
    imagePullPolicy: IfNotPresent
    command:
    - sleep
    args:
    - 99d
  - name: gcc
    #image: gcc:13.2.0
    image: ccr.ccs.tencentyun.com/huanghuanhui/gcc:13.2.0
    imagePullPolicy: IfNotPresent
    command:
    - sleep
    args:
    - 99d
  - name: kubectl
    #image: kostiscodefresh/kubectl-argo-rollouts:v1.6.0
    #image: kubectl:v1.28.4
    image: ccr.ccs.tencentyun.com/huanghuanhui/kubectl:v1.28.4
    imagePullPolicy: IfNotPresent
    command:
    - sleep
    args:
    - 99d
  volumes:
  - name: docker-socket
    emptyDir: {}
  - name: maven-cache
    persistentVolumeClaim:
      claimName: jenkins-slave-maven-cache-pvc
  - name: node-cache
    persistentVolumeClaim:
      claimName: jenkins-slave-node-cache-pvc
'''
        }
    }

    stages {
        stage('测试 docker') {
            steps {
              container('docker') {
                sh """
                  docker version
                """
                }
            }
        }

        stage('测试 maven') {
            steps {
              container('maven') {
                sh """
                  mvn -version && java -version && javac -version
                """
                }
            }
        }

        stage('测试 node') {
            steps {
              container('node') {
                sh """
                  node --version && npm --version && yarn --version
                """
                }
            }
        }

        stage('测试 golang') {
            steps {
              container('golang') {
                sh """
                  go version
cat > HelloWorld.go << 'EOF'
package main

import "fmt"

func main() {
    fmt.Println("Hello, world! My Name is go!")
}
EOF

go build -o HelloWorld-go HelloWorld.go && ./HelloWorld-go
                """
                }
            }
        }

        stage('测试 gcc') {
            steps {
              container('gcc') {
                sh """
                  gcc --version && g++ --version && make --version
cat > HelloWorld.cpp << 'EOF'
#include <iostream>

int main() {
    std::cout << "Hello, World! My Name is C++!" << std::endl;
    return 0;
}
EOF

g++ -o HelloWorld-cpp HelloWorld.cpp && ./HelloWorld-cpp
                """
                }
            }
        }

        stage('测试 kubectl') {
            steps {
              container('kubectl') {
                sh """
                  kubectl get node
                """
                }
            }
        }

    }
}
```
