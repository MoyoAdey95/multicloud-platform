variable "name" {
  description = "Name used for the registry, the service and its identity."
  type        = string
}

variable "region" {
  description = "Region for the registry and the service."
  type        = string
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
