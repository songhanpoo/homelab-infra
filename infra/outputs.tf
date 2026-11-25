output "client_configuration" {
  value     = module.talos.client_configuration
  sensitive = true
}

output "kubeconfig" {
  value     = module.talos.kubeconfig
  sensitive = true
}

output "kubeconfig_raw" {
  value     = module.talos.kubeconfig_raw
  sensitive = true
}

