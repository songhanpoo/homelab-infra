variable "env" {
  type    = string
  default = "nonprod"
}

# variable "nodes" {
#   description = "Configuration for cluster nodes"
#   type = map(object({
#     machine_type      = string
#     datastore_id      = optional(string, "default")
#     ip                = string
#     mac_address       = string
#     enable_qemu_agent = optional(bool, true)
#     cpu               = number
#     memory            = number
#     disk_size         = number
#   }))
#   default = {}
# }
