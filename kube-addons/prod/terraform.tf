terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.6.2"
    }
    pihole = {
      source  = "iolave/pihole"
      version = "0.2.2"
    }
  }

  # FAILS CLOSED until filled in: add the address, lock_address and unlock_address of the
  # empty Harness workspace for kube-addons/prod. Never point two folders at one workspace.
  backend "http" {}
}
