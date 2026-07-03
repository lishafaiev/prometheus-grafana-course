# Заняття 3 — Розгортання Prometheus у Kubernetes

## Що здаю

| Пункт ДЗ | Відповідь / файл |
| --- | --- |
| Розгортання Prometheus через Helm | [`values.yaml`](values.yaml) + [`install.md`](install.md) |
| Кластер Kubernetes | **kind** (k8s 1.36.1), контекст `kind-rd-course` |
| Підключені експортери | node-exporter, kube-state-metrics, cAdvisor (через kubelet) |
| Власний застосунок + ServiceMonitor | [`weather-service/`](weather-service/) |
| Скріншоти | [`screenshots/`](screenshots/) |

Середовище: **WSL2 (Ubuntu)**, Docker Engine, **kind v0.32.0** (нода
Kubernetes v1.36.1), **kubectl v1.36.2**, **Helm v4.2.2**, чарт
**kube-prometheus-stack 87.2.1** (Operator v0.92.0). Реліз — `kps`,
namespace — `monitoring`.

---

## Спосіб розгортання

На лекції розглядалися три варіанти: ручне розгортання (Deployment/Service/
ConfigMap вручну), **Helm-чарт** і **Prometheus Operator** окремо. Обрано
Helm-чарт **`kube-prometheus-stack`** — найшвидший спосіб, що одним релізом
привозить увесь стек моніторингу разом із Operator, експортерами та Grafana.
Окремо `bundle.yaml` оператора не ставиться: чарт уже містить Operator, тож
подвійна інсталяція спричинила б конфлікт CRD.

Повна відтворювана послідовність наведена в [`install.md`](install.md).
Стислий вигляд:

```bash
kind create cluster --name rd-course
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace -f values.yaml
```

---

## Що розгорнулось

Чарт `kube-prometheus-stack` піднімає такі компоненти:

- **Prometheus Operator** — контролер, що керує Prometheus через CRD
  (ServiceMonitor, PodMonitor, PrometheusRule).
- **Prometheus** — збір (scrape) і зберігання метрик, мова запитів PromQL.
- **node-exporter** — системні метрики ноди (DaemonSet).
- **kube-state-metrics** — стан обʼєктів Kubernetes.
- **Grafana** — візуалізація з готовими дашбордами Kubernetes.
- **Alertmanager** — маршрутизація алертів (поки без кастомних правил).

---

## Експортери (пункт ДЗ)

Три експортери покривають різні шари — разом дають повну картину:

| Експортер | Шар | Що міряє |
| --- | --- | --- |
| **node-exporter** | хост / нода | CPU, RAM, диск, мережа вузла |
| **cAdvisor** (у kubelet) | контейнер | споживання ресурсів кожним контейнером |
| **kube-state-metrics** | обʼєкти k8s | стан подів, Deployment, реплік (не ресурси) |

node-exporter і cAdvisor міряють **реальне споживання** (на рівні ноди й
контейнера відповідно), а kube-state-metrics — **стан/статус** обʼєктів через
Kubernetes API, без CPU/RAM. cAdvisor вбудований у kubelet, тому окремого
вмикання не потребує — Operator підхоплює його автоматично
(`/metrics/cadvisor`).

---

## values.yaml — ключові налаштування

Повний конфіг — [`values.yaml`](values.yaml). Найважливіше:

- **`serviceMonitorSelectorNilUsesHelmValues: false`** (і аналогічно для
  PodMonitor) — за замовчуванням Prometheus підхоплює лише монітори, створені
  цим релізом. Прапорець вмикає режим «брати ВСІ монітори в кластері», щоб були
  видні й власні (напр. для застосунку), а не лише вбудовані.
- **`retention: 10d`** — тривалість зберігання метрик у локальному TSDB.
- **`resources.requests`** — скромні CPU/RAM під локальний kind.
- **`grafana.adminPassword: admin`** — доступ admin/admin (лише локально).

---

## Власний застосунок — weather-service

Щоб показати моніторинг **власного** застосунку (а не лише вбудованих
експортерів), у namespace `default` розгорнуто демо-сервіс **weather-service**
(ASP.NET, віддає `/metrics` через бібліотеку `prometheus-net`). Маніфести — у
[`weather-service/`](weather-service/):

- `deployment.yaml` — под із готовим образом `ozarevychgh/weather-service:latest`;
- `service.yaml` — Service (порт `http`/80);
- `servicemonitor.yaml` — CRD `ServiceMonitor`, що націлює Prometheus на цей
  Service.

```bash
kubectl apply -f weather-service/
```

Prometheus підхопив цей ServiceMonitor **автоматично** — попри те, що той
лежить у `default` і не належить релізу `kps`. Спрацювало саме завдяки
`serviceMonitorSelectorNilUsesHelmValues: false` у `values.yaml`. Таргет
`serviceMonitor/default/weather-service-servicemonitor/0` — **UP**
(`http://<pod-ip>:80/metrics`).

---

## Результат

Після розгортання всі поди в namespace `monitoring` — `Running`. Зі scrape-
таргетів **більшість UP**: node-exporter, kube-state-metrics, kubelet (включно
з `/metrics/cadvisor`), apiserver, coredns, Grafana, Alertmanager, Operator,
Prometheus.

**DOWN — 4 таргети:** `kube-controller-manager`, `kube-etcd`, `kube-proxy`,
`kube-scheduler`. Це **відоме обмеження kind**: ці компоненти control-plane
слухають `/metrics` на `127.0.0.1` усередині контейнера-ноди, тож scrape на IP
ноди дає `connection refused`. До «експортерів» з ДЗ вони не належать; на
повноцінному кластері (kubeadm/хмара) їх зазвичай налаштовують слухати
`0.0.0.0`. Рішення для навчального завдання — лишити як є.

Скріни (у [`screenshots/`](screenshots/)):

- `prometheus-targets-1.png` … `prometheus-targets-4.png` — сторінка Targets
  (UP-таргети та 4 DOWN control-plane).
- `grafana-node-exporter.png` — дашборд Grafana *Node Exporter / Nodes*.

---

## Як відтворити

Покрокова інструкція (встановлення інструментів, підняття кластера, розгортання,
доступ до UI, відновлення після ребута, прибирання) — [`install.md`](install.md).
