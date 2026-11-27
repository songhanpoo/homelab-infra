terraform {
  required_providers {
    # nginxproxymanager = {
    #   source  = "Sander0542/nginxproxymanager"
    #   version = "1.2.2"
    # }
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
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = ">= 1.22.0"
    }
    # n8n = {
    #   source  = "kodflow/n8n"
    #   version = "~> 1.0"
    # }
  }
  backend "http" {
    address        = "https://app.harness.io/gateway/iacm/api/orgs/default/projects/visabulletin/workspaces/homelabkubeaddons/terraform-backend?accountIdentifier=LzGbvkVKS72VH3cLnnJmSA"
    username       = "harness"
    lock_address   = "https://app.harness.io/gateway/iacm/api/orgs/default/projects/visabulletin/workspaces/homelabkubeaddons/terraform-backend/lock?accountIdentifier=LzGbvkVKS72VH3cLnnJmSA"
    lock_method    = "POST"
    unlock_address = "https://app.harness.io/gateway/iacm/api/orgs/default/projects/visabulletin/workspaces/homelabkubeaddons/terraform-backend/lock?accountIdentifier=LzGbvkVKS72VH3cLnnJmSA"
    unlock_method  = "DELETE"
  }
}
