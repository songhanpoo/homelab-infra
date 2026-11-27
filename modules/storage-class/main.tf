resource "kubernetes_storage_class_v1" "this" {
  for_each = var.storage_classes

  metadata {
    name = each.key
  }
  storage_provisioner = "nfs.csi.k8s.io"
  reclaim_policy      = each.value.reclaim_policy
  volume_binding_mode = each.value.volume_binding_mode
  parameters = merge(
    {
      server = each.value.server
      share  = each.value.share
    },
    each.value.mount_permissions != null ? { mountPermissions = each.value.mount_permissions } : {}
  )
  mount_options = each.value.mount_options
}
