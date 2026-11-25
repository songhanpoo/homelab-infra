output "client_configuration" {
  value = data.talos_client_configuration.this
}
#
output "kubeconfig" {
  value = talos_cluster_kubeconfig.this
}
#
output "kubeconfig_raw" {
  value = talos_cluster_kubeconfig.this.kubeconfig_raw
}

output "machine_config" {
  value = data.talos_machine_configuration.this
}
