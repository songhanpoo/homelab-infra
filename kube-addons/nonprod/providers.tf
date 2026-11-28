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
