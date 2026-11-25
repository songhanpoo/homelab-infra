output "names" {
  value = { for k, v in kubernetes_storage_class_v1.this : k => v.metadata[0].name }
}
