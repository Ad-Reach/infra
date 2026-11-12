locals {
  # Сайт работает в Москве (ru-3): зарубежные IP App Platform из России блокируются.

  # Подключённые к App Platform аккаунты GitHub и репозитории
  # (GET /api/v1/vcs-provider и /api/v1/vcs-provider/{id}).
  github_ad_reach = "5a55e9c9-5a59-40ad-aa18-27f605ba6aae"
  repo_cars       = "9a1ec970-eb46-493d-903b-a057a0ebaa8b"

  preset_backend_1gb = 2731 # 1 vCPU / 1 ГБ / 15 ГБ NVMe, ru-3 (Москва), 510 ₽/мес

  potolki_build = "(command -v apk >/dev/null && apk add --no-cache python3 || (apt-get update -qq && apt-get install -y -qq python3)) && python3 build.py"

  # Куда дублировать заявки. Переменная LEAD_EMAIL_TO в GitHub, если задана, заменяет этот список.
  lead_email_to = var.lead_email_to != "" ? var.lead_email_to : "rangauto@mail.ru,dimahudric@gmail.com"

  cars_envs = { for k, v in {
    TELEGRAM_BOT_TOKEN = var.telegram_bot_token
    TELEGRAM_CHAT_IDS  = var.telegram_chat_ids
    TELEGRAM_PROXY     = var.telegram_proxy
    SMTP_HOST          = "smtp.timeweb.ru"
    SMTP_PORT          = "465"
    SMTP_USER          = local.smtp_user
    SMTP_PASS          = random_password.smtp.result
    SMTP_FROM          = local.smtp_user
    LEAD_EMAIL_TO      = local.lead_email_to
    # тестовый доступ к каталогу новых авто: https://rangauto.ru/new?preview=<ключ> (src/proxy.ts в cars)
    NEW_CARS_PREVIEW_KEY = "42a929dd10b0a624"
    # Список Telegram-групп бота хранится в S3 (бакет состояния Terraform, папка app/)
    CHATS_S3_BUCKET     = "rangauto-tfstate"
    CHATS_S3_KEY        = "app/telegram-chats.json"
    CHATS_S3_ACCESS_KEY = var.s3_access_key
    CHATS_S3_SECRET_KEY = var.s3_secret_key
  } : k => v if v != "" }
}

# Коммит для первого деплоя (обязателен при создании). Дальше App Platform
# сам деплоит каждый пуш в ветку (is_auto_deploy).
data "http" "cars_head" {
  url             = "https://api.timeweb.cloud/api/v1/vcs-provider/${local.github_ad_reach}/repository/${local.repo_cars}/branch?name=${var.cars_branch}"
  request_headers = { Authorization = "Bearer ${var.twc_token}" }
}

# centro-plus.ru: ID репозитория Ad-Reach/potolki в App Platform и тариф статического
# сайта в Москве (ru-3) берутся из API — зарубежные IP App Platform из России блокируются.
data "http" "potolki_repos" {
  count = var.potolki_enabled ? 1 : 0

  url             = "https://api.timeweb.cloud/api/v1/vcs-provider/${local.github_ad_reach}"
  request_headers = { Authorization = "Bearer ${var.twc_token}" }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Не удалось получить список репозиториев GitHub Ad-Reach в App Platform: ${self.response_body}"
    }
  }
}

data "http" "app_presets" {
  count = var.potolki_enabled ? 1 : 0

  url             = "https://api.timeweb.cloud/api/v1/presets/apps"
  request_headers = { Authorization = "Bearer ${var.twc_token}" }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Не удалось получить тарифы App Platform: ${self.response_body}"
    }
  }
}

locals {
  potolki_repo_matches = var.potolki_enabled ? [
    for r in jsondecode(data.http.potolki_repos[0].response_body).repositories : r.id
    if lower(r.full_name) == lower(var.potolki_repo)
  ] : []
  repo_potolki = try(local.potolki_repo_matches[0], null)

  # самый дешёвый тариф статического сайта в нужной локации
  potolki_presets = var.potolki_enabled ? [
    for p in jsondecode(data.http.app_presets[0].response_body).frontend_presets : p
    if p.location == var.potolki_location
  ] : []
  potolki_preset_min_price = length(local.potolki_presets) > 0 ? min([for p in local.potolki_presets : p.price]...) : null
  preset_frontend          = try([for p in local.potolki_presets : p.id if p.price == local.potolki_preset_min_price][0], null)
}

