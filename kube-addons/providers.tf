provider "helm" {
  kubernetes = {
    config_path = "~/.kube/talos-paul/kubeconfig"
  }
}

provider "kubernetes" {
  config_path = "~/.kube/talos-paul/kubeconfig"
}

provider "docker" {
  host     = "ssh://songhanpoo@192.168.1.98"
  ssh_opts = ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"]
}

# provider "nginxproxymanager" {
#   url      = "http://192.168.1.99:8181"
#   username = "songhanpoo@gmail.com"
#   password = "changeme1234"
# }

provider "pihole" {
  url      = "http://192.168.1.79"
  password = "wh0lov3me"
  # api_token = "3nsA1IoNzxYhADOt5AyBWgs0O2GxOjlhxVvrrrqdCHU="
}

provider "postgresql" {
  host     = "192.168.1.120"
  port     = 5432
  username = "postgres"
  password = "wh0lov3me"
  sslmode  = "disable"
}
