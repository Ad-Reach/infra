# Telegram-бот заявок rangauto (Ad-Reach/cars, папка bot/) — отдельное backend-приложение
# App Platform в Амстердаме (nl-1): оттуда Telegram API доступен без прокси.
# Тариф — самый дешёвый backend в локации, выбирается через API.
# Собирается из bot/Dockerfile (build_entry_path = /bot), деплоит сам по пушу в ветку.

data "http" "bot_presets" {
  count = var.bot_enabled ? 1 : 0

  url             = "https://api.timeweb.cloud/api/v1/presets/apps"
  request_headers = { Authorization = "Bearer ${var.twc_token}" }

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Не удалось получить тарифы App Platform: ${self.response_body}"
    }
  }
}

data "http" "bot_head" {
  count = var.bot_enabled ? 1 : 0

  url             = "https://api.timeweb.cloud/api/v1/vcs-provider/${local.github_ad_reach}/repository/${local.repo_cars}/branch?name=${var.bot_branch}"
  request_headers = { Authorization = "Bearer ${var.twc_token}" }
}

locals {
  bot_presets = var.bot_enabled ? [
    for p in jsondecode(data.http.bot_presets[0].response_body).backend_presets : p
    if p.location == var.bot_location
  ] : []
  bot_preset_min_price = length(local.bot_presets) > 0 ? min([for p in local.bot_presets : p.price]...) : null
  preset_bot           = try([for p in local.bot_presets : p.id if p.price == local.bot_preset_min_price][0], null)
  head_bot             = var.bot_enabled ? jsondecode(data.http.bot_head[0].response_body).commits[0].sha : null

  bot_envs = { for k, v in {
    TELEGRAM_BOT_TOKEN = var.bot_telegram_token
    LEAD_CHAT_IDS      = var.bot_lead_chat_ids
    # HTTPS-адрес приложения: на нём Mini App (кнопка меню бота)
    PUBLIC_URL = var.bot_public_url
    # почта — тот же ящик no-reply@rangauto.ru, что у сайта (mail.tf)
    SMTP_HOST     = "smtp.timeweb.ru"
    SMTP_PORT     = "465"
    SMTP_USER     = local.smtp_user
    SMTP_PASS     = random_password.smtp.result
    SMTP_FROM     = local.smtp_user
    LEAD_EMAIL_TO = local.lead_email_to
  } : k => v if v != "" }
}

resource "restapi_object" "bot" {
  count = var.bot_enabled ? 1 : 0

  path          = "/api/v1/apps"
  create_path   = "/api/v2/apps"
  read_path     = "/api/v1/apps/{id}"
  update_path   = "/api/v1/apps/{id}"
  destroy_path  = "/api/v1/apps/{id}"
  update_method = "PATCH"

  data = jsonencode({
    name             = "bot.rangauto.ru"
    comment          = "Ad-Reach cars, папка bot (Telegram lead bot), managed by Terraform"
    type             = "backend"
    language         = "docker"
    framework        = "docker"
    provider_id      = local.github_ad_reach
    repository_id    = local.repo_cars
    branch_name      = var.bot_branch
    commit_sha       = local.head_bot
    is_auto_deploy   = true
    build_entry_path = "/bot"
    build_cmd        = ""
    run_cmd          = ""
    preset_id        = local.preset_bot
    project_id       = var.project_id
    health_check     = "/health"
    envs             = local.bot_envs
  })

  update_data = jsonencode({
    name           = "bot.rangauto.ru"
    branch_name    = var.bot_branch
    is_auto_deploy = true
    envs           = local.bot_envs
  })

  ignore_all_server_changes = true

  lifecycle {
    ignore_changes = [data]
    precondition {
      condition     = local.preset_bot != null
      error_message = "В локации ${var.bot_location} нет backend-тарифа App Platform."
    }
    precondition {
      condition     = var.bot_telegram_token != ""
      error_message = "Не задан секрет BOT_TELEGRAM_TOKEN (Settings → Secrets → Actions)."
    }
  }

  depends_on = [restapi_object.mail_noreply]
}

data "http" "bot_deploys" {
  count = var.bot_enabled ? 1 : 0

  url             = "https://api.timeweb.cloud/api/v1/apps/${restapi_object.bot[0].id}/deploys?limit=3"
  request_headers = { Authorization = "Bearer ${var.twc_token}" }
}

output "bot" {
  value = var.bot_enabled ? {
    id      = restapi_object.bot[0].id
    preset  = local.preset_bot
    price   = local.bot_preset_min_price
    ip      = try(jsondecode(restapi_object.bot[0].api_response).app.ip, null)
    domains = try(jsondecode(restapi_object.bot[0].api_response).app.domains, null)
    deploys = try([
      for d in jsondecode(data.http.bot_deploys[0].response_body).deploys : {
        for k, v in d : k => v if contains(["id", "status", "commit_sha", "started_at", "ended_at"], k)
      }
    ], data.http.bot_deploys[0].response_body)
  } : null
}

# Лог последнего деплоя бота (сборка и запуск) — чтобы видеть причину ошибки без панели.
# Переменных окружения в нём нет. Последние строки — в выводе terraform output bot_last_deploy_log.
locals {
  bot_last_deploy_id = try(jsondecode(data.http.bot_deploys[0].response_body).deploys[0].id, "")
}

data "http" "bot_last_deploy_log" {
  count = var.bot_enabled && local.bot_last_deploy_id != "" ? 1 : 0

  url             = "https://api.timeweb.cloud/api/v1/apps/${restapi_object.bot[0].id}/deploy/${local.bot_last_deploy_id}/logs"
  request_headers = { Authorization = "Bearer ${var.twc_token}" }
}

output "bot_last_deploy_log" {
  value = try(
    join("\n", slice(
      [for l in jsondecode(data.http.bot_last_deploy_log[0].response_body).logs : try(l.message, tostring(l))],
      max(0, length(jsondecode(data.http.bot_last_deploy_log[0].response_body).logs) - 80),
      length(jsondecode(data.http.bot_last_deploy_log[0].response_body).logs)
    )),
    try(data.http.bot_last_deploy_log[0].response_body, null)
  )
}
