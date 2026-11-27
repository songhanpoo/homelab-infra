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

provider "pihole" {
  url      = "http://192.168.1.79"
  password = "wh0lov3me"
  # api_token = "3nsA1IoNzxYhADOt5AyBWgs0O2GxOjlhxVvrrrqdCHU="
}
