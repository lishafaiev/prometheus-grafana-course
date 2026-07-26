# Outputs модуля автоматично не зʼявляються у root — їх потрібно
# явно ре-експортувати (модуль ізольований в обидва боки).

output "release_name" {
  value       = module.kube_prometheus_stack.release_name
  description = "Імʼя встановленого helm-релізу"
}

output "namespace" {
  value       = module.kube_prometheus_stack.namespace
  description = "Namespace стека моніторингу"
}

output "chart_version" {
  value       = module.kube_prometheus_stack.chart_version
  description = "Фактично встановлена версія чарта"
}

output "release_status" {
  value       = module.kube_prometheus_stack.release_status
  description = "Статус релізу (очікується deployed)"
}
