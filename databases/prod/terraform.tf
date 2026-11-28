terraform {
  required_providers {
    postgresql = {
      source  = "cyrilgdn/postgresql"
      version = ">= 1.22.0"
    }
  }

  # FAILS CLOSED until filled in: add the address, lock_address and unlock_address of this
  # folder's own Harness workspace. Never point two folders at one workspace.
  backend "http" {}
}
