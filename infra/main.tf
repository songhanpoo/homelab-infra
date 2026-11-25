# KVM module to create Talos nodes
module "talos" {
  source = "./modules/talos"
  nodes  = local.configs.clusters.nodes
  image = {
    version = local.configs.clusters.image.version
    schematics = {
      for k, v in try(local.configs.clusters.image.schematics, {}) : k => jsonencode(v)
    }
    platform     = try(local.configs.clusters.image.platform, null)
    image_type   = try(local.configs.clusters.image.image_type, null)
    datastore_id = try(local.configs.clusters.image.datastore_id, null)
  }
  cluster = {
    name            = "talos-${local.configs.clusters.name}"
    endpoint        = [for k, v in local.configs.clusters.nodes : v.ip if v.machine_type == "controlplane"][0]
    talos_version   = local.configs.clusters.talos_version
    libvirt_cluster = local.configs.clusters.name
  }
}

# Nginx Proxy Manager module
# module "nginx_proxy" {
#   source       = "./modules/nginx-proxy"
#   service_name = "nginx-proxy-manager"
#   timezone     = "Asia/Ho_Chi_Minh"
# }

# Initial vm by cloud_init
module "virtual-machine" {
  source = "./modules/kvm"
  nodes  = local.configs.databases.nodes
  image = {
    version = local.configs.databases.image.version
    # schematic  = jsonencode(local.configs.clusters.image.schematic)
    image_name = local.configs.databases.image.name
  }
}
