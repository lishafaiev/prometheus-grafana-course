#!/usr/bin/env bash
# Команди встановлення Prometheus та Node Exporter.
# Середовище: WSL2 (Ubuntu) на Windows. Усі команди нижче виконуються
# всередині Ubuntu (термінал `wsl` або застосунок Ubuntu), а не в PowerShell.

# =====================================================================
# Етап 1. WSL2 + Ubuntu  (виконується в PowerShell, не в bash)
# =====================================================================
# wsl --status        # перевірка, що WSL2 — версія за замовчуванням
# wsl -l -v           # список дистрибутивів та їх версія (має бути VERSION 2)
# wsl                 # вхід в Ubuntu
# Якщо WSL відсутній:  wsl --install -d Ubuntu  (потім перезавантаження)

# =====================================================================
# Етап 2. Node Exporter  (всередині Ubuntu)
# =====================================================================
# Node Exporter — агент, що віддає метрики хоста (CPU/RAM/диск/мережа)
# на HTTP-ендпоінті :9100/metrics. Використовується офіційний бінарник з GitHub.

NODE_VER="1.11.1"                     # актуальну версію слід звірити: https://github.com/prometheus/node_exporter/releases

cd /tmp
# 1) завантажити архів під linux-amd64
wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_VER}/node_exporter-${NODE_VER}.linux-amd64.tar.gz

# 2) розпакувати
tar xzf node_exporter-${NODE_VER}.linux-amd64.tar.gz

# 3) (опційно) покласти бінарник у PATH, щоб запускати з будь-якої теки
sudo cp node_exporter-${NODE_VER}.linux-amd64/node_exporter /usr/local/bin/

# 4) запустити (займає поточний термінал; для запуску у фоні додається "&")
node_exporter
#    → у логах має з'явитися "Listening on [::]:9100"

# 5) перевірка в іншому терміналі Ubuntu: метрики мають віддаватися
# curl -s http://localhost:9100/metrics | head

# =====================================================================
# Етап 3. Prometheus  (всередині Ubuntu)
# =====================================================================
# Prometheus — сервер, що по таймеру сам ходить до targets (scrape),
# забирає метрики й складає в time-series базу. Слухає :9090.

PROM_VER="3.12.0"                     # Latest (feature). LTS-гілка — 3.5.x. https://github.com/prometheus/prometheus/releases

cd /tmp
# 1) завантажити та розпакувати
wget https://github.com/prometheus/prometheus/releases/download/v${PROM_VER}/prometheus-${PROM_VER}.linux-amd64.tar.gz
tar xzf prometheus-${PROM_VER}.linux-amd64.tar.gz
cd prometheus-${PROM_VER}.linux-amd64

# 2) налаштувати prometheus.yml: два targets — сам Prometheus і Node Exporter.
#    (редагується штатний конфіг, який лежить поряд із бінарником)
cat > prometheus.yml <<'EOF'
global:
  scrape_interval: 15s          # як часто Prometheus забирає метрики

scrape_configs:
  - job_name: "prometheus"      # target 1: сам Prometheus моніторить себе
    static_configs:
      - targets: ["localhost:9090"]

  - job_name: "node"            # target 2: Node Exporter (метрики ОС)
    static_configs:
      - targets: ["localhost:9100"]
EOF

# 3) запустити (займає ще один термінал; node_exporter має лишатися запущеним)
./prometheus --config.file=prometheus.yml
#    → у логах: "Server is ready to receive web and API requests."

# =====================================================================
# Етап 4. Запуск / перевірка
# =====================================================================
# Веб-інтерфейс Prometheus:  http://localhost:9090
#   • Status → Targets        — обидва target-и мають бути "UP"
#   • вкладка Graph, запит:    rate(node_cpu_seconds_total{mode="system"}[5m])
#
# Перевірка з терміналу, що target-и живі:
# curl -s http://localhost:9090/api/v1/targets | head
