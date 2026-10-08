variable "name" {
  description = "Name used for the resource group, identity, environment and app."
  type        = string
}

variable "location" {
  description = "Azure region for the estate."
  type        = string
}

variable "registry_name" {
  description = "Container registry name. Global, 5 to 50 letters and digits only."
  type        = string
}

variable "image" {
  description = "Image the app runs, pinned by digest. Empty means no app yet."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to every resource, since azurerm has no default tags."
  type        = map(string)
}

variable "collector_image" {
  description = "Collector image to run next to the app, by digest. Empty means no collector."
  type        = string
  default     = ""
}
