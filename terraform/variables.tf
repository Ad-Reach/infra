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

variable "amocrm_token" {
  description = "Долгосрочный токен интеграции amoCRM rangauto123 (секрет AMOCRM_TOKEN). Пусто — заявки в amoCRM не уходят"
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
  description = "Ветка сайта. Таймвеб не меняет ветку у созданного приложения через PATCH — только при создании"
  type        = string
  default     = "main"
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

# --- Telegram-бот заявок (Ad-Reach/cars, папка bot/) ---

variable "bot_enabled" {
  description = "Создавать ли приложение бота"
  type        = bool
  default     = true
}

variable "bot_branch" {
  description = "Ветка Ad-Reach/cars, из которой собирается бот"
  type        = string
  default     = "main"
}

variable "bot_location" {
  description = "Локация App Platform для бота (Амстердам: Telegram API доступен без прокси)"
  type        = string
  default     = "nl-1"
}

variable "bot_telegram_token" {
  description = "Токен бота заявок (@BotFather) — отдельный от бота сайта"
  type        = string
  sensitive   = true
  default     = ""
}

variable "bot_lead_chat_ids" {
  description = "Чаты менеджеров для заявок из бота, через запятую (узнать id — /id в чате)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "bot_public_url" {
  description = "Публичный HTTPS-адрес приложения бота (технический домен App Platform) — адрес Mini App"
  type        = string
  default     = "https://tg.rangauto.ru"
}

variable "smtp_pass" {
  description = "Пароль для внешних приложений ящика rangauto@mail.ru (секрет SMTP_PASS)"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.smtp_pass) > 0
    error_message = "Не задан секрет SMTP_PASS: без него заявки на почту не уходят."
  }
}
