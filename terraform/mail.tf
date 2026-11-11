# Ящик для отправки заявок с сайта: no-reply@rangauto.ru (почта Таймвеба).
# Домен добавлен на аккаунт (POST /api/v1/add-domain/rangauto.ru), NS остаются на reg.ru.
# Для доставляемости на reg.ru нужна TXT-запись SPF (см. README).
locals {
  mail_domain = "rangauto.ru"
  smtp_user   = "no-reply@${local.mail_domain}"
}

resource "random_password" "smtp" {
  length           = 24
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "-_"
}

resource "restapi_object" "mail_noreply" {
  path          = "/api/v1/mail/domains/${local.mail_domain}"
  create_path   = "/api/v2/mail/domains/${local.mail_domain}"
  read_path     = "/api/v1/mail/domains/${local.mail_domain}/mailboxes/{id}"
  update_path   = "/api/v1/mail/domains/${local.mail_domain}/mailboxes/{id}"
  destroy_path  = "/api/v1/mail/domains/${local.mail_domain}/mailboxes/{id}"
  update_method = "PATCH"
  id_attribute  = "mailbox/mailbox"

  data = jsonencode({
    mailbox  = "no-reply"
    password = random_password.smtp.result
    comment  = "SMTP for rangauto.ru leads (Terraform)"
  })

  update_data = jsonencode({
    password = random_password.smtp.result
  })

  ignore_all_server_changes = true
}
