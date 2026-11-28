provider "libvirt" {
  uri = "qemu+ssh://songhanpoo@${local.configs.clusters.libvirt_server}/system"
}


# provider "docker" {
#   host     = "ssh://songhanpoo@${local.configs.clusters.libvirt_server}"
#   ssh_opts = ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"]
# }

# Manages the Harness secrets in harness-secrets.tf. The API token comes from
# HARNESS_PLATFORM_API_KEY, which infra/Makefile sets from TF_HTTP_PASSWORD. Never put it here.
provider "harness" {
  endpoint   = "https://app.harness.io/gateway"
  account_id = "LzGbvkVKS72VH3cLnnJmSA" # an identifier, not a secret; also in the backend URLs
}
