variable "n8n_base_url" {
  description = "Base URL of n8n instance"
  type        = string
  default     = "https://n8n.localdev.me"
}

variable "n8n_api_key" {
  description = "API key for n8n instance"
  type        = string
  sensitive   = true
}
