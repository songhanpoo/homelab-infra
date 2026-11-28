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
  }

  # FAILS CLOSED until filled in: add the address, lock_address and unlock_address of the
  # empty Harness workspace for kube-addons/nonprod. Never point two folders at one workspace.
  backend "http" {
    address        = "https://app.harness.io/gateway/iacm/api/orgs/default/projects/visabulletin/workspaces/homelabkubeaddonsnonprod/terraform-backend?accountIdentifier=LzGbvkVKS72VH3cLnnJmSA"
    username       = "harness"
    lock_address   = "https://app.harness.io/gateway/iacm/api/orgs/default/projects/visabulletin/workspaces/homelabkubeaddonsnonprod/terraform-backend/lock?accountIdentifier=LzGbvkVKS72VH3cLnnJmSA"
    lock_method    = "POST"
    unlock_address = "https://app.harness.io/gateway/iacm/api/orgs/default/projects/visabulletin/workspaces/homelabkubeaddonsnonprod/terraform-backend/lock?accountIdentifier=LzGbvkVKS72VH3cLnnJmSA"
    unlock_method  = "DELETE"
  }
}
