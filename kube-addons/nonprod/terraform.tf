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

  # State for kube-addons/nonprod lives in its own Harness IaCM workspace "homelab-kube-addons-nonprod".
  # Never point two folders at one workspace. The token comes from TF_HTTP_PASSWORD.
  backend "http" {
    address        = "https://app.harness.io/gateway/iacm/api/orgs/default/projects/visabulletin/workspaces/homelab-kube-addons-nonprod/terraform-backend?accountIdentifier=LzGbvkVKS72VH3cLnnJmSA"
    username       = "harness"
    lock_address   = "https://app.harness.io/gateway/iacm/api/orgs/default/projects/visabulletin/workspaces/homelab-kube-addons-nonprod/terraform-backend/lock?accountIdentifier=LzGbvkVKS72VH3cLnnJmSA"
    lock_method    = "POST"
    unlock_address = "https://app.harness.io/gateway/iacm/api/orgs/default/projects/visabulletin/workspaces/homelab-kube-addons-nonprod/terraform-backend/lock?accountIdentifier=LzGbvkVKS72VH3cLnnJmSA"
    unlock_method  = "DELETE"
  }
}
