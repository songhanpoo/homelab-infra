variable "image" {
  description = "Talos image configuration"
  type = object({
    factory_url  = optional(string, "https://factory.talos.dev")
    schematic    = optional(string)
    schematics   = optional(map(string))
    version      = string
    arch         = optional(string, "amd64")
    platform     = optional(string, "metal")
    image_type   = optional(string, "iso")
    datastore_id = optional(string, "iso")
  })
}

# variable "cluster" {
#   description = "Cluster configuration"
#   type = object({
#     name            = string
#     endpoint        = string
#     gateway         = string
#     talos_version   = string
#     libvirt_cluster = string
#   })
# }

variable "nodes" {
  description = "Configuration for cluster nodes"
  type = map(object({
    machine_type      = string
    datastore_id      = optional(string, "kvm")
    ip                = string
    mac_address       = string
    enable_qemu_agent = optional(bool, true)
    cpu               = number
    hostdevs = optional(list(object({
      address = string
      alias   = string
    })), [])
    memory    = number
    disk_size = number
  }))
  default = {}
}

# variable "create_nfs_pool" {
#   description = "Flag to create nfs pool"
#   type        = bool
#   default     = false
# }

# variable "additional_networks" {
#   description = "List of additional networks to create"
#   type = object({
#     name         = string
#     cidr         = string
#     mode         = string
#     auto_start   = optional(bool, true)
#     dhcp_enabled = optional(bool, true)
#     prefix       = optional(number, 24)
#     dhcp_start   = string
#     dhcp_end     = string
#   })
# }

# variable "nfs_pools" {
#   description = "List of NFS pools to create"
#   type = list(object({
#     name        = string
#     host_path   = string
#     host        = string
#     target_path = string
#     port        = optional(number, 4049)
#   }))
# }

variable "cluster" {
  description = "Cluster configuration"
  type = object({
    name            = string
    endpoint        = string
    talos_version   = string
    libvirt_cluster = string
  })
}

