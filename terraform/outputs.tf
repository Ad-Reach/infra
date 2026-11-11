output "rangauto_msk" {
  value = {
    id      = restapi_object.rangauto_msk.id
    ip      = try(jsondecode(restapi_object.rangauto_msk.api_response).app.ip, null)
    domains = try(jsondecode(restapi_object.rangauto_msk.api_response).app.domains, null)
  }
}

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
    ip      = try(jsondecode(restapi_object.potolki[0].api_response).app.ip, null)
    domains = try(jsondecode(restapi_object.potolki[0].api_response).app.domains, null)
  } : null
}
