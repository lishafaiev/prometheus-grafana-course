# Заняття 1 — Вступ до моніторингу та основні концепції

## Що здаю

| Пункт ДЗ | Відповідь / файл |
| --- | --- |
| Команди встановлення | [`install.sh`](install.sh) |
| Конфіг Prometheus | [`prometheus.yml`](prometheus.yml) |
| Метрики CPU | `node_cpu_seconds_total` + запити → [нижче](#метрики-використання-cpu) |
| Інтервал збору метрик | **`scrape_interval: 15s`** |
| Кількість targets | **2** (`prometheus` + `node`) |
| Скріншоти роботи | [`screenshots/`](screenshots/) |

Середовище встановлення: **WSL2 (Ubuntu) на Windows** — метрики описують
Linux-середовище WSL.

---

## Деталі

### Метрики використання CPU

Базова метрика — **`node_cpu_seconds_total`** (counter): сумарний час у секундах
кожного ядра (`cpu`) у кожному режимі (`mode`: `idle`, `user`, `system`,
`iowait`, `irq`, `softirq`, `steal`, `nice`) з моменту завантаження ОС.

```promql
# Загальне завантаження CPU у % (усереднено по ядрах)
100 * (1 - avg(rate(node_cpu_seconds_total{mode="idle"}[5m])))

# Розподіл по режимах — де саме витрачається час CPU
avg by (mode) (rate(node_cpu_seconds_total[5m]))
```

Логіка: сума всіх режимів на одне ядро ≈ 1 секунда/секунду, тож
завантаження = `1 − idle`. Для counter'а швидкість зростання дає `rate(metric[вікно])`.

### Аналіз prometheus.yml

- **`scrape_interval: 15s`** (блок `global`) — частота збору метрик. Діє на всі
  job-и, якщо для них не задано власне значення.
- **2 job-и** у `scrape_configs`: `prometheus` (моніторить сам себе) та `node`
  (Node Exporter). `job_name` потрапляє в метрики як лейбл `job` для фільтрації.
- **2 targets**: `localhost:9090` (Prometheus) та `localhost:9100` (Node Exporter).
  Обидва підтверджені як `UP` на сторінці Status → Targets.

---

## Конспект (основні концепції)

- **Метрика** — числовий показник стану системи з ім'ям і **лейблами**
  (`cpu="0"`, `mode="idle"`).
- **Time series** — послідовність пар «значення + час» для однієї комбінації
  імені та лейблів; так Prometheus зберігає дані.
- **Exporter** — агент, що віддає метрики підсистеми на `/metrics` (нічого не
  зберігає). Node Exporter — для Linux-хоста.
- **Target** — джерело метрик, до якого ходить Prometheus.
- **Scrape** — Prometheus сам по таймеру забирає метрики з targets (pull-модель).
- **Job** — група однотипних targets зі спільним `job_name`.
- **Counter / gauge** — лічильник, що тільки зростає / величина, що ходить
  вгору-вниз.
- **PromQL** — мова запитів; для counter'ів зазвичай `rate(metric[вікно])`.

Архітектура: `ОС → exporter (/metrics) → Prometheus scrape → time series → PromQL`.