data "http" "potolki_head" {
  count = var.potolki_enabled ? 1 : 0

  url             = "https://api.timeweb.cloud/api/v1/vcs-provider/${local.github_ad_reach}/repository/${local.repo_potolki}/branch?name=${var.potolki_branch}"
  request_headers = { Authorization = "Bearer ${var.twc_token}" }

  lifecycle {
    precondition {
      condition     = local.repo_potolki != null
      error_message = "Репозиторий ${var.potolki_repo} не виден App Platform: в GitHub дайте приложению Timeweb Cloud доступ к нему (Settings → GitHub Apps у организации Ad-Reach)."
    }
    precondition {
      condition     = local.preset_frontend != null
      error_message = "В локации ${var.potolki_location} нет тарифа статического сайта App Platform."
    }
  }
}

locals {
  # последний коммит ветки на момент создания приложения; дальше деплоит App Platform по пушу
  head_cars    = jsondecode(data.http.cars_head.response_body).commits[0].sha
  head_potolki = var.potolki_enabled ? jsondecode(data.http.potolki_head[0].response_body).commits[0].sha : null
}

# rangauto.ru — Next.js (Dockerfile в репозитории), сборка и запуск в App Platform.
# rangauto.ru в Москве (ru-3) — основное приложение.
resource "restapi_object" "rangauto" {
  path          = "/api/v1/apps"
  create_path   = "/api/v2/apps"
  read_path     = "/api/v1/apps/{id}"
  update_path   = "/api/v1/apps/{id}"
  destroy_path  = "/api/v1/apps/{id}"
  update_method = "PATCH"

  data = jsonencode({
    name           = "rangauto.ru"
    comment        = "Ad-Reach cars, managed by Terraform"
    type           = "backend"
    language       = "docker"
    framework      = "docker"
    provider_id    = local.github_ad_reach
    repository_id  = local.repo_cars
    branch_name    = var.cars_branch
    commit_sha     = local.head_cars
    is_auto_deploy = true
    build_cmd      = ""
    run_cmd        = ""
    preset_id      = local.preset_backend_1gb
    project_id     = var.project_id
    health_check   = "/"
    envs           = local.cars_envs
  })

  update_data = jsonencode({
    name           = "rangauto.ru"
    branch_name    = var.cars_branch
    is_auto_deploy = true
    preset_id      = local.preset_backend_1gb
    envs           = local.cars_envs
  })

  ignore_all_server_changes = true

  # data нужна только при создании (в ней коммит, который меняется с каждым пушем);
  # изменения настроек применяются через update_data
  lifecycle {
    ignore_changes = [data]
  }

  depends_on = [restapi_object.mail_noreply]
}

# centro-plus.ru — статический сайт в Москве (python3 build.py → dist/). Python в сборочном
# окружении App Platform нет, поэтому build_cmd сначала ставит его.
resource "restapi_object" "potolki" {
  count = var.potolki_enabled ? 1 : 0

  path          = "/api/v1/apps"
  create_path   = "/api/v2/apps"
  read_path     = "/api/v1/apps/{id}"
  update_path   = "/api/v1/apps/{id}"
  destroy_path  = "/api/v1/apps/{id}"
  update_method = "PATCH"

  data = jsonencode({
    name           = "centro-plus.ru"
    comment        = "Ad-Reach potolki, managed by Terraform"
    type           = "frontend"
    language       = "javascript"
    framework      = "another"
    provider_id    = local.github_ad_reach
    repository_id  = local.repo_potolki
    branch_name    = var.potolki_branch
    commit_sha     = local.head_potolki
    is_auto_deploy = true
    build_cmd      = local.potolki_build
    index_dir      = "/dist"
    preset_id      = local.preset_frontend
    project_id     = var.project_id
    envs           = {}
  })

  update_data = jsonencode({
    name           = "centro-plus.ru"
    branch_name    = var.potolki_branch
    is_auto_deploy = true
    build_cmd      = local.potolki_build
    index_dir      = "/dist"
  })

  ignore_all_server_changes = true
}
