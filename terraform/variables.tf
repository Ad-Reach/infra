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

variable "telegram_admin_ids" {
  description = "Telegram ID администраторов бота через запятую"
  type        = string
  sensitive   = true
  default     = ""
}

variable "smtp_user" {
  type      = string
  sensitive = true
  default   = ""
}

variable "smtp_pass" {
  type      = string
  sensitive = true
  default   = ""
}

variable "lead_email_to" {
  description = "Куда дублировать заявки (через запятую). Пусто — email из src/data/site.ts"
  type        = string
  default     = ""
}

# --- centro-plus.ru (DmitryHudrich/potolki) ---

variable "potolki_branch" {
  description = "Ветка с собранным сайтом (её публикует CI репозитория potolki)"
  type        = string
  default     = "site"
}
