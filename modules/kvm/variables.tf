variable "nodes" {
  description = "Configuration for cluster nodes"
  type = map(object({
    machine_type   = optional(string, "node")
    datastore_id   = optional(string, "kvm")
    user_data      = string
    meta_data      = string
    network_config = string
    cpu            = number
    hostdevs = optional(list(object({
      address = string
      alias   = string
    })), [])
    memory    = number
    disk_size = number
  }))
  default = {}
}

variable "image" {
  description = "Talos image configuration"
  type = object({
    factory_url  = optional(string, "https://factory.talos.dev")
    distribution = optional(string, "ubuntu")
    arch         = optional(string, "amd64")
    image_type   = optional(string, "img")
    image_name   = optional(string, "noable")
  })
}

variable "create_vm_cloud_init" {
  type    = bool
  default = true
}
