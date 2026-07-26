output "release_name" {
  value       = helm_release.kube_prometheus_stack.name
  description = "Імʼя встановленого helm-релізу"
}

output "namespace" {
  value       = helm_release.kube_prometheus_stack.namespace
  description = "Namespace, куди встановлено стек"
}

output "chart_version" {
  value       = helm_release.kube_prometheus_stack.version
  description = "Фактично встановлена версія чарта"
}

output "release_status" {
  value       = helm_release.kube_prometheus_stack.status
  description = "Статус релізу після apply (очікується deployed)"
}
