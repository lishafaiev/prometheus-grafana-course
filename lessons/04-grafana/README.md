# Заняття 4 — Візуалізація з Grafana

## Що здаю

| Пункт ДЗ | Відповідь / файл |
| --- | --- |
| Власний дашборд із 5 панелями | [`dashboards/node-and-pods.json`](../../dashboards/node-and-pods.json) |
| Variables у панелях | дві змінні: `$instance`, `$namespace` |
| Скріншот дашборда | [`screenshots/node-and-pods.png`](screenshots/node-and-pods.png) |

Дашборд **`Node & Pods`** зібрано у Grafana зі стека
**kube-prometheus-stack** (розгорнутого на занятті 3, kind, namespace
`monitoring`). Доступ до UI — через `kubectl port-forward` до сервісу
`kube-prometheus-stack-grafana`. Data source **Prometheus** підключений
автоматично (provisioning через ConfigMap), окремо не налаштовувався.

---

## Variables

Variable — випадаючий список угорі дашборда, значення якого підставляється
в запити всіх панелей. Дозволяє одним дашбордом дивитися будь-яку ноду /
namespace замість того, щоб робити окремий дашборд на кожен.

Обидві змінні — типу **Query** (значення тягнуться з Prometheus):

| Змінна | Джерело | Значення |
| --- | --- | --- |
| `$instance` | `label_values(node_uname_info, instance)` | ноди (тут одна: `172.18.0.2:9100`) |
| `$namespace` | `label_values(kube_pod_info, namespace)` | `default`, `kube-system`, `monitoring` |

У панелях фільтр пишеться через `=~` (regex-match), а не `=`, бо з
увімкненим *Include All* Grafana підставляє список через `|`
(напр. `ns1|ns2`).

---

## Панелі

Три панелі по хосту (фільтр `$instance`) і дві по Kubernetes (фільтр
`$namespace`). Тип візуалізації обрано під характер даних: динаміка — Time
series, поточне значення — Gauge / Stat.

**1. CPU usage** — Time series, `Percent (0–100)`. Завантаження CPU як
`100%` мінус частка часу в `idle`, усереднена по ядрах ноди.

```promql
100 - avg by(instance)(rate(node_cpu_seconds_total{mode="idle",instance=~"$instance"}[5m])) * 100
```

**2. RAM usage** — Gauge, `Percent (0–100)`. Частка зайнятої памʼяті =
`1 − available / total`.

```promql
(1 - node_memory_MemAvailable_bytes{instance=~"$instance"} / node_memory_MemTotal_bytes{instance=~"$instance"}) * 100
```

**3. Disk usage** — Stat, `Percent (0–100)`. Частка зайнятого диску =
`1 − вільне / розмір`, без тимчасових ФС. `max by(instance)` згортає кілька
однакових точок монтування одного диску (`/dev/sdd` у kind) до одного
значення — інакше Stat показав би «Multiple series».

```promql
(1 - max by(instance)(node_filesystem_avail_bytes{instance=~"$instance",fstype!~"tmpfs|overlay"}) / max by(instance)(node_filesystem_size_bytes{instance=~"$instance",fstype!~"tmpfs|overlay"})) * 100
```

**4. Running pods** — Stat, `short`. Кількість подів у фазі `Running` в
обраних namespace.

```promql
sum(kube_pod_status_phase{phase="Running",namespace=~"$namespace"})
```

**5. CPU by pod** — Time series, `short`. Швидкість споживання CPU кожним
подом (сума по його контейнерах). Повертає багато рядів — тому Time series,
а не Gauge/Stat.

```promql
sum by(pod)(rate(container_cpu_usage_seconds_total{namespace=~"$namespace",container!="",pod!=""}[5m]))
```

---

## Як відтворити

1. Підняти стек із заняття 3 (kind + kube-prometheus-stack, namespace
   `monitoring`).
2. Прокинути порт Grafana:

   ```bash
   kubectl -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
   ```

3. У Grafana: **Dashboards → New → Import** → завантажити
   [`dashboards/node-and-pods.json`](../../dashboards/node-and-pods.json) →
   обрати data source **Prometheus**.
4. Угорі перемикати `$instance` / `$namespace` — панелі перебудовуються під
   обране значення.