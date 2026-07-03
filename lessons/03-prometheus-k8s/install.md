# Інструкція: розгортання Prometheus у Kubernetes (kind + Helm)

Покрокова, відтворювана інструкція до ДЗ №3. Усі команди виконуються у WSL2
(Ubuntu), де вже працює Docker. Версії інструментів — актуальні на момент
виконання; їх необхідно звіряти наживо, а не брати з пам'яті.

## 0. Передумови

- WSL2 + Docker (демон працює): перевіряється командою `docker info`.
- Архітектура: `uname -m` → `x86_64` (= amd64).

## 1. Встановлення інструментів (kind, kubectl, helm)

Усі три — окремі бінарники. Послідовність для кожного: завантаження →
`chmod +x` → переміщення в `/usr/local/bin`.

```bash
# kind (Kubernetes IN Docker)
curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.32.0/kind-linux-amd64
chmod +x ./kind
sudo mv ./kind /usr/local/bin/kind

# kubectl
curl -LO https://dl.k8s.io/release/v1.36.2/bin/linux/amd64/kubectl
chmod +x kubectl
sudo mv kubectl /usr/local/bin/kubectl

# helm
curl -LO https://get.helm.sh/helm-v4.2.2-linux-amd64.tar.gz
tar -zxvf helm-v4.2.2-linux-amd64.tar.gz
sudo mv linux-amd64/helm /usr/local/bin/helm
rm -rf helm-v4.2.2-linux-amd64.tar.gz linux-amd64
```

Свіжі версії визначаються так:

- kind: остання на github.com/kubernetes-sigs/kind/releases
- kubectl: `curl -L https://dl.k8s.io/release/stable.txt`
- helm: github.com/helm/helm/releases

Перевірка встановлення:

```bash
kind version && kubectl version --client && helm version
```

## 2. Підняття кластера

```bash
kind create cluster --name rd-course
```

kind запускає Docker-контейнер із Kubernetes усередині й автоматично додає та
активує kubectl-контекст `kind-rd-course`.

Перевірка:

```bash
kubectl get nodes              # нода Ready
kubectl get --raw /healthz     # має повернути "ok"
```

## 3. Додавання Helm-репозиторію

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

## 4. Розгортання стека kube-prometheus-stack

Конфіг розташований у сусідньому `values.yaml` (головний артефакт ДЗ).

```bash
helm install kps prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f values.yaml
```

`kps` — імʼя релізу (ресурси отримують префікс `kps-`). Стек привозить:
Prometheus + Operator + node-exporter + kube-state-metrics + Grafana + Alertmanager.

Очікування готовності:

```bash
kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=240s
kubectl get pods -n monitoring
```

## 5. Перевірка таргетів

```bash
# тимчасовий тунель + запит до API (jq у WSL немає — парситься grep/python3)
kubectl port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 -n monitoring >/dev/null 2>&1 &
PF=$!; sleep 4
curl -s http://localhost:9090/api/v1/targets | grep -o '"health":"[a-z]*"' | sort | uniq -c
kill $PF
```

Очікувано: більшість UP. 4 DOWN (kube-controller-manager, kube-etcd,
kube-proxy, kube-scheduler) — відоме обмеження kind (слухають 127.0.0.1
усередині ноди → `connection refused`). До «експортерів» з ДЗ не належать.

## 6. Доступ до UI (браузер)

Кожен port-forward — блокуючий, його слід тримати у окремій вкладці WSL.

```bash
kubectl port-forward svc/kps-kube-prometheus-stack-prometheus 9090:9090 -n monitoring
# → http://localhost:9090/targets

kubectl port-forward svc/kps-grafana 3000:80 -n monitoring
# → http://localhost:3000   (логін admin / пароль admin)
```

Grafana слухає порт 80 усередині, тому використовується мапінг `3000:80`.

## 7. Відновлення після перезавантаження/сну хоста

kind ефемерний. Після ребута WSL-годинник може стрибнути й зламати кластер
(apiserver флапає, `Forbidden`, у /healthz падають `bootstrap-roles`/
`priority-classes`). Послідовність відновлення:

```bash
# з Windows PowerShell:
wsl --shutdown
# після повторного входу у WSL docker підніметься сам (systemd).
# Кластер потребує перестворення:
kind delete cluster --name rd-course
kind create cluster --name rd-course
# далі необхідно повторити кроки 4–6. values.yaml не змінюється.
```

## 8. Прибирання

```bash
kind delete cluster --name rd-course
```
