provider "helm" {
  kubernetes = {
    config_path = "~/.kube/talos-paul/kubeconfig"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/talos-paul/kubeconfig"
}

# provider "nginxproxymanager" {
#   url      = "http://192.168.1.99:8181"
#   username = "songhanpoo@gmail.com"
#   password = "changeme1234"
# }

# For the cd_kubeconfig_b64 secret in cd-deployer.tf. The API token comes from
# HARNESS_PLATFORM_API_KEY, which terraform.mk sets from TF_HTTP_PASSWORD.
provider "harness" {
  endpoint   = "https://app.harness.io/gateway"
  account_id = "LzGbvkVKS72VH3cLnnJmSA" # an identifier, not a secret; also in the backend URLs
}
