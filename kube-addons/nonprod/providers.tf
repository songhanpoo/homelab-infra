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

provider "postgresql" {
  host     = "192.168.1.120"
  port     = 5432
  username = "postgres"
  password = "wh0lov3me"
  sslmode  = "disable"
}
