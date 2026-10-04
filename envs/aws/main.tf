module "workload" {
  source = "../../modules/workload-fargate"

  name     = "platform-api"
  vpc_cidr = "10.40.0.0/16"
  image    = var.image
}
