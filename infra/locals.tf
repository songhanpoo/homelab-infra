locals {
  configs = yamldecode(file("${path.module}/envs/${var.env}.yaml"))
}
