variable "service_name" {
  type        = string
  description = "The name of the service"
}

variable "timezone" {
  type        = string
  description = "The timezone for the nginx-proxy-manager"
  default     = "UTC"
}

variable "admin_port" {
  type        = number
  default     = 8181
  description = "The port access for admin management"
}

variable "https_port" {
  type        = number
  default     = 443
  description = "The port for HTTPS traffic"
}

variable "http_port" {
  type        = number
  default     = 80
  description = "The port for HTTPS traffic"
}
