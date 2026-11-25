variable "storage_classes" {
  description = "Map of StorageClass name -> NFS-backed config"
  type = map(object({
    server              = string
    share               = string
    reclaim_policy      = optional(string, "Delete")
    volume_binding_mode = optional(string, "Immediate")
    mount_options       = optional(list(string), ["nfsvers=4"])
    mount_permissions   = optional(string, null)
  }))
}
