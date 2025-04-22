###### k8s-cronjob

```shell
mkdir ~/k8s-cronjob-yml

kubectl create ns k8s-cronjob
```

````shell
cat > ~/k8s-cronjob-yml/clean-failed-pods-cronjob.yml  << 'EOF'
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: pod-cleaner-admin
  namespace: k8s-cronjob

---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pod-cleaner-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: pod-cleaner-admin
  namespace: k8s-cronjob

---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: clean-failed-pods
  namespace: k8s-cronjob
spec:
  schedule: "*/30 * * * *"  # 每 30 分钟执行一次
  jobTemplate:
    spec:
      ttlSecondsAfterFinished: 60  # <-- Job 完成后 60 秒自动清理 Pod
      template:
        spec:
          serviceAccountName: pod-cleaner-admin
          containers:
            - name: clean-failed-pods
              image: registry.cn-hangzhou.aliyuncs.com/jingsocial/kubectl:bitnami-1.32.3
              command:
                - /bin/bash
                - -c
                - |
                  kubectl get po -n live-jingsocial |grep 0/ | grep -v 'clean-failed-pods' | awk '{print $1}' | xargs -i kubectl delete pod {} -n live-jingsocial
          restartPolicy: OnFailure
EOF
````

