variable "release_name" {
  type        = string
  description = "Імʼя helm-релізу (префікс усіх ресурсів стека)"
  default     = "kps"
}

variable "namespace" {
  type        = string
  description = "Namespace для стека моніторингу"
  default     = "monitoring"
}

variable "chart_name" {
  type        = string
  description = "Імʼя чарта"
  default     = "kube-prometheus-stack"
}

variable "chart_repository" {
  type        = string
  description = "Репозиторій чартів"
  default     = "https://prometheus-community.github.io/helm-charts"
}

variable "chart_version" {
  type        = string
  description = "Версія чарта (фіксується для відтворюваності)"
  default     = "87.19.1"
}

variable "prometheus_retention" {
  type        = string
  description = "Тривалість зберігання метрик у TSDB"
  default     = "10d"
}

variable "prometheus_memory_request" {
  type        = string
  description = "Memory request для Prometheus (скромно під kind)"
  default     = "512Mi"
}

variable "prometheus_cpu_request" {
  type        = string
  description = "CPU request для Prometheus"
  default     = "200m"
}

variable "grafana_admin_password" {
  type        = string
  description = "Пароль admin у Grafana"
  default     = "admin"
  sensitive   = true
}

variable "alertmanager_enabled" {
  type        = bool
  description = "Чи вмикати Alertmanager"
  default     = true
}

variable "node_exporter_enabled" {
  type        = bool
  description = "Чи вмикати node-exporter (DaemonSet на кожній ноді)"
  default     = true
}

variable "kube_state_metrics_enabled" {
  type        = bool
  description = "Чи вмикати kube-state-metrics (стан k8s-обʼєктів)"
  default     = true
}

variable "helm_timeout_seconds" {
  type        = number
  description = "Таймаут операцій Helm, секунд"
  default     = 600
}