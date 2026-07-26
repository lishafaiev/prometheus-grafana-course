# Заняття 10 — Автоматизація розгортання Prometheus

## Що здаю

| Пункт ДЗ | Відповідь / файл |
| --- | --- |
| Автоматизувати розгортання Prometheus + Grafana через Terraform | [`terraform/`](terraform/) — root-модуль + модуль [`terraform/prometheus/`](terraform/prometheus/), ставить kube-prometheus-stack 87.19.1 у kind |
| Результат виконання — Terraform-код | [`terraform/main.tf`](terraform/main.tf), [`terraform/prometheus/main.tf`](terraform/prometheus/main.tf), [`values.yaml.tpl`](terraform/prometheus/values.yaml.tpl), [`variables.tf`](terraform/prometheus/variables.tf), [`outputs.tf`](terraform/outputs.tf) |
| Підтвердження розгортання | скріншоти [`screenshots/`](screenshots/): `terraform apply` → `deployed`, поди стека, Grafana |

Ручний helm-реліз `kps` (заняття 3) знесено (`helm uninstall`) і розгорнуто
заново через `terraform apply` — з тим самим імʼям релізу і namespace, тож
напрацювання минулих занять (PrometheusRule з лейблом `release: kps`, Probe,
datasource-ConfigMap-и Loki/Tempo) підхопилися без змін.

---

## Навіщо автоматизувати

Проблеми ручного розгортання: трудомісткість, помилки конфігурації, складність
оновлень, відсутність єдиного джерела правди. Автоматизація дає
відтворюваність середовищ, версіонування інфраструктури в git, швидке
відновлення після збоїв (актуально для ефемерного kind: раніше після кожного
перестворення кластера стек накочувався руками покроково — тепер це один
`terraform apply`).

## Три інструменти з лекції

| Інструмент | Коли доречний |
| --- | --- |
| **Ansible** | Prometheus на віртуальних машинах: готові ролі для сервера й експортерів, targets задаються у ролі |
| **Terraform** | Prometheus у Kubernetes як частина коду інфраструктури (кластер + моніторинг разом) |
| **Helm-чарти сервісів** | додавання сервісів як targets: анотації до Deployment або ресурс ServiceMonitor / PodMonitor |

## Terraform не замінює Helm, а керує ним

Рівні: **чарт** (шаблони маніфестів + дефолтні values) → **Helm** (рендерить і
ставить чарт у кластер) → **Terraform** (описує бажаний стан у коді;
`terraform apply` викликає Helm через провайдер `hashicorp/helm`). Результат у
кластері ідентичний ручному `helm install`, різниця — у способі керування:

| | Руками (заняття 3) | Через Terraform |
| --- | --- | --- |
| Джерело правди | історія команд | `.tf`-файли в git |
| Відтворити з нуля | згадати всі команди | `terraform apply` |
| Змінити параметр | довгий `helm upgrade` | правка рядка → `apply` |

Terraform веде state (`terraform.tfstate`) — свій облік створених ресурсів.
Реліз, поставлений руками, для Terraform чужий (`cannot re-use a name that is
still in use`), тому ручний реліз попередньо знесено. Зворотний шлях легкий:
`terraform state rm` — і реліз знову «ручний»; асиметрія показова — почав
керувати кодом, керуй кодом (інакше drift).

## Структура коду

```text
terraform/
├── main.tf              root: провайдер helm + виклик модуля з параметрами
├── outputs.tf           ре-експорт outputs модуля (самі назовні не спливають)
├── .gitignore           state (містить sensitive), кеш .terraform/
└── prometheus/          модуль — «функція»: аргументи → helm_release
    ├── main.tf          ресурс helm_release + templatefile()
    ├── variables.tf     параметри з дефолтами
    ├── values.yaml.tpl  шаблон values (відтворює values заняття 3)
    └── outputs.tf       release_name / namespace / chart_version / status
```

Ключові рішення (відмінності від прикладу з матеріалів курсу):

- `templatefile()` замість `data "template_file"` — провайдер
  `hashicorp/template` архівний, функція вбудована;
- namespace створює `create_namespace = true` у `helm_release` (no-op, якщо
  існує) замість ресурсу `kubernetes_namespace` — namespace `monitoring` вже
  існував, окремий ресурс упав би на «already exists»; бонус — не потрібен
  другий провайдер;
- `atomic = true` — якщо стек не піднявся за timeout, Helm відкочує реліз;
- пароль Grafana — змінна з `sensitive = true`: не світиться у plan/log
  (у плані весь values-блок показано як `(sensitive value)`);
- версія чарта зафіксована змінною (87.19.1) — відтворюваність замість
  «latest»;
- `.terraform.lock.hcl` закомічено: фіксує версію і хеші провайдера.

Нюанс шаблону: для `templatefile()` увесь файл — шаблон, включно з
коментарями; конструкція «долар + фігурні дужки» у коментарі викликає помилку
парсингу (перевірено на собі).

## Як відтворити

```bash
cd terraform

terraform init    # завантажує провайдер, створює .terraform.lock.hcl
terraform plan    # суха репетиція: Plan: 1 to add, 0 to change, 0 to destroy
terraform apply   # план + підтвердження yes; atomic чекає готовності подів
```

`apply` завершується outputs: `release_status = "deployed"`,
`chart_version = "87.19.1"`.

## Перевірка

```bash
kubectl get pods -n monitoring          # весь стек Running
helm list -n monitoring                 # kps deployed, chart 87.19.1
kubectl get prometheusrules -n monitoring | grep hw05   # правила ДЗ №5 підхоплені
```

- Grafana (`http://localhost:3000`): data sources Prometheus, Alertmanager — від
  чарта; Loki, Tempo — сайдкар підхопив вцілілі ConfigMap-и занять 8–9.
- Сусідні релізи (`blackbox`, Loki, Tempo, Alloy) пересоздання не зачепило —
  межа helm-релізу.
