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

  # State for kube-addons/prod lives in its own Harness IaCM workspace "homelabkubeaddonsprod".
  # Never point two folders at one workspace. The token comes from TF_HTTP_PASSWORD.
  backend "http" {
    address        = "https://app.harness.io/gateway/iacm/api/orgs/default/projects/visabulletin/workspaces/homelabkubeaddonsprod/terraform-backend?accountIdentifier=LzGbvkVKS72VH3cLnnJmSA"
    username       = "harness"
    lock_address   = "https://app.harness.io/gateway/iacm/api/orgs/default/projects/visabulletin/workspaces/homelabkubeaddonsprod/terraform-backend/lock?accountIdentifier=LzGbvkVKS72VH3cLnnJmSA"
    lock_method    = "POST"
    unlock_address = "https://app.harness.io/gateway/iacm/api/orgs/default/projects/visabulletin/workspaces/homelabkubeaddonsprod/terraform-backend/lock?accountIdentifier=LzGbvkVKS72VH3cLnnJmSA"
    unlock_method  = "DELETE"
  }
}
