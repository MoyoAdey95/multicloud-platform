module "workload" {
  source = "../../modules/workload-containerapps"

  name          = "platform-api"
  location      = var.azure_location
  registry_name = "moyoplatformacr"
  image         = var.image
  tags          = local.common_tags
}
