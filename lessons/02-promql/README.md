# Заняття 2 — Основи PromQL і налаштування збору метрик

## Що здаю

| Пункт ДЗ | Відповідь / файл |
| --- | --- |
| Новий експортер | **cAdvisor** (контейнер) → [`cadvisor.sh`](cadvisor.sh) |
| Config для cAdvisor | scrape-job `cadvisor` у [`prometheus.yml`](prometheus.yml) + запуск у [`cadvisor.sh`](cadvisor.sh) |
| 5 запитів PromQL | [`queries.promql`](queries.promql) + розбір нижче |
| — агрегація | запит 1 (`sum by`) |
| — агрегація за часом | запит 2 (`max_over_time`) |
| — `histogram_quantile` | запит 3 (p95) |
| — топ-N (бонус) | запит 4 (`topk`) |
| — бінарна операція (бонус) | запит 5 (`/`, % від ліміту) |
| Скріншоти | [`screenshots/`](screenshots/) |

Середовище: **WSL2 (Ubuntu 22.04)**, Docker Engine, Prometheus 3.12,
Node Exporter, **cAdvisor v0.57.0**. Усі три target-и — `UP`
([`targets-up.png`](screenshots/targets-up.png)).

---

## Новий експортер — cAdvisor

**cAdvisor** (Container Advisor, від Google) збирає метрики використання
ресурсів **контейнерами**: CPU, RAM, мережа, диск. Читає їх із **cgroups**
ядра й віддає у форматі Prometheus на `:8080/metrics`. Сам запускається як
контейнер (див. [`cadvisor.sh`](cadvisor.sh)).

Підключення до Prometheus — третій job у `scrape_configs`:

```yaml
  - job_name: "cadvisor"        # target 3: cAdvisor (метрики контейнерів)
    static_configs:
      - targets: ["localhost:8080"]
```

- `localhost:8080` — порт, опублікований у `docker run` (`-p 8080:8080`).
- `metrics_path` не вказуємо — `/metrics` за замовчуванням.
- `scrape_interval` не вказуємо — успадковує глобальні `15s`.

Конфіг перевірено `./promtool check config prometheus.yml` → **SUCCESS**.

### Ключові метрики

| Метрика | Тип | Що означає |
| --- | --- | --- |
| `container_cpu_usage_seconds_total` | counter | сумарний CPU-час (→ `rate`) |
| `container_memory_working_set_bytes` | gauge | «робоча» памʼять (її дивиться OOM-killer) |
| `container_spec_memory_limit_bytes` | gauge | ліміт памʼяті (0 = без ліміту) |
| `container_network_receive_bytes_total` | counter | прийнято з мережі (→ `rate`) |

> Важливо: у кожної серії є лейбл `name` (імʼя контейнера). Для кореневого
> cgroup `id="/"` він порожній (`name=""`), тому в запитах «по контейнерах»
> ставимо фільтр `{name!=""}` — інакше підмішається агрегат усієї машини.

---

## Пʼять запитів PromQL

Повні запити з коментарями — у [`queries.promql`](queries.promql).

### 1. Агрегація — CPU по контейнерах

```promql
sum by (name) (rate(container_cpu_usage_seconds_total{name!=""}[5m]))
```

`rate()` від counter дає зайняті ядра; `sum by (name)` зводить кілька серій
контейнера в одне число. Результат: `cadvisor` ≈ 0.01 ядра, `web-test` ≈ 0
(idle-nginx). Скрін: [`query1-cpu-by-container.png`](screenshots/query1-cpu-by-container.png).

### 2. Агрегація за часом — пік памʼяті

```promql
max_over_time(container_memory_working_set_bytes{name!=""}[30m])
```

`*_over_time` агрегує одну серію **вздовж часу** (на відміну від `sum by` —
**між серіями**). Графік росте «полицями»: функція тримає максимум за вікно й
підіймається лише на новому піку. Скрін:
[`query2-mem-max-over-time.png`](screenshots/query2-mem-max-over-time.png).

### 3. `histogram_quantile` — p95 латентності API Prometheus

```promql
histogram_quantile(0.95, sum by (le) (rate(prometheus_http_request_duration_seconds_bucket[5m])))
```

Гістограма зберігає розподіл у бакетах (buckets) `_bucket{le=...}`. Беремо `rate`
по бакетах, агрегуємо `sum by (le)` (лейбл `le` зберігаємо — на ньому тримається
гістограма), `0.95` дає значення, нижче якого 95% запитів. cAdvisor гістограм
не має, тому джерело — self-метрика Prometheus. Лінія ≈ 0 з рідкісними піками
на повільних запитах. Скрін:
[`query3-histogram-quantile-p95.png`](screenshots/query3-histogram-quantile-p95.png).

### 4. `topk` — топ контейнерів за мережею

```promql
topk(3, sum by (name) (rate(container_network_receive_bytes_total{name!=""}[5m])))
```

`cadvisor` приймає ~60–120 Б/с (його scrape'ить Prometheus), `web-test` ≈ 0.
Скрін: [`query4-topk-network.png`](screenshots/query4-topk-network.png).

### 5. Бінарна операція — памʼять у % від ліміту

```promql
100 * container_memory_working_set_bytes{name!=""}
  / (container_spec_memory_limit_bytes{name!=""} > 0)
```

Фільтр `> 0` відсікає контейнери без ліміту памʼяті. `web-test` запущено з
`--memory=256m`, тож запит повертає для нього **≈5.5%** (working set ~5 МБ із
256 МіБ); `cadvisor` без ліміту — і фільтр його прибирає. Скрін:
[`query5-mem-percent-limit.png`](screenshots/query5-mem-percent-limit.png).

> Цікавий нюанс: доки контейнери працювали **без** `--memory`, цей самий запит
> повертав порожньо — `container_spec_memory_limit_bytes` має сенс лише там, де
> ліміт реально заданий. Тобто метрика ліміту інформативна тільки під ліміт.

---

## Конспект PromQL

- **`rate(counter[вікно])`** — середня швидкість росту counter'а за вікно
  (напр. CPU-секунди/с, байти/с). Базовий інструмент для counter-метрик.
- **Агрегація між серіями** — `sum`/`avg`/`max ... by (лейбли)`: згортає багато
  time series в одну мить часу в менше число рядів за вказаними лейблами.
- **Агрегація за часом** — `*_over_time(метрика[вікно])` (`avg_`, `max_`, `min_`,
  `sum_`): згортає **одну** серію вздовж часового вікна.
- **Гістограма** — метрика з суфіксами `_bucket{le=...}` / `_sum` / `_count`;
  `histogram_quantile(φ, rate(_bucket[вікно]))` оцінює квантиль (p50/p95/p99).
- **`topk(N, ...)`** — N найбільших рядів; зручно для «хто найбільше споживає».
- **Бінарні операції** між векторами (`/`, `*`) працюють за збігом лейблів;
  фільтр-порівняння (`> 0`) відсікає непотрібні ряди.
