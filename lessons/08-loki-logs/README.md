# Заняття 8 — Логування з Grafana Loki

## Що здаю

| Пункт ДЗ | Відповідь / файл |
| --- | --- |
| Розгорнути Loki | helm-реліз `loki` (SingleBinary) — [`values-loki.yaml`](values-loki.yaml), вивід [`loki-install-output.txt`](loki-install-output.txt) |
| Розгорнути Promtail | helm-реліз `promtail` (DaemonSet) — [`values-promtail.yaml`](values-promtail.yaml), вивід [`promtail-install-output.txt`](promtail-install-output.txt) |
| Зібрати логи з ноди | підтвердження, що логи надходять у Loki — [`verify-output.txt`](verify-output.txt) |

Loki + Promtail піднято в кластер із заняття 3 (kind + kube-prometheus-stack),
namespace `loki`. Promtail як DaemonSet читає логи всіх подів з файлової системи
ноди `rd-course-control-plane` і шле їх у Loki. Grafana (`kps-grafana` із
заняття 3) підключається до Loki як data source для перегляду логів через LogQL.

---

## Loki: SingleBinary замість Distributed

Матеріали організаторів розгортають Loki на Azure AKS у режимі `Distributed`
(окремі поди для distributor/ingester/querier/…) зі сховищем Azure Blob через
workload identity. Для локального kind це надлишково, тому конфіг адаптовано:

| Параметр | Організатори (AKS) | Тут (kind) |
| --- | --- | --- |
| `deploymentMode` | `Distributed` | `SingleBinary` (усі ролі в одному поді) |
| Сховище | Azure Blob (`use_federated_token`) | `filesystem` (PVC через local-path) |
| Кеші (chunks/results) | увімкнені | вимкнені (за замовчуванням просять ~9Gi RAM) |
| `auth_enabled` | multi-tenant | `false` (не треба `X-Scope-OrgID`) |
| Canary / minio | увімкнені | вимкнені |

## Як працює збір логів

1. **Promtail** (DaemonSet) — по одному поду на кожній ноді, монтує
   `/var/log/pods` ноди й читає stdout/stderr усіх контейнерів.
2. Набір міток (`namespace`, `pod`, `container`, `node_name`…) формує **stream**;
   рядки логів пакуються в **chunks**.
3. Promtail пушить у Loki через gateway:
   `http://loki-gateway.loki.svc.cluster.local/loki/api/v1/push`.
4. **Loki** індексує лише мітки, chunks зберігає на диску (`filesystem`).
5. **Grafana** читає з Loki за LogQL (напр. `{namespace="default"}`).

## Як відтворити

```bash
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update grafana

kubectl create namespace loki

# Loki (SingleBinary + filesystem)
helm install loki grafana/loki --version 6.55.0 -n loki -f values-loki.yaml

# Promtail (DaemonSet)
helm install promtail grafana/promtail --version 6.17.1 -n loki -f values-promtail.yaml
```

Перевірка, що логи з ноди надходять у Loki:

```bash
kubectl port-forward -n loki svc/loki-gateway 3100:80 &

# доступні мітки (мають бути namespace, pod, node_name…)
curl -s http://127.0.0.1:3100/loki/api/v1/labels | jq -r '.data'

# приклад лог-рядків
curl -s -G http://127.0.0.1:3100/loki/api/v1/query_range \
  --data-urlencode 'query={namespace="default"}' \
  --data-urlencode 'limit=5' | jq -r '.data.result[].values[][1]'
```
