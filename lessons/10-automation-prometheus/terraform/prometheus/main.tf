# Модуль розгортання kube-prometheus-stack.
#
# Відмінності від прикладу лектора (course-info/lesson 10):
# - замість deprecated `data "template_file"` (провайдер hashicorp/template
#   архівний) використано вбудовану функцію templatefile();
# - namespace створює сам helm_release (create_namespace = true — no-op,
#   якщо namespace вже існує), тому провайдер kubernetes не потрібен;
# - синтаксис провайдера helm v3 (kubernetes-блок як атрибут у root-модулі).

terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name       = var.release_name
  repository = var.chart_repository
  chart      = var.chart_name
  version    = var.chart_version
  namespace  = var.namespace

  # no-op, якщо namespace вже існує (наш випадок: monitoring лишився
  # від ручної інсталяції разом із ConfigMap-ами datasource-ів Loki/Tempo)
  create_namespace = true

  # values рендеряться з шаблону: у values.yaml.tpl підставляються змінні
  values = [templatefile("${path.module}/values.yaml.tpl", {
    prometheus_retention       = var.prometheus_retention
    prometheus_memory_request  = var.prometheus_memory_request
    prometheus_cpu_request     = var.prometheus_cpu_request
    grafana_admin_password     = var.grafana_admin_password
    alertmanager_enabled       = var.alertmanager_enabled
    node_exporter_enabled      = var.node_exporter_enabled
    kube_state_metrics_enabled = var.kube_state_metrics_enabled
  })]

  # atomic: якщо інсталяція не піднялась за timeout — автоматичний відкат,
  # у кластері не лишається напівживий реліз
  atomic  = true
  timeout = var.helm_timeout_seconds
}