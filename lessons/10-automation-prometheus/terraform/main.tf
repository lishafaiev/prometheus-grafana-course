# Розгортання kube-prometheus-stack у kind-кластер через Terraform (ДЗ №10).
#
# Terraform не замінює Helm, а керує ним: terraform apply викликає Helm
# через провайдер hashicorp/helm. Параметри інсталяції зафіксовані в коді —
# єдине джерело правди замість ручних команд helm install/upgrade.

terraform {
  required_version = ">= 1.5"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

# Підключення до кластера — той самий kubeconfig, яким користується kubectl.
# config_context зафіксований явно, щоб apply ніколи не влучив у чужий кластер.
provider "helm" {
  kubernetes = {
    config_path    = "~/.kube/config"
    config_context = "kind-rd-course"
  }
}

module "kube_prometheus_stack" {
  source = "./prometheus"

  # Імʼя релізу те саме, що було при ручному встановленні (заняття 3):
  # CR-и минулих занять (PrometheusRule, Probe) мають лейбл release: kps,
  # тож новий Prometheus підхоплює їх без жодних змін.
  release_name = "kps"
  namespace    = "monitoring"

  # Параметри відтворюють values.yaml із заняття 3 (retention, ресурси).
  prometheus_retention      = "10d"
  prometheus_memory_request = "512Mi"
  prometheus_cpu_request    = "200m"

  # Лише для локального навчання; у продакшні пароль передається через
  # змінну середовища TF_VAR_grafana_admin_password або secrets-менеджер.
  grafana_admin_password = "admin"
}