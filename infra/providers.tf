provider "libvirt" {
  uri = "qemu+ssh://songhanpoo@${local.configs.clusters.libvirt_server}/system"
}


# provider "docker" {
#   host     = "ssh://songhanpoo@${local.configs.clusters.libvirt_server}"
#   ssh_opts = ["-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null"]
# }
