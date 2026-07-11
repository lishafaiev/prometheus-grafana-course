# Заняття 5 — Alertmanager і створення алертів

## Що здаю

| Пункт ДЗ | Відповідь / файл |
| --- | --- |
| Алерт CPU > 80% протягом 2 хв | `HighNodeCpuUsage` у [`prometheusrule-hw.yaml`](prometheusrule-hw.yaml) |
| Алерт USE (saturation з диска) | `HighDiskSaturation` (там само) |
| Алерт RED (кількість 5xx помилок) | `HighHttp5xxRatio` (там само) |
| Підтвердження роботи | [`screenshots/alerts-loaded-inactive.png`](screenshots/alerts-loaded-inactive.png), [`screenshots/cpu-alert-firing.png`](screenshots/cpu-alert-firing.png) |

Усі три алерти оформлені як один ресурс **`PrometheusRule`** (CRD від
Prometheus Operator) і застосовані в кластер із заняття 3 (kind +
kube-prometheus-stack, namespace `monitoring`). Оператор підхоплює правило за
міткою **`release: kps`** — саме її очікує `ruleSelector` цього Prometheus
(перевірка: `kubectl -n monitoring get prometheus -o jsonpath='{.items[0].spec.ruleSelector}'`).

Методології: CPU і диск — це **USE** (Utilization / Saturation ресурсів
інфраструктури), 5xx по веб-сервісу — це **RED** (Errors по сервісу/API).

---

## Алерти

### 1. HighNodeCpuUsage — CPU > 80% (USE / Utilization)

`node_cpu_seconds_total{mode="idle"}` — лічильник секунд простою CPU.
`rate(...)` дає частку часу в простої (0–1), усереднену по ядрах ноди;
`1 − rate(idle)` = завантаженість. Поріг `> 80`, `for: 2m` відсікає короткі
спайки.

```promql
100 * (1 - avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[2m]))) > 80
```

### 2. HighDiskSaturation — насичення диска (USE / Saturation)

`node_disk_io_time_seconds_total` — лічильник секунд, коли диск був зайнятий
I/O. `rate(...)` дає **частку часу** зайнятості (0–1). `> 0.8` = диск
завантажений понад 80% часу.

```promql
rate(node_disk_io_time_seconds_total[2m]) > 0.8
```

> Тут важливий `rate()`. Сирий лічильник (`node_disk_io_time_seconds_total > 0.8`
> без `rate`) лише зростає й майже завжди більший за 0.8 — такий «алерт» горів
> би постійно.

### 3. HighHttp5xxRatio — частка 5xx (RED / Errors)

Веб-сервіс `weather-service` (.NET, бібліотека `prometheus-net`) віддає
`http_requests_received_total` з міткою `code` (статус-код). Класичний
RED-Errors — не абсолютна кількість, а **частка** помилкових відповідей:
rate 5xx поділений на загальний rate. Поріг `> 0.05` (5%).

```promql
sum(rate(http_requests_received_total{job="weather-service", code=~"5.."}[5m]))
/
sum(rate(http_requests_received_total{job="weather-service"}[5m])) > 0.05
```

Кожен алерт має `labels` (`severity`, `type`) і `annotations` (`summary` +
`description` з підказкою на дію та поточним значенням `{{ $value }}`).

---

## Як відтворити

1. Підняти стек із заняття 3 (kind + kube-prometheus-stack, namespace
   `monitoring`); переконатися, що `weather-service` у namespace `default`
   скрейпиться.
2. Застосувати правила:

   ```bash
   kubectl apply -f prometheusrule-hw.yaml
   ```

3. Перевірити, що Prometheus підхопив правила (`health: ok`):

   ```bash
   curl -s http://localhost:9090/api/v1/rules \
     | jq '.data.groups[] | select(.name|test("hw05")) | {group:.name, rules:[.rules[]|{alert:.name, health:.health, state:.state}]}'
   ```

4. (Демонстрація firing) навантажити CPU ноди на кілька хвилин:

   ```bash
   kubectl run cpu-stress --image=polinux/stress --restart=Never -- \
     stress --cpu <кількість_ядер> --timeout 300s
   ```

   За ~1 хв `HighNodeCpuUsage` перейде в `pending`, ще за 2 хв (`for`) — у
   `firing` (див. скріншот). Після зупинки навантаження алерт сам
   резолвиться назад у `inactive`.

   ```bash
   kubectl delete pod cpu-stress
   ```
