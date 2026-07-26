# Заняття 11 — Воркшоп. Моніторинг MLOps за допомогою Prometheus та Q&A

Дата: 21 липня, 19:00

## Конспект

Воркшоп: ML-модель у Kubernetes — це звичайний сервіс, і моніториться вона
тим самим стеком, що й решта навантажень.

- **Seldon Core** — оператор, що перетворює навчену модель на REST/gRPC-сервіс:
  `SeldonDeployment` з `implementation: SKLEARN_SERVER` і `modelUri` на артефакт
  моделі у сховищі (gs://…). Метрики Seldon віддає на шляху `/prometheus`
  (не `/metrics`), тому в `ServiceMonitor` вказується саме цей `path`.
- **OpenTelemetry Collector** (через OpenTelemetry Operator, CR
  `OpenTelemetryCollector`) — універсальний вузол збору телеметрії:
  receivers → processors → exporters, зібрані в pipelines по сигналах.
  Простий варіант: OTLP-receiver (gRPC :4317, HTTP :4318) → `memory_limiter`
  → `debug`.
- Розгорнутий варіант (`mode: daemonset`) замінює окремі агенти: `filelog`
  читає логи контейнерів з `/var/log/pods` (роль Promtail), `k8sattributes`
  збагачує дані метаданими подів, `filter` відкидає DEBUG-логи ще на агенті,
  `count`/`transform` генерують метрики з логів; виходи — Loki (логи),
  Tempo (трейси), Prometheus-екзпортер `:8889` (метрики).
- **Prometheus як OTLP-приймач** — feature flag `otlp-write-receiver`
  у kube-prometheus-stack: застосунки можуть push-ити метрики по OTLP прямо
  в Prometheus; `promoteResourceAttributes` визначає, які OTel-атрибути
  стають лейблами.
- **OpenTelemetry Demo** (astronomy shop) — helm-чарт з ~20 інструментованих
  мікросервісів і повним observability-стеком з коробки; полігон для
  експериментів з телеметрією.

## Домашнє завдання — курсовий проєкт

Дата захисту: 23 липня, 19:00

### Завдання

Обрати один із чотирьох варіантів проєкту та побудувати архітектурну діаграму
системи моніторингу, позначивши на ній:

- джерела даних (де виникають метрики/логи/трейси);
- системи збору (експортери, агенти, проксі);
- системи зберігання/обробки (Prometheus, Loki, Tempo, …);
- візуалізацію та алерти (Grafana, Alertmanager).

Здача — діаграма у форматі PDF; на захисті — продемонструвати роботу та
пояснити, чому діаграма побудована саме так.

### Обраний варіант

**Варіант 1 — моніторинг Kubernetes-кластера з мікросервісами.**

Легенда: кластер (1 control-plane + 2 worker), на нодах працюють мікросервіси
e-commerce (frontend, backend API, database). Бізнес хоче відстежувати
продуктивність додатків і стан самого кластера.

Вибір зумовлений тим, що цей варіант повністю лягає на практику курсу:
kind + kube-prometheus-stack (заняття 3), дашборди Grafana (заняття 4),
алерти через PrometheusRule (заняття 5), Blackbox exporter + Probe
(заняття 6), Loki + Promtail (заняття 8), Tempo + Alloy (заняття 9).
Кожен блок діаграми підкріплений реальним досвідом розгортання.

Діаграма покриває всі три сигнали спостережуваності: метрики, логи і трейси.

### Діаграма

Джерело: [architecture.mmd](architecture.mmd) · PDF: [architecture.pdf](architecture.pdf)

```mermaid
---
title: "Моніторинг Kubernetes-кластера з мікросервісами"
config:
  layout: elk
  theme: default
---
flowchart LR
  %% ── Шар 1. Джерела даних ─────────────────────────────
  subgraph SRC["1. Джерела даних"]
    subgraph APPS["Мікросервіси (e-commerce)"]
      FE["frontend<br/>(/metrics + OTel SDK)"]
      BE["backend API<br/>(/metrics + OTel SDK)"]
      DB[("database<br/>(без /metrics)")]
    end
    K8SAPI["Kubernetes API server<br/>(стан обʼєктів)"]
    KUBELET["kubelet + cAdvisor<br/>(ресурси контейнерів)"]
    subgraph NODES["Ноди: 1 control-plane + 2 worker"]
      OS["ОС нод<br/>(/proc, /sys)"]
      CLOGS["Логи контейнерів<br/>(stdout → /var/log/pods)"]
    end
  end

  %% ── Шар 2. Системи збору ─────────────────────────────
  subgraph COLLECT["2. Системи збору"]
    BB["Blackbox exporter"]
    ALLOY["Alloy<br/>(OTLP-збирач)"]
    DBEXP["postgres-exporter"]
    KSM["kube-state-metrics"]
    NE["node-exporter<br/>(DaemonSet)"]
    PT["Promtail<br/>(DaemonSet)"]
  end

  %% ── Шар 3. Зберігання / обробка ──────────────────────
  subgraph STORE["3. Зберігання / обробка"]
    PROM["Prometheus<br/>(kube-prometheus-stack:<br/>ServiceMonitor / PrometheusRule)"]
    LOKI["Loki"]
    TEMPO["Tempo"]
  end

  %% ── Шар 4. Візуалізація та алерти ────────────────────
  subgraph VIS["4. Візуалізація та алерти"]
    AM["Alertmanager"]
    NOTIF["Slack / Email"]
    GRAF["Grafana<br/>(datasources: Prometheus,<br/>Loki, Tempo)"]
  end

  %% Джерела → збір (порядок = порядок вузлів у колонках)
  FE -.->|"HTTP-проба (ініціює BB)"| BB
  DB -->|"SQL-запити"| DBEXP
  K8SAPI -->|"watch"| KSM
  OS -->|"читання /proc, /sys"| NE
  CLOGS -->|"tail файлів логів"| PT

  %% Збір → зберігання (метрики: pull, ініціює Prometheus)
  BB -->|"pull /probe"| PROM
  DBEXP -->|"pull"| PROM
  KSM -->|"pull"| PROM
  NE -->|"pull"| PROM
  FE -->|"pull"| PROM
  BE -->|"pull"| PROM
  KUBELET -->|"pull"| PROM

  %% Логи: push, ініціює Promtail
  PT -->|"push"| LOKI

  %% Трейси: push OTLP, ініціюють застосунки (OTel SDK)
  FE -->|"push OTLP (спани)"| ALLOY
  BE -->|"push OTLP (спани)"| ALLOY
  ALLOY -->|"push OTLP"| TEMPO

  %% Зберігання → візуалізація та алерти
  PROM -->|"алерти (push)"| AM
  AM -->|"нотифікації"| NOTIF
  PROM -->|"PromQL"| GRAF
  LOKI -->|"LogQL"| GRAF
  TEMPO -->|"TraceQL"| GRAF
```

### Пояснення по шарах

#### 1. Джерела даних

Місця, де телеметрія виникає; жодних інструментів моніторингу тут ще немає.

- **ОС нод** — CPU, памʼять, диск, мережа на рівні операційної системи.
- **Kubernetes API server** — стан обʼєктів кластера (Deployment, Pod, PVC…).
- **kubelet + cAdvisor** — споживання ресурсів контейнерами; особливий випадок:
  джерело, яке одразу віддає метрики у форматі Prometheus, тому окремий
  збирач йому не потрібен.
- **Мікросервіси** — frontend і backend API інструментовані двічі: віддають
  метрики через власний `/metrics` і надсилають трейси через OTel SDK;
  database не інструментована — їй потрібен експортер.
- **Логи контейнерів** — stdout/stderr подів, які kubelet складає у файли
  в `/var/log/pods` на кожній ноді.

#### 2. Системи збору

Перетворюють «сирі» сигнали джерел на метрики/логи/трейси для зберігання.

- **node-exporter** (DaemonSet) — читає `/proc` і `/sys` хоста в момент
  скрейпу, віддає метрики ОС.
- **kube-state-metrics** — через watch API server перетворює стан обʼєктів
  Kubernetes на метрики. Різниця з cAdvisor: cAdvisor показує, *скільки
  ресурсів фактично споживає* контейнер, kube-state-metrics — *що про обʼєкт
  думає Kubernetes* (кількість реплік, фази подів тощо).
- **postgres-exporter** — ходить у БД SQL-запитами і публікує результати
  як метрики (сама БД формат Prometheus не віддає).
- **Blackbox exporter** — перевіряє доступність frontend «ззовні» HTTP-пробою;
  Prometheus забирає результат через `/probe`.
- **Promtail** (DaemonSet) — безперервно «тейлить» файли логів з ноди
  (як `tail -f`, із запамʼятовуванням позиції) і відправляє рядки в Loki.
- **Alloy** — OTLP-збирач трейсів: приймає спани від застосунків
  (:4317 gRPC / :4318 HTTP) і пересилає їх у Tempo. Проміжний шар дає змогу
  батчити, фільтрувати і збагачувати телеметрію, не чіпаючи застосунки.

#### 3. Зберігання / обробка

- **Prometheus** (розгорнутий через kube-prometheus-stack) — сам скрейпить усі
  цілі за ServiceMonitor, зберігає метрики в TSDB, обчислює правила алертів
  (PrometheusRule).
- **Loki** — приймає та індексує логи від Promtail.
- **Tempo** — сховище трейсів; вміст не індексує, пошук за trace ID
  (або через TraceQL у Grafana).

#### 4. Візуалізація та алерти

- **Grafana** — єдиний інтерфейс до всіх трьох сигналів: метрики (datasource
  Prometheus, PromQL), логи (Loki, LogQL), трейси (Tempo, TraceQL);
  з логу можна перейти на повʼязаний трейс за trace ID.
- **Alertmanager** — отримує спрацьовані алерти від Prometheus, групує,
  дедуплікує і надсилає нотифікації у Slack / Email.

### Потоки даних: pull, push, локальне читання

Підписи на стрілках показують, хто ініціює обмін:

- **pull** — Prometheus сам ініціює HTTP-запит до цілі за розкладом
  (scrape). Так збираються всі метрики: експортери, kubelet/cAdvisor,
  `/metrics` застосунків.
- **push** — відправник сам штовхає дані: Promtail → Loki (логи),
  застосунки → Alloy → Tempo (трейси, протокол OTLP),
  Prometheus → Alertmanager (алерти).
- **локальне читання** — не мережева взаємодія: node-exporter читає
  `/proc` і `/sys`, Promtail тейлить файли логів у межах своєї ноди.

Метрики йдуть pull-ом, бо це знімок стану, який Prometheus знімає за власним
розкладом; логи і трейси — подієві, «прийти і поскрейпити» їх не можна, тому
вони йдуть push-ем від відправника.

Окремий випадок — **Blackbox exporter**: він сам ініціює HTTP-пробу до
frontend (на діаграмі пунктир), а результат віддає Prometheus через
звичайний pull `/probe`.

### Що здаю

| Файл | Опис |
| --- | --- |
| [architecture.mmd](architecture.mmd) | Джерело діаграми (Mermaid, рендериться вище) |
| [architecture.pdf](architecture.pdf) | Діаграма для здачі в LMS |
| [screenshots/architecture.png](screenshots/architecture.png) | Діаграма у PNG |
