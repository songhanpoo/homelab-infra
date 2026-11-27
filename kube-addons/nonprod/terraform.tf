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
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = ">= 1.22.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.8.1"
    }
  }

  # FAILS CLOSED until filled in: add the address, lock_address and unlock_address of the
  # empty Harness workspace for kube-addons/nonprod. Never point two folders at one workspace.
  backend "http" {}
}
