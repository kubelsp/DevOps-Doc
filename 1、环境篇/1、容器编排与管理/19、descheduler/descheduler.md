###### descheduler

````shell
mkdir -p ~/descheduler-yml

````

```shell
cat > ~/descheduler-yml/deschedulerrbac.yml << 'EOF'
---
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: descheduler-cluster-role
rules:
- apiGroups: ["events.k8s.io"]
  resources: ["events"]
  verbs: ["create", "update"]
- apiGroups: [""]
  resources: ["nodes"]
  verbs: ["get", "watch", "list"]
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "watch", "list"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list", "delete"]
- apiGroups: [""]
  resources: ["pods/eviction"]
  verbs: ["create"]
- apiGroups: ["scheduling.k8s.io"]
  resources: ["priorityclasses"]
  verbs: ["get", "watch", "list"]
- apiGroups: ["policy"]
  resources: ["poddisruptionbudgets"]
  verbs: ["get", "watch", "list"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["create", "update"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  resourceNames: ["descheduler"]
  verbs: ["get", "patch", "delete"]
- apiGroups: ["metrics.k8s.io"]
  resources: ["nodes", "pods"]
  verbs: ["get", "list"]
---
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: descheduler-role
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "watch"]
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: descheduler-sa
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: descheduler-cluster-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: descheduler-cluster-role
subjects:
  - name: descheduler-sa
    kind: ServiceAccount
    namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: descheduler-role-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: descheduler-role
subjects:
  - name: descheduler-sa
    kind: ServiceAccount
    namespace: kube-system
EOF
```

````shell
kubectl apply -f ~/descheduler-yml/deschedulerrbac.yml
````

```shell
cat > ~/descheduler-yml/~/descheduler-cronjob.yml << 'EOF'
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: descheduler-cronjob
  namespace: kube-system
spec:
  schedule: "*/2 * * * *"
  concurrencyPolicy: "Forbid"
  jobTemplate:
    spec:
      template:
        metadata:
          name: descheduler-pod
        spec:
          priorityClassName: system-cluster-critical
          containers:
          - name: descheduler
            image: registry.k8s.io/descheduler/descheduler:v0.32.0
            volumeMounts:
            - mountPath: /policy-dir
              name: policy-volume
            command:
              - "/bin/descheduler"
            args:
              - "--policy-config-file"
              - "/policy-dir/policy.yaml"
              - "--v"
              - "3"
            resources:
              requests:
                cpu: "500m"
                memory: "256Mi"
            livenessProbe:
              failureThreshold: 3
              httpGet:
                path: /healthz
                port: 10258
                scheme: HTTPS
              initialDelaySeconds: 3
              periodSeconds: 10
            securityContext:
              allowPrivilegeEscalation: false
              capabilities:
                drop:
                  - ALL
              privileged: false
              readOnlyRootFilesystem: true
              runAsNonRoot: true
          restartPolicy: "Never"
          serviceAccountName: descheduler-sa
          volumes:
          - name: policy-volume
            configMap:
              name: descheduler-policy-configmap
EOF
```

