# PromQL — шпаргалка (доповнюй по курсу)

## Типи метрик
- Counter — лише зростає (напр. node_cpu_seconds_total)
- Gauge — може рости/падати (напр. node_memory_MemAvailable_bytes)
- Histogram / Summary — розподіли

## Базове
- `up` — чи живі targets (1/0)
- `rate(metric[5m])` — швидкість зростання counter за 5 хв
- `irate(metric[5m])` — миттєва швидкість
- `sum by (instance) (...)` — агрегація з групуванням

## CPU (стане в пригоді для ДЗ-1)
- `node_cpu_seconds_total` — час CPU за режимами (mode)
- `rate(node_cpu_seconds_total{mode="idle"}[5m])` — idle
- `100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m]))*100)` — % завантаження
