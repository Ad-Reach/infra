output "rangauto" {
  value = {
    id      = restapi_object.rangauto.id
    ip      = try(jsondecode(restapi_object.rangauto.api_response).app.ip, null)
    domains = try(jsondecode(restapi_object.rangauto.api_response).app.domains, null)
  }
}

output "potolki" {
  value = var.potolki_enabled ? {
    id      = restapi_object.potolki[0].id
    preset  = local.preset_frontend
    ip      = try(jsondecode(restapi_object.potolki[0].api_response).app.ip, null)
    domains = try(jsondecode(restapi_object.potolki[0].api_response).app.domains, null)
  } : null
}

# Последние деплои centro-plus.ru: видно, собрался ли сайт после пуша в Ad-Reach/potolki.
data "http" "potolki_deploys" {
  count = var.potolki_enabled ? 1 : 0

  url             = "https://api.timeweb.cloud/api/v1/apps/${restapi_object.potolki[0].id}/deploys?limit=3"
  request_headers = { Authorization = "Bearer ${var.twc_token}" }
}

output "potolki_deploys" {
  value = var.potolki_enabled ? try([
    for d in jsondecode(data.http.potolki_deploys[0].response_body).deploys : {
      for k, v in d : k => v if contains(["id", "status", "commit_sha", "started_at", "ended_at"], k)
    }
  ], data.http.potolki_deploys[0].response_body) : null
}
