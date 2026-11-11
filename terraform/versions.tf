terraform {
  required_version = ">= 1.10"

  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 3.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }

  # Состояние — в S3 Таймвеба (бакет rangauto-tfstate создан вручную, см. README).
  # Ключи: AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY.
  backend "s3" {
    bucket                      = "rangauto-tfstate"
    key                         = "infra/terraform.tfstate"
    region                      = "ru-1"
    endpoints                   = { s3 = "https://s3.twcstorage.ru" }
    use_path_style              = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

# Terraform-провайдер Таймвеба не умеет App Platform, поэтому приложения
# управляются через REST API Таймвеба (https://timeweb.cloud/api-docs).
provider "restapi" {
  uri                   = "https://api.timeweb.cloud"
  bearer_token          = var.twc_token
  write_returns_object  = true
  create_returns_object = true
  id_attribute          = "app/id"
  headers = {
    "Content-Type" = "application/json"
  }
}
