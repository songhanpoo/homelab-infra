terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.9.1" # pin to the provider series you want
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.9.0"
    }
  }
}
