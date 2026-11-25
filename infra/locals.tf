locals {
  configs = yamldecode(file("${path.module}/envs/nonprod.yaml"))
}
