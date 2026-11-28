variable "traefik_version" {
  type    = string
  default = "v3.6"
}

variable "config_yaml" {
  description = "Raw YAML string decoded from the environment config file (e.g. envs/dev.yaml)"
  type        = string
}
