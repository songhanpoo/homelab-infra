# Local-only helper for "make prepare" in infra/. It rebuilds the cloud-init ISOs that
# module.virtual-machine tracks, from the same settings, so the files exist on any machine.
# It creates nothing on the libvirt host, uses throwaway local state, and is never a pipeline target.
# Relies on provider 0.9.1 naming the ISO from its content and reusing an existing file:
# check this again before upgrading the provider (here and in modules/kvm).
terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.1"
    }
  }
}

locals {
  configs = yamldecode(file("${path.module}/../envs/nonprod.yaml"))
}

provider "libvirt" {
  uri = "qemu+ssh://songhanpoo@${local.configs.clusters.libvirt_server}/system"
}

# Keep the arguments identical to libvirt_cloudinit_disk.vm_init in modules/kvm.
resource "libvirt_cloudinit_disk" "vm_init" {
  for_each       = local.configs.databases.nodes
  name           = "${each.key}.iso"
  user_data      = each.value.user_data
  meta_data      = each.value.meta_data
  network_config = each.value.network_config
}
