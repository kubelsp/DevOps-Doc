###### pod 级别

```shel
      - job_name: 'Java-prod'
        kubernetes_sd_configs:
        - role: pod
          namespaces:
            names:
            - prod
        relabel_configs:
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrapeprod]
          action: keep
          regex: 'true'
        - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
          action: replace
          target_label: __address__
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
```

###### svc 级别

````shell
      - job_name: 'Java-prod'
        kubernetes_sd_configs:
        - role: endpoints
          namespaces:
            names:
            - prod
        relabel_configs:
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_scrapeprod]
          action: keep
          regex: 'true'
        - source_labels: [__meta_kubernetes_service_annotation_prometheus_io_path]
          action: replace
          target_label: __metrics_path__
          regex: (.+)
        - source_labels: [__address__, __meta_kubernetes_service_annotation_prometheus_io_port]
          action: replace
          target_label: __address__
          regex: ([^:]+)(?::\d+)?;(\d+)
          replacement: $1:$2
````

