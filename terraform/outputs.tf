output "rangauto" {
  value = {
    id      = restapi_object.rangauto.id
    ip      = try(jsondecode(restapi_object.rangauto.api_response).app.ip, null)
    domains = try(jsondecode(restapi_object.rangauto.api_response).app.domains, null)
  }
}

output "potolki" {
  value = {
    id      = restapi_object.potolki.id
    ip      = try(jsondecode(restapi_object.potolki.api_response).app.ip, null)
    domains = try(jsondecode(restapi_object.potolki.api_response).app.domains, null)
  }
}
