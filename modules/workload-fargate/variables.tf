variable "name" {
  description = "Name used for the cluster, service, registry, roles and network."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC. Subnets are carved from it."
  type        = string
}

variable "app_port" {
  description = "Port the app container listens on."
  type        = number
  default     = 8080
}

variable "image" {
  description = "Image the service runs, pinned by digest. Empty means no service yet."
  type        = string
  default     = ""
}

variable "collector_image" {
  description = "Collector image to run next to the app, by digest. Empty means no collector."
  type        = string
  default     = ""
}
