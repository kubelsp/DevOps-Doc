#!/bin/sh
set -e

mkdir -p ~/jenkins-dev-yml

kubectl create ns jenkins-dev

cat > ~/jenkins-dev-yml/Jenkins-dev-rbac.yml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: jenkins-dev
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: jenkins-dev
  namespace: jenkins-dev
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: jenkins-dev
rules:
- apiGroups:
  - '*'
  resources:
  - statefulsets
  - services
  - replicationcontrollers
  - replicasets
  - podtemplates
  - podsecuritypolicies
  - pods
  - pods/log
  - pods/exec
  - podpreset
  - poddisruptionbudget
  - persistentvolumes
  - persistentvolumeclaims
  - jobs
  - endpoints
  - deployments
  - deployments/scale
  - daemonsets
  - cronjobs
  - configmaps
  - namespaces
  - events
  - secrets
  verbs:
  - create
  - get
  - watch
  - delete
  - list
  - patch
  - update
- apiGroups:
  - ""
  resources:
  - nodes
  verbs:
  - get
  - list
  - watch
  - update
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: jenkins-dev
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: jenkins-dev
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: system:serviceaccounts:jenkins-dev
EOF

kubectl apply -f ~/jenkins-dev-yml/Jenkins-dev-rbac.yml

cat > ~/jenkins-dev-yml/Jenkins-dev-Service.yml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: jenkins-dev
  namespace: jenkins-dev
  labels:
    app: jenkins-dev
spec:
  selector:
    app: jenkins-dev
  type: NodePort
  ports:
  - name: web
    nodePort: 30456
    port: 8080
    targetPort: web
  - name: agent
    nodePort: 30789
    port: 50000
    targetPort: agent
EOF

cat > ~/jenkins-dev-yml/Jenkins-dev-Deployment.yml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins-dev
  namespace: jenkins-dev
  labels:
    app: jenkins-dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins-dev
  template:
    metadata:
      labels:
        app: jenkins-dev
    spec:
      tolerations:
      - effect: NoSchedule
        key: no-pod
        operator: Exists
#     nodeSelector:
#       jenkins-dev: jenkins-dev
      containers:
      - name: jenkins-dev
        #image: jenkins/jenkins:2.454-jdk21
        image: ccr.ccs.tencentyun.com/huanghuanhui/jenkins:2.454-jdk21
        imagePullPolicy: IfNotPresent
        resources:
          limits:
            cpu: "2"
            memory: "4Gi"
          requests:
            cpu: "1"
            memory: "2Gi"
        securityContext:
          runAsUser: 0
        ports:
        - containerPort: 8080
          name: web
          protocol: TCP
        - containerPort: 50000
          name: agent
          protocol: TCP
        env:
        - name: LIMITS_MEMORY
          valueFrom:
            resourceFieldRef:
              resource: limits.memory
              divisor: 1Mi
        - name: JAVA_OPTS
          value: -Dhudson.security.csrf.GlobalCrumbIssuerConfiguration.DISABLE_CSRF_PROTECTION=true
        volumeMounts:
        - name: jenkins-home-dev
          mountPath: /var/jenkins_home
        - mountPath: /etc/localtime
          name: localtime
      volumes:
      - name: jenkins-home-dev
        persistentVolumeClaim:
          claimName: jenkins-home-dev
      - name: localtime
        hostPath:
          path: /etc/localtime

---
apiVersion: v1
kind:  PersistentVolumeClaim
metadata:
  name: jenkins-home-dev
  namespace: jenkins-dev
spec:
  storageClassName: "nfs-storage"
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 2Ti
EOF

kubectl apply -f ~/jenkins-dev-yml/Jenkins-dev-Deployment.yml
