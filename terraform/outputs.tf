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
