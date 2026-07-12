# Заняття 6 — Моніторинг сторонніх сервісів

## Що здаю

| Пункт ДЗ | Відповідь / файл |
| --- | --- |
| Blackbox Exporter для перевірки сайту robot_dreams | `Probe` на `https://robotdreams.cc` — [`probe-robotdreams.yaml`](probe-robotdreams.yaml) |
| Підтвердження роботи | таргет [UP](screenshots/blackbox-target-up.png), графіки [`probe_success`](screenshots/probe-success.png) = 1 і [`probe_duration_seconds`](screenshots/probe-duration-seconds.png) |

ДЗ опційне. Blackbox Exporter піднято helm-чартом у кластер із заняття 3
(kind + kube-prometheus-stack, namespace `monitoring`), ціль описано
кастомним ресурсом **`Probe`** (CRD від Prometheus Operator). Оператор
підхоплює пробу за міткою **`release: kps`** — саме її очікує `probeSelector`
цього Prometheus
(`kubectl -n monitoring get prometheus -o jsonpath='{.items[0].spec.probeSelector}'`).

---

## Як працює Blackbox

Blackbox — це сервіс-посередник; Prometheus **не** скрейпить сайт напряму:

1. Prometheus скрейпить сам blackbox: `/probe?target=https://robotdreams.cc&module=http_2xx`.
2. Blackbox виконує HTTP-пробу цілі й повертає метрики `probe_*`.
3. Реальний URL цілі переїжджає в лейбл `instance`.

Підміну адреси скрейпу (target → blackbox-сервіс через relabel) генерує
оператор із ресурсу `Probe` — руками relabel-конфіг писати не треба.

## Ресурс Probe

```yaml
apiVersion: monitoring.coreos.com/v1
kind: Probe
metadata:
  name: blackbox-robotdreams
  namespace: monitoring
  labels:
    release: kps          # probeSelector kps-Prometheus
spec:
  jobName: blackbox-robotdreams
  interval: 30s
  module: http_2xx        # HTTP-проба, успіх = 2xx
  prober:
    url: blackbox-prometheus-blackbox-exporter:9115   # Service blackbox-експортера
  targets:
    staticConfig:
      static:
        - https://robotdreams.cc
```

- `module: http_2xx` — базовий модуль чарту (для ICMP/DNS довелося б вмикати
  окремі модулі у values blackbox-експортера).
- `prober.url` — куди Prometheus ходить по `/probe`.
- Нюанс: pod-пробер має мати мережевий доступ до публічної цілі з кластера.

## Корисні метрики проби

| Метрика | Що показує |
| --- | --- |
| `probe_success` | 1 = ціль доступна, 0 = ні (основа для алерту) |
| `probe_http_status_code` | код відповіді (200) |
| `probe_duration_seconds` | повний час проби |
| `probe_http_duration_seconds{phase=…}` | розклад по фазах (DNS / TCP / TLS) |
| `probe_ssl_earliest_cert_expiry` | коли протухає TLS-сертифікат |

---

## Як відтворити

1. Підняти стек із заняття 3 (kind + kube-prometheus-stack, namespace `monitoring`).
2. Поставити Blackbox Exporter:

   ```bash
   helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
   helm -n monitoring upgrade --install blackbox \
     prometheus-community/prometheus-blackbox-exporter
   ```

3. Застосувати пробу:

   ```bash
   kubectl apply -f probe-robotdreams.yaml
   ```

4. Перевірити, що ціль підхопилась і сайт доступний:

   ```bash
   curl -s 'http://localhost:9090/api/v1/query?query=probe_success{job="blackbox-robotdreams"}' \
     | jq '.data.result'
   # очікуємо value [..., "1"], instance="https://robotdreams.cc"
   ```

   Ручна проба напряму (без Prometheus) — для дебагу зі `&debug=true`:

   ```bash
   kubectl -n monitoring run bb-test --rm -i --restart=Never --image=curlimages/curl -- \
     -s 'http://blackbox-prometheus-blackbox-exporter:9115/probe?target=https://robotdreams.cc&module=http_2xx'
   ```
