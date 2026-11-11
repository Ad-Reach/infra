locals {
  # Сайт работает в Москве (ru-3): зарубежные IP App Platform из России блокируются.

  # Подключённые к App Platform аккаунты GitHub и репозитории
  # (GET /api/v1/vcs-provider и /api/v1/vcs-provider/{id}).
  github_ad_reach      = "5a55e9c9-5a59-40ad-aa18-27f605ba6aae"
  github_dmitryhudrich = "407f9a8f-b26b-45e0-bb42-fd3e394b05ee"
  repo_cars            = "9a1ec970-eb46-493d-903b-a057a0ebaa8b"
  repo_potolki         = "e09e2d6f-02d2-40c0-8484-87b7da00e635"

  preset_backend_1gb = 2731 # 1 vCPU / 1 ГБ / 15 ГБ NVMe, ru-3 (Москва), 510 ₽/мес
  preset_backend_2gb = 2733 # 1 vCPU / 2 ГБ / 30 ГБ, 810 ₽ — старое приложение, удаляется после переключения доменов
  preset_frontend    = 2803 # статический сайт, nl-1

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

data "http" "potolki_head" {
  count = var.potolki_enabled ? 1 : 0

  url             = "https://api.timeweb.cloud/api/v1/vcs-provider/${local.github_dmitryhudrich}/repository/${local.repo_potolki}/branch?name=${var.potolki_branch}"
  request_headers = { Authorization = "Bearer ${var.twc_token}" }
}

resource "terraform_data" "first_commit" {
  input = {
    cars    = jsondecode(data.http.cars_head.response_body).commits[0].sha
    potolki = var.potolki_enabled ? jsondecode(data.http.potolki_head[0].response_body).commits[0].sha : null
  }
  lifecycle {
    ignore_changes = [input]
  }
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
    commit_sha     = terraform_data.first_commit.output.cars
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

  depends_on = [restapi_object.mail_noreply]
}

# Старое московское приложение на 2 ГБ (по ошибке, уменьшить тариф нельзя).
# Удаляется, когда домены переедут на restapi_object.rangauto.
resource "restapi_object" "rangauto_msk" {
  path          = "/api/v1/apps"
  create_path   = "/api/v2/apps"
  read_path     = "/api/v1/apps/{id}"
  update_path   = "/api/v1/apps/{id}"
  destroy_path  = "/api/v1/apps/{id}"
  update_method = "PATCH"

  data = jsonencode({
    name           = "rangauto.ru (Москва)"
    comment        = "Ad-Reach cars, managed by Terraform"
    type           = "backend"
    language       = "docker"
    framework      = "docker"
    provider_id    = local.github_ad_reach
    repository_id  = local.repo_cars
    branch_name    = var.cars_branch
    commit_sha     = terraform_data.first_commit.output.cars
    is_auto_deploy = true
    build_cmd      = ""
    run_cmd        = ""
    preset_id      = local.preset_backend_2gb
    project_id     = var.project_id
    health_check   = "/"
    envs           = local.cars_envs
  })

  update_data = jsonencode({
    name           = "rangauto.ru (выводится)"
    branch_name    = var.cars_branch
    is_auto_deploy = true
    preset_id      = local.preset_backend_2gb
    envs           = local.cars_envs
  })

  ignore_all_server_changes = true

  depends_on = [restapi_object.mail_noreply]
}

# centro-plus.ru — статический сайт (python3 build.py → dist/). Python в сборочном
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
    comment        = "potolki, managed by Terraform"
    type           = "frontend"
    language       = "javascript"
    framework      = "another"
    provider_id    = local.github_dmitryhudrich
    repository_id  = local.repo_potolki
    branch_name    = var.potolki_branch
    commit_sha     = terraform_data.first_commit.output.potolki
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
