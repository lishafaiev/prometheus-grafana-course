---
# Шаблон values для kube-prometheus-stack. Плейсхолдери "долар + фігурні
# дужки" підставляє terraform-функція templatefile() зі змінних модуля
# (тому й у коментарях таку конструкцію писати не можна — розпарсить).
# Вміст відтворює values.yaml заняття 3, щоб реліз відповідав ручному.

prometheus:
  prometheusSpec:
    retention: "${prometheus_retention}"

    # За замовчуванням Prometheus бере лише ServiceMonitor/PodMonitor свого
    # релізу. false = «брати всі у кластері» — потрібно для власних
    # моніторів (weather-service тощо), як і при ручній інсталяції.
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false

    resources:
      requests:
        memory: "${prometheus_memory_request}"
        cpu: "${prometheus_cpu_request}"

grafana:
  enabled: true
  adminPassword: "${grafana_admin_password}"

alertmanager:
  enabled: ${alertmanager_enabled}

nodeExporter:
  enabled: ${node_exporter_enabled}

kubeStateMetrics:
  enabled: ${kube_state_metrics_enabled}
