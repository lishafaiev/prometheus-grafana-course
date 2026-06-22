#!/usr/bin/env bash
# Запуск нового експортера — cAdvisor (метрики контейнерів).
# Середовище: WSL2 (Ubuntu 22.04), systemd увімкнено, cgroup v2.
# Усі команди виконуються всередині Ubuntu (термінал `wsl`), а не в PowerShell.

# =====================================================================
# Етап 1. Docker Engine  (одноразово, якщо ще не встановлено)
# =====================================================================
# Ставимо саме Docker Engine з офіційного репозиторію Docker (не docker.io
# зі стандартного Ubuntu — там пакет старіший). Повний набір кроків:
# https://docs.docker.com/engine/install/ubuntu/
#
#   sudo apt-get update
#   sudo apt-get install -y ca-certificates curl gnupg
#   sudo install -m 0755 -d /etc/apt/keyrings
#   curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
#     | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
#   sudo chmod a+r /etc/apt/keyrings/docker.gpg
#   echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
#     https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
#     | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
#   sudo apt-get update
#   sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
#     docker-buildx-plugin docker-compose-plugin
#   sudo systemctl enable --now docker     # systemd підніме демон і після перезавантаження
#   sudo usermod -aG docker $USER          # щоб не писати sudo (потім перелогін у WSL)
#
# Примітка: якщо лишився конфіг від Docker Desktop і docker лається на
# "docker-credential-desktop.exe" — обнулити ~/.docker/config.json до "{}".

# =====================================================================
# Етап 2. Тестовий контейнер  (щоб cAdvisor мав що моніторити)
# =====================================================================
# Легкий nginx у фоні; дає стабільні метрики контейнера.
# Ліміт --memory=256m потрібен, щоб працював запит 5 (% памʼяті від ліміту):
# без ліміту container_spec_memory_limit_bytes не має сенсу і запит порожній.
docker run -d --name web-test --memory=256m -p 8081:80 nginx:alpine

# =====================================================================
# Етап 3. cAdvisor  (новий експортер)
# =====================================================================
# cAdvisor читає cgroups ядра й віддає метрики контейнерів на :8080/metrics.
# На cgroup v2 обовʼязкові --privileged і --device=/dev/kmsg, інакше не стартує.
# Версію взято з офіційних releases (github.com/google/cadvisor/releases),
# образ — у GHCR (свіжі теги вже не публікують у старому gcr.io).
VERSION=v0.57.0
docker run -d \
  --name=cadvisor \
  --restart=unless-stopped \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:ro \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --volume=/dev/disk/:/dev/disk:ro \
  --publish=8080:8080 \
  --device=/dev/kmsg \
  --privileged \
  ghcr.io/google/cadvisor:${VERSION}

# =====================================================================
# Етап 4. Перевірка
# =====================================================================
# docker ps                                              # cadvisor і web-test у статусі Up
# curl -s http://localhost:8080/metrics | grep -c '^container_'   # десятки сотень метрик
# Веб-UI cAdvisor:  http://localhost:8080

# =====================================================================
# Етап 5. Підключення до Prometheus
# =====================================================================
# У prometheus.yml додано job "cadvisor" з target localhost:8080 (див. файл поруч).
# Перевірка конфігу перед застосуванням:
#   ./promtool check config prometheus.yml      # очікуємо SUCCESS
# Застосувати (Prometheus запущено з --web.enable-lifecycle):
#   curl -X POST http://localhost:9090/-/reload
# Перевірити: http://localhost:9090 → Status → Targets — job cadvisor має бути UP.
