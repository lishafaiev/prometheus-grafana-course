# Заняття 9 — Трасування з Grafana Tempo

## Що здаю

| Пункт ДЗ | Відповідь / файл |
| --- | --- |
| Розгорнути Tempo | helm-реліз `tempo` (SingleBinary) — [`tempo-values.yaml`](tempo-values.yaml), вивід [`install-output.txt`](install-output.txt) |
| Розгорнути Alloy | helm-реліз `alloy` (OTLP-збирач) — [`alloy-values-trace-only.yaml`](alloy-values-trace-only.yaml), вивід [`install-output.txt`](install-output.txt) |
| Надіслати трейс до Tempo | скрипт [`send_trace.sh`](send_trace.sh) → трейс прочитано назад з Tempo API ([`install-output.txt`](install-output.txt)) |
| Перегляд у Grafana | Tempo як data source — [`grafana-tempo-datasource.yaml`](grafana-tempo-datasource.yaml), скріншоти [`screenshots/`](screenshots/) |

Tempo + Alloy піднято в кластер із заняття 3 (kind + kube-prometheus-stack).
Потік трейсів: `curl → Alloy (OTLP :4318) → Tempo (:4317)`. Grafana (`kps-grafana`
із заняття 3) підключається до Tempo як data source для перегляду трейсів.

---

## Трасування, Trace і Span

Трасування (distributed tracing) відстежує шлях **одного запиту** крізь усі
сервіси. Ключ — **Trace ID**, що передається між сервісами (W3C Trace Context,
заголовок `traceparent`) і зшиває спани в один трейс.

- **Trace** — повна історія запиту, дерево зі спанів.
- **Span** — атомарна операція (HTTP-виклик, SQL). Має Span ID, Parent Span ID
  (будує ієрархію), таймінги й атрибути (`http.method`, `service.name`…).

Три сигнали: метрики (скільки/як швидко), логи (що сталося), трейси (де в
ланцюжку час і помилки).

## Компоненти

| Компонент | Роль |
| --- | --- |
| **Tempo** (SingleBinary) | сховище трейсів; не індексує вміст, ключ пошуку — traceID; backend `local` (filesystem) |
| **Alloy** | OTLP-збирач: приймає трейси (:4317/:4318), експортує в Tempo |
| **Grafana** | перегляд трейсів (Explore → Tempo, Search / TraceQL) |

## Tempo: SingleBinary + local storage

Приклад із матеріалів курсу розгортає Tempo на Azure AKS у режимі
`tempo-distributed` (окремі поди distributor/ingester/compactor/querier) зі
сховищем Azure Blob. Для локального kind це надлишково, тому взято:

| Параметр | Матеріали курсу (AKS) | Тут (kind) |
| --- | --- | --- |
| Чарт | `tempo-distributed` | `tempo` (SingleBinary, усі ролі в одному поді) |
| Сховище | Azure Blob (ключ акаунта) | `local` (filesystem у поді) |
| Приймачі | OTLP + Jaeger + Zipkin | лише OTLP (:4317 gRPC, :4318 HTTP) |

## Alloy як OTLP-збирач

Конфіг Alloy (river) — граф з двох компонентів:

1. `otelcol.receiver.otlp` — приймає OTLP на `:4317`/`:4318`, спрямовує `traces`
   на вхід експортера.
2. `otelcol.exporter.otlp` — шле трейси в `tempo.tempo.svc.cluster.local:4317`
   з `tls { insecure = true }` (Tempo слухає без TLS усередині кластера).

`extraPorts` у values відкриває `4317/4318` на Kubernetes Service Alloy — без
цього приймач слухає лише всередині контейнера й недосяжний ззовні пода.

## Як відтворити

```bash
helm repo add grafana-community https://grafana-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Tempo (SingleBinary + local storage)
helm install tempo grafana-community/tempo \
  --namespace tempo --create-namespace -f tempo-values.yaml

# Alloy (OTLP-збирач → Tempo)
helm install alloy grafana/alloy \
  --namespace alloy --create-namespace -f alloy-values-trace-only.yaml

# Tempo як data source у Grafana (sidecar підхопить ConfigMap)
kubectl apply -f grafana-tempo-datasource.yaml
```

Надсилання тестового трейсу й перевірка:

```bash
# тунель до Alloy (OTLP HTTP)
kubectl -n alloy port-forward svc/alloy 4318:4318 &

# надіслати трейс (свіжі таймінги + випадкові trace/span ID)
bash send_trace.sh

# тунель до Tempo API і читання трейсу за ID
kubectl -n tempo port-forward svc/tempo 3200:3200 &
curl -s "http://localhost:3200/api/traces/<trace_id>"
```

У Grafana: **Explore → Tempo → Search → Service Name `demo-service`** показує
трейс `demo-span` (див. [`screenshots/`](screenshots/)).
