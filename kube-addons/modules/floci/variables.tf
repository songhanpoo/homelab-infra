variable "image_digest" {
  description = "Pinned digest of ghcr.io/quenchworks/images/floci-full (never a tag - see the chart's own values.yaml comment on why)."
  type        = string
  default     = "sha256:d68808dcc7c1b27898ffa0b40de1074b9a20f8e23d003b05f58e2f919d60bd25"
}

variable "default_region" {
  description = "AWS region the emulated services report."
  type        = string
  default     = "ap-southeast-1"
}

variable "host" {
  description = "Hostname Traefik routes to this container (must match a DNS record in envs/prod/platform/dns.yaml)."
  type        = string
  default     = "floci.localdev.me"
}

variable "network_name" {
  description = "Docker network Traefik discovers containers on (modules/traefik creates this)."
  type        = string
  default     = "proxy"
}
