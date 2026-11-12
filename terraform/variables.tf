variable "twc_token" {
  description = "API-токен Таймвеба"
  type        = string
  sensitive   = true
}

variable "project_id" {
  description = "Проект в панели Таймвеба"
  type        = number
  default     = 939455
}

# --- rangauto.ru (Ad-Reach/cars) ---

variable "cars_branch" {
  description = "Ветка, из которой App Platform собирает rangauto.ru"
  type        = string
  default     = "production"
}

variable "telegram_bot_token" {
  type      = string
  sensitive = true
  default   = ""
}

variable "telegram_chat_ids" {
  description = "ID чатов для заявок через запятую"
  type        = string
  sensitive   = true
  default     = ""
}

variable "lead_email_to" {
  description = "Куда дублировать заявки (через запятую). Пусто — email из src/data/site.ts"
  type        = string
  default     = ""
}

# --- centro-plus.ru (Ad-Reach/potolki) ---

variable "potolki_enabled" {
  description = "Создавать ли приложение centro-plus.ru"
  type        = bool
  default     = true
}

variable "potolki_repo" {
  type    = string
  default = "Ad-Reach/potolki"
}

variable "potolki_location" {
  description = "Локация App Platform для centro-plus.ru"
  type        = string
  default     = "ru-3"
}

variable "potolki_branch" {
  type    = string
  default = "main"
}

# Ключи S3-пользователя аккаунта (те же, что для состояния Terraform)
variable "s3_access_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "s3_secret_key" {
  type      = string
  sensitive = true
  default   = ""
}

variable "telegram_proxy" {
  description = "Прокси до api.telegram.org (http://user:pass@host:port или socks5://...). Из Москвы Telegram API недоступен"
  type        = string
  sensitive   = true
  default     = ""
}
