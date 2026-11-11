# infra

Инфраструктура сайтов в Timeweb Cloud (Амстердам, `nl-1`), описанная в Terraform.

| Сайт | Репозиторий | Где работает | Деплой |
|---|---|---|---|
| rangauto.ru | `Ad-Reach/cars` | App Platform, backend (Dockerfile, Next.js), 1 vCPU / 1 ГБ | пуш в `production` → App Platform пересобирает сам |
| centro-plus.ru | `DmitryHudrich/potolki` | App Platform, статический сайт — **пока выключено** (`potolki_enabled = false`) | пуш в `main` → App Platform собирает (`python3 build.py`) и выкладывает |

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
| `TELEGRAM_CHAT_IDS` | необязательно: чаты, куда слать заявки всегда |

Куда дублируются заявки: `rangauto@mail.ru`, `dimahudric@gmail.com` (`terraform/apps.tf`, `lead_email_to`).
Переменная GitHub (Variables) `LEAD_EMAIL_TO`, если задана, заменяет этот список.

## Заявки в Telegram

Заявки приходят во все группы, куда добавлен бот: группа подключается сама при добавлении бота
(или командой `/connect` в группе), отключается при удалении бота или командой `/disconnect`.
Список групп хранится в S3: бакет `rangauto-tfstate`, файл `app/telegram-chats.json`.

## Почта для заявок

Письма уходят с `no-reply@rangauto.ru` (почта Таймвеба, `smtp.timeweb.ru:465`).
Ящик и случайный пароль создаёт Terraform (`terraform/mail.tf`) и сам передаёт их приложению,
руками пароль задавать не нужно. Домен `rangauto.ru` добавлен на аккаунт Таймвеба, NS остаются на reg.ru.

Исходящие SMTP-порты 465/587 для backend-приложения App Platform открывает поддержка Таймвеба
по запросу (ID приложения rangauto.ru — 287225).

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
| `rangauto.ru` | `TXT` → `v=spf1 include:_spf.timeweb.ru ~all` (SPF, чтобы письма с no-reply@ не попадали в спам) |

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
