# infra

Инфраструктура сайтов в Timeweb Cloud (Амстердам, `nl-1`), описанная в Terraform.

| Сайт | Репозиторий | Где работает | Деплой |
|---|---|---|---|
| rangauto.ru | `Ad-Reach/cars` | App Platform, backend (Dockerfile, Next.js), 1 vCPU / 1 ГБ | пуш в `production` → App Platform пересобирает сам |
| centro-plus.ru | `DmitryHudrich/potolki` | App Platform, статический сайт | пуш в `main` → CI собирает `dist/` в ветку `site` → App Platform выкладывает |

Серверов (VDS) нет, CMS нет: контент сайтов хранится в их репозиториях.

## Как устроено

- `terraform/apps.tf` — приложения App Platform. Terraform-провайдер Таймвеба App Platform
  не поддерживает, поэтому используется провайдер `Mastercard/restapi` поверх
  [API Таймвеба](https://timeweb.cloud/api-docs).
- Состояние Terraform — S3 Таймвеба, бакет `rangauto-tfstate` (создан вручную, тариф Standard 1 ГБ).
- `.github/workflows/terraform.yml`: PR → `plan` (в сводке запуска), пуш в `main` → `apply`.
- Секреты (Telegram, SMTP) задаются только здесь, в секретах GitHub. Переменные окружения,
  заданные руками в панели, Terraform перезапишет.

## Секреты GitHub (Settings → Secrets and variables → Actions)

| Секрет | Что это |
|---|---|
| `TWC_TOKEN` | API-токен Таймвеба |
| `TF_STATE_ACCESS_KEY` | access key S3 (панель → Хранилище S3 → `rangauto-tfstate`) |
| `TF_STATE_SECRET_KEY` | secret key S3 (там же) |
| `TELEGRAM_BOT_TOKEN` | токен бота заявок |
| `TELEGRAM_CHAT_IDS` | ID чатов для заявок через запятую |
| `TELEGRAM_ADMIN_IDS` | Telegram ID администраторов бота |
| `SMTP_USER` | ящик mail.ru, с которого уходят письма |
| `SMTP_PASS` | «пароль для внешних приложений» mail.ru |

Переменная (Variables): `LEAD_EMAIL_TO` — куда дублировать заявки (необязательно,
по умолчанию email из `src/data/site.ts` в cars).

SMTP-порты 465/587 для backend-приложения App Platform открывает поддержка Таймвеба по запросу (укажите ID приложения).

## DNS (reg.ru, вручную)

IP приложений: `terraform output` или панель → App Platform → приложение.
Сначала добавьте домен в панели: приложение → «Домены» → добавить `rangauto.ru` и `www.rangauto.ru`
(для centro-plus.ru — так же). Сертификат Let's Encrypt App Platform выпустит сам.

| Домен | Запись |
|---|---|
| `rangauto.ru` | `A` → IP приложения rangauto.ru |
| `www.rangauto.ru` | `A` → тот же IP |
| `centro-plus.ru` | `A` → IP приложения centro-plus.ru |
| `www.centro-plus.ru` | `A` → тот же IP |

`catalog.rangauto.ru` живёт на отдельном сервере, его запись не трогать.

## Локальный запуск

```bash
cd terraform
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=... TF_VAR_twc_token=...
terraform init
terraform plan
```

## Стоимость (тарифы на ноябрь 2026)

- rangauto.ru: 510 ₽/мес (1 vCPU 3.3 ГГц, 1 ГБ RAM, 15 ГБ NVMe).
- centro-plus.ru: тариф статического сайта, оплата по запросам.
- S3 для состояния: 1 ₽/мес.
